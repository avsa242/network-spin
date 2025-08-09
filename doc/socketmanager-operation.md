# Socket manager operation
--------------------------

Sockets contain per-connection information stored in a structure:
* Local IP and MAC address and port (used in TCP and UDP sockets)
* Remote IP and MAC address and port (TCP and UDP)
* Transmit and receive ring-buffers containing application protocol/end-user data only and associated pointers (TCP and UDP) 
* a pointer to an application protocol's "mailbox" to pass signals to it directly, e.g. to notify it of events like a connection state change or new data received (TCP and UDP)
* send and receive sequence numbers and window (TCP only)
* current and previous connection state (CLOSED, LISTENING, ESTABLISHED, etc) (TCP and some states UDP)
* layer-4 protocol: TCP, UDP
* push flag (TCP only)
* pending connection fifo/backlog for listening sockets (TCP only)


### Main loop (secondary cog)
* check network interface link state
	* suspend until connected
	* upon connection, announce IP/MAC via ARP
* check for pending commands from the user/application
	* check command
		* connect (must call bind() first)
		* disconnect
* check for packets received on network interface, check ethertype
	* ARP:
		* update cache
		* answer, if it's appropriate for us to
	* IPv4:
		* verify packet is addressed to us (or is multicast)
		* check layer-4 protocol
			* icmp:
				* parse messages (destination unreachable, echo request)
			* udp:
				* check for a matching existing socket (local port, and is UDP)
				* receive payload into socket if there's a valid one
				* if unicast, bounce as unreachable with ICMP if there's no valid socket
			* tcp:
				* verify socket
					* check for a matching existing socket
					* check for a service listening on that port if no existing socket
					* reset connection/return error on failure
				* check connection state
					* `CLOSED`
						* check flags
						* return error if connection was reset by remote host
						* send reset segment if ACK received
					* `LISTENING`
						* check flags
						* open a new socket if SYN received, send SYN|ACK
				* check the sequence number
				* check the reset flag
					* `SYN_RECEIVED`
						* return to `LISTENING` if that was the previous state (OK)
						* return to `CLOSED` if `SYN_SENT` was the previous state (error)
						* return to `CLOSED` if `ESTABLISHED`, `FIN_WAIT_1`, `FIN_WAIT_2`, `CLOSE_WAIT` were the previous state (error)
						* return to `CLOSED` if `CLOSING`, `LAST_ACK`, `TIME_WAIT` were the previous state (error)
				* check the SYN flag
					* `SYN_RECEIVED`
						* delete the socket/ignore if `LISTEN` was the previous state
					* send ACK for all other states
					* check the ACK flag
					* ignore/return if not set
					* check that received sequence number is "in-window". Reset/drop if not
				* process segment text
					* receive into socket's buffer if in `ESTABLISHED`, `FIN_WAIT_1`, `FIN_WAIT_2`
					* Update the receive window
					* Signal to app if PSH is set
				* check the FIN flag
					* return if it isn't set
					* ignore in states `CLOSED`, `LISTEN`, `SYN_SENT`
					* signal to app that a disconnect was received by the remote host
					* transition state:
						1. `SYN_RECEIVED`, `ESTABLISHED` -> `CLOSE_WAIT`
						2. `FIN_WAIT_1` -> `CLOSING`
						3. `FIN_WAIT_2` -> `TIME_WAIT`
						4. `CLOSE_WAIT`, `CLOSING`, `LAST_ACK` -> no change
						5. `TIME_WAIT` -> no change
					* inc sequence number (rcv.nxt)
					* send ACK

* check sockets for queued data to send
* check ARP table for entries not marked 'resolved'
	* send probes/requests to resolve (no more than one per second per entry)


### User interface:

* `set_ip()` set this node's IP address
* `set_mac_addr()` set this node's MAC address
* `new_socket()` check out a socket for subsequent operations (TCP, UDP)
* `bind()` bind an address to a socket (TCP, UDP)
* `register_service()` register an application as a handler for a service (TCP, UDP; function pointer, port, protocol)
* `set_socket_mailbox()` manually set or change the pointer to a socket's signal mailbox
* `listen()` set up a socket to listen on a port (TCP; must `bind()`, and `register_service()` first)
* `accept()` accept a client connection (TCP)
* `connect()` open a connection to a remote host (TCP; supports UDP but not necessary)
* `send()` send data to a socket (TCP)
* `recv()` receive data from a socket (TCP)
* `recvq()` get the number of bytes queued in a socket's receive buffer
* `sendq()` get the number of bytes queued in a socket's transmit buffer
* `sendto()` send data to a socket/remote host (UDP)
* `recvfrom()` receive data from a socket/remote host (UDP)
* `disconnect()` close a connection (TCP, UDP)


### Setting up a server (TCP):
1. register a port/protocol pair (e.g., 80, TCP) with `register_service()`
2. check out a new socket (validate socket number to check for errors) with `new_socket()`
3. bind the socket to an IP address and port (e.g. 192.168.1.10, 80) with `bind()`
4. set the socket to listen with `listen()`
5. wait for a valid socket number to be returned from `accept()`. This will be the socket of a newly connected client. From this point, _that_ socket number can be used to send data to/receive from the remote host, using `send()` and `recv()`.
6. use `disconnect()` to close a socket

_See http-server-example1.spin2 for an example_


### Setting up a server / receiving datagrams from a remote host (UDP):
1. register a port/protocol pair (e.g., 1234, UDP): `register_service()`
2. check out a new socket (validate socket number to check for errors) with `new_socket()`
3. bind a socket to an IP address (e.g. 192.168.1.10, 80): `bind()`
4. Call `recvfrom()` to read a maximum length of data. Return value indicates/implies reception with length actually received. Remote host's IP and port are readable indirectly.
5. use `disconnect()` to close a socket

_See UDP-RecvDemo.spin2 for an example_


### Sending datagrams (UDP) to a remote host:
1. check out a new socket (validate socket number to check for errors) using `new_socket()`
2. bind a socket to an IP address (e.g. 192.168.1.10, 80): `bind()`
3. Call `sendto()`
4. use `disconnect()` to close a socket

_See UDP-SendDemo.spin2 for an example_


