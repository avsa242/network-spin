{
    --------------------------------------------
    Filename: socketman-onesocket.spin
    Author: Jesse Burt
    Description: Socket manager
        * one TCP socket
    Started Nov 8, 2023
    Updated Nov 21, 2023
    Copyright 2023
    See end of file for terms of use.
    --------------------------------------------
}

#include "net-common.spinh"
#define TERM_DRIVER "com.serial.terminal.ansi"
#pragma exportdef(TERM_DRIVER)

dat objname byte "[SOCKMGR] ", 0                ' identify this object in debug output

con

    { limits }
    SENDQ_SZ            = 128
    RECVQ_SZ            = 128
    MAX_ARP_ATTEMPTS    = 5                     ' max tries to resolve an IP to a MAC

    { socket states }
    #0, CLOSED, SYN_SENT, SYN_RECEIVED, ESTABLISHED, FIN_WAIT_1, FIN_WAIT_2, CLOSE_WAIT, ...
    CLOSING, LAST_ACK, TIME_WAIT, LISTEN


    { error codes }
    OK                  = 0
    NO_ERROR            = OK


var

    long netif                                  ' pointer to network interface driver object

    long _timestamp_last_arp_req                ' timestamp of last outgoing ARP request
    byte _last_arp_answer                       ' ARP cache entry # of answer to last request

    { socket }
    long _ptr_my_mac
    long _ptr_remote_mac
    byte _my_mac[MACADDR_LEN]

    long _my_ip
    word _local_port
    long _remote_ip
    word _remote_port
    long _iss, _ack_nr, _flags
    long _snd_una, _snd_nxt, _snd_wnd, _snd_wl1, _snd_wl2
    long _irs, _rcv_wnd, _rcv_nxt, _rcv_up
    byte _state, _prev_state

    { socket buffers }
    byte _txbuff[SENDQ_SZ], _rxbuff[RECVQ_SZ]   ' XXX use ring buffers


obj

    net=    NETIF_DRIVER                        ' "virtual" network device object

    ethii:  "protocol.net.eth-ii"               ' OSI protocols
    arp:    "protocol.net.arp"
    ip:     "protocol.net.ip"
    tcp:    "protocol.net.tcp"

    crc:    "math.crc"
    math:   "math.int"
    time:   "time"

    { debugging output }
    util:   "net-util"
    dbg=    "com.serial.terminal.ansi"

var long dptr
pub init(net_ptr, local_ip, local_mac)
' Initialize the socket
'   net_ptr: pointer to the network device driver object
'   local_ip: this node's IP address, in 32-bit form
'   local_mac: pointer to this node's MAC address
    netif := net_ptr
    bytemove(@_my_mac, @net[netif]._mac_local, MACADDR_LEN)
    _ptr_my_mac := @_my_mac

    math.rndseed(cnt)                           ' seed the RNG

    ethii.init(net_ptr)                         ' attach the OSI protocols to the network device
    arp.init(net_ptr)                           ' .
    ip.init(net_ptr)                            ' .
    tcp.init(net_ptr)                           ' .

    ip.set_my_ip32(local_ip)
    _my_ip := local_ip
    arp.cache_entry(local_mac, local_ip)


var long _pending_arp_request
var long _conn  ' XXX temp, for testing
pub loop() | l  ' XXX rename
' Main loop
    _conn := 1  'XXX temp, for testing
    testflag := true
    repeat
        if ( net[netif].pkt_cnt() )
            get_frame()
            if ( ethii.ethertype() == ETYP_ARP )
                process_arp()
            elseif ( ethii.ethertype() == ETYP_IPV4 )
                process_ipv4()
                'printf1(@"flags: %09.9b\n\r", tcp.flags())
                'printf2(@"ack_nr=%d  _snd_nxt=%d\n\r", tcp.ack_nr(), _snd_nxt)
        if ( _conn )    ' XXX temp, for testing
            if ( connect(10,42,0,1, 23) == 1 )
                _conn := false                  ' once connected, clear this flag
        if ( _state == ESTABLISHED and testflag == true)
            send_test_data()
        if ( _pending_arp_request )
            if ( ||(cnt-_timestamp_last_arp_req) => clkfreq )
                strln(@"new pending ARP request")
                { don't send out another request unless at least 1 second has elapsed }
                arp_request()
                if (    (_last_arp_answer > 0) and ...
                        (arp.read_entry_ip(_last_arp_answer) == _pending_arp_request) )
                    strln(@"last ARP reply was an answer to the pending ARP request; clearing")
                    _pending_arp_request := 0
        if dbg[dptr].rx_check() == "c"
            strln(@"closing")
            disconnect()


pub arp_request(): ent_nr
' Send an ARP request to resolve an IP
    if ( _pending_arp_request )                 ' basic sanity check
        strln(@"arp_request(): received request")
        ent_nr := -1'XXX specific error code

        { see if the IP is already in the ARP cache }
        ent_nr := arp.read_entry_by_proto_addr(_pending_arp_request)
        if ( ent_nr > 0 )
            printf1(@"arp_request(): found IP in ARP cache: entry #%d\n\r", ent_nr)
            'xxx review: why were we setting these ARP params after the lookup? should we still?
            arp.set_target_hw_addr( arp.hw_ent(ent_nr) )
            arp.set_target_proto_addr( _pending_arp_request )
            arp.set_sender_hw_addr( _ptr_my_mac )
            arp.set_sender_proto_addr( _my_ip )
            _last_arp_answer := ent_nr
            return ent_nr                       ' == the entry # in the table/cache

        { not yet cached; ask the network for who the IP belongs to }
        strln(@"arp_request(): not cached; requesting resolution...")
        net[netif].start_frame()
        ethii.new(_ptr_my_mac, @_mac_bcast, ETYP_ARP)
        arp.who_has(_my_ip, _pending_arp_request)
        net[netif].send_frame()
        _timestamp_last_arp_req := cnt          ' mark now as the last time we sent a request


pub check_seq_nr(dlen): status | seq
' Check/validate the sequence number during a synchronized connection state
'   Returns:
'       0: sequence number acceptable
'       -1: sequence number bad
    strln(@"check the seq num")
    status := OK
    seq := tcp.seq_nr()
    if ( (dlen == 0) and (_rcv_wnd == 0) )
        if ( seq == _rcv_nxt )
            status := OK
    if ( (dlen == 0) and (_rcv_wnd > 0) )
        if ( (seq => _rcv_nxt) and (seq < (_rcv_nxt+_rcv_wnd)) )
            status := OK
    if ( (dlen > 0) and (_rcv_wnd == 0) )
        strln(@"    SEQ bad")
        return -1'xxx
    if ( (dlen > 0) and (_rcv_wnd > 0) )
        if (    (seq => _rcv_nxt) and ( seq < (_rcv_nxt+_rcv_wnd) ) ...
                    or ...
                (((seq+(dlen-1)) => _rcv_nxt) and (seq+(dlen-1)) < (_rcv_nxt+_rcv_wnd)) )
            status := OK


pub close()
' Close the socket (effectively delete the transmission control block)
    if ( _state <> CLOSED )
        _ptr_remote_mac := 0
        _local_port := 0
        _remote_ip := 0
        _remote_port := 0
        _iss := 0
        _ack_nr := 0
        _flags := 0
        _snd_una := _snd_nxt := _snd_wnd := _snd_wl1 := _snd_wl2 := 0
        _irs := _rcv_wnd := _rcv_nxt := 0
        _state := _prev_state := CLOSED
        bytefill(@_txbuff, 0, SENDQ_SZ)
        bytefill(@_rxbuff, 0, RECVQ_SZ)


pub connect(ip0, ip1, ip2, ip3, dest_port): status | dest_addr, arp_ent, dest_mac, attempt
' Connect to a remote host
'   ip0..ip3: IP address octets (e.g., for 192.168.1.1: 192,168,1,1)
'   dest_port: remote port
    dest_addr := ip0 | (ip1 << 8) | (ip2 << 16) | (ip3 << 24)
    if ( _state == CLOSED )                     ' only attempt if the socket isn't in use
        util.show_ip_addr(@"connecting to ", dest_addr, string("...", 10, 13))
        arp_ent := arp.read_entry_by_proto_addr(dest_addr)
        if ( arp_ent > 0 )
        { if we know the MAC address associated with this IP, we can set up the socket
            and request a connection }
            strln(@"IP resolved; setting up socket")
            { set up the remote node in the socket }
            _remote_ip := dest_addr
            _remote_port := dest_port
            _ptr_remote_mac := arp.read_entry_mac(arp_ent)
            _local_port := 49152+math.rndi(16383)
            _flags := tcp.SYN                   ' will synchronize on first connection
            _rcv_wnd := RECVQ_SZ
            _rcv_nxt := 0
            _snd_wnd := SENDQ_SZ
            _snd_una := _iss := math.rndi(posx)
            _snd_nxt := _iss
            send_segment()
            _snd_nxt++
            set_state(SYN_SENT)
            return 1
        else
            ifnot ( _pending_arp_request )
                strln(@"requesting IP resolution")
                _pending_arp_request := dest_addr
            else
                strln(@"another ARP request is already queued")
                return -1'XXX specific error code: arp busy
        return -1'XXX specific error code: arp can't resolve
    return -1'XXX specific error code: socket already open


pub disconnect(): status | ack, seq, dp, sp, tcplen, frm_end
' Disconnect the socket
'   Returns:
'       0: success
'       -1: error (socket not open)
    case _state
        ESTABLISHED:                            ' connection must be established to close it
            tcp_send(   _local_port, _remote_port, ...
                        _snd_nxt, _rcv_nxt, ...
                        tcp.FIN | tcp.ACK, ...
                        128, ...
                        0 )
            _snd_nxt++
            set_state(FIN_WAIT_1)
        other:
            return -1'xxx specific error: socket not open


pub get_frame(): etype
' Get a frame of data from the network device
'   Returns: ethertype of frame
    'strln(@"get_frame()")
    net[netif].get_frame()
    ethii.rd_ethii_frame()                      ' read in the Ethernet-II header
    return ethii.ethertype()


pub process_arp()
' Process received ARP messages
    arp.rd_arp_msg()
    case arp.opcode()
        arp.ARP_REQ:
            strln(@"process_arp(): REQ")
            if ( arp.target_proto_addr() == _my_ip )
                { respond to requests for our IP/MAC }
                net[netif].start_frame()
                ethii.new(arp.hw_ent(0), arp.sender_hw_addr(), ETYP_ARP)
                arp.set_opcode(arp.ARP_REPL)
                arp.set_target_proto_addr(arp.sender_proto_addr())
                arp.set_target_hw_addr(arp.sender_hw_addr())
                arp.set_sender_proto_addr(ip.my_ip())
                arp.set_sender_hw_addr(arp.hw_ent(0))
                arp.wr_arp_msg()
                net[netif].send_frame()
            if ( arp.sender_proto_addr() == arp.target_proto_addr() )
                { gratuitous ARP announcement }
                'strln(@"gratuitous ARP")
                _last_arp_answer := arp.cache_entry( arp.sender_hw_addr(), arp.sender_proto_addr() )
        arp.ARP_REPL:
            strln(@"process_arp(): REPL")
            arp.cache_entry( arp.sender_hw_addr(), arp.sender_proto_addr() )


pub process_ipv4()
' Process incoming IPv4 header, and hand off to the appropriate layer-4 processor
    ip.rd_ip_header()
    if ( (ip.dest_addr() == _my_ip) and (ip.src_addr() == _remote_ip) )
        strln(@"frame is sent to us")
        if ( ip.layer4_proto() == L4_TCP )
            process_tcp()


pub process_tcp(): tf | ack, seq, tcplen, frm_end, sp, dp, dlen, ack_accept, seq_accept
' Process incoming TCP segment
    tcp.rd_tcp_header()
    ifnot ( (tcp.dest_port() == _local_port) and (tcp.source_port() == _remote_port) )
        strln(@"connection refused")
        sp := tcp.dest_port()
        dp := tcp.source_port()
        seq := tcp.ack_nr()
        ack := tcp.seq_nr()
        tcp_send(   sp, dp, ...
                    seq, ack, ...
                    tcp.RST | tcp.ACK, ...
                    0 )
        return -1'xxx connection refused - doesn't match this socket
    dlen := ( ip.dgram_len() - ip.IP_HDR_SZ - tcp.header_len() )
    case _state
        CLOSED:
            strln(@"    state: CLOSED")
            if ( tcp.flags() & tcp.RST )
                strln(@"    RST received; discard")
                return -1                           ' discard
            else
                ifnot ( tcp.flags() & tcp.ACK )     ' received with ACK bit clear
                    strln(@"    ACK clear")
                    seq := 0
                    ack := tcp.seq_nr() + dlen
                    _flags := tcp.RST | tcp.ACK
                else                                ' received with ACK bit set
                    strln(@"    ACK set")
                    seq := tcp.ack_nr()
                    _flags := tcp.RST
                strln(@"    sending reset")
                tcp_send(   tcp.dest_port(), tcp.source_port(), ...
                            ack, seq, ...
                            tcp.RST | tcp.ACK, ...
                            0 )
            return -1'xxx specific error code
        LISTEN:
            strln(@"state: LISTEN")
            '1. check for RST
                'ignore
            '2. check for ACK
                'bad - send reset, seq=tcp.ack, _flags=RST, return
            '3. check for SYN
                'check security (ignored for now)
            '_rcv_nxt := tcp.seq_nr()+1
            '_irs := tcp.seq_nr()
            '_iss := math.rndi(posx)
            'send segment: seq=_iss, ack=rcv.nxt, _flags=SYN|ACK
            '_snd_nxt := _iss+1
            '_snd_una := _iss
            '_state := SYN_RECEIVED
            ' other ctrl or data will be processed in SYN_RECEIVED state (proc of SYN|ACK don't repeat)
            ' if listen not fully specd (foreign socket not fully specd), fill in unspec fields
            '4. other text or ctrl
                'drop segment
        SYN_SENT:
            strln(@"state: SYN_SENT")
            '1. check ACK bit
            strln(@"check ACK bit")
            ack_accept := false
            if ( tcp.flags() & tcp.ACK )
                strln(@"    ACK received")
                if ( (tcp.ack_nr() =< _iss) or (tcp.ack_nr() > _snd_nxt) )
                { if the remote's ACK is bad, send a reset (unless the remote segment also
                    had the RST bit set - in that case, simply drop the segment) }
                    str(@"    bad ACK num - ")
                    if ( tcp.flags() & tcp.RST )
                        { drop }
                        strln(@"    dropping")
                        return -1'xxx
                    else
                        { send reset }
                        strln(@"    sending reset")
                        seq := tcp.ack_nr()
                        ack := 0    'xxx not specd in RFC...this ok?
                        _flags := tcp.RST
                        tcp_send(   tcp.dest_port(), tcp.source_port(), ...
                                    seq, ack, ...
                                    _flags, ...
                                    0 )
                        return -1'xxx
                if ( (tcp.ack_nr() => _snd_una) and (tcp.ack_nr() =< _snd_nxt) )
                    strln(@"    ACK is good")
                    ' ACK is acceptable
                    ack_accept := true
            '2. check RST bit
            str(@"check RST bit: ")
            if ( tcp.flags() & tcp.RST )
                str(@"    RST - ")
                if ( ack_accept )
                    strln(@"error: connection reset")
                    disconnect()
                    return -1
                else
                    strln(@"dropped")
                    return -1
            '---
            '3. check security/precedence (ignored for now)
            '---
            ifnot ( ack_accept )
                strln(@"ack_accept != true")
                return -1'xxx
            '4. check the SYN bit
            str(@"check the SYN bit: ")
            if ( tcp.flags & tcp.SYN )
                strln(@"SYN")
                _rcv_nxt := tcp.seq_nr() + 1
                _irs := tcp.seq_nr()
                _snd_una := tcp.ack_nr()
                ' future: any segments on the retrans queue which are ack'd should be removed
                if ( _snd_una > _iss )
                    strln(@"    SYN_SENT -> ESTABLISHED")
                    set_state(ESTABLISHED)
                    seq := _snd_nxt
                    ack := _rcv_nxt
                    _flags := tcp.ACK
                    tcp_send(   _local_port, _remote_port, ...
                                seq, ack, ...
                                _flags, ...
                                _snd_wnd )  'xxx is window param correct here?
                else
                    strln(@"    LISTEN - > SYN_RECEIVED")
                    set_state(SYN_RECEIVED)
                    seq := _iss
                    ack := _rcv_nxt
                    _flags := tcp.SYN | tcp.ACK
                    tcp_send(   _local_port, _remote_port, ...
                                seq, ack, ...
                                _flags, ...
                                _snd_wnd )
            '5. if no SYN or RST, drop
            else                                ' SYN not set
                ifnot ( tcp.flags() & tcp.RST ) ' no RST received
                    strln(@"no SYN, no RST - drop")
                    set_state(CLOSED)'xxx actually clean up the TCB
                    return -1'xxx drop
                else                            ' RST received
                    strln(@"RESET")
                    set_state(CLOSED)'xxx ditto
                    return -1'xxx drop
        SYN_RECEIVED, ESTABLISHED, FIN_WAIT_1, FIN_WAIT_2, CLOSE_WAIT, CLOSING, LAST_ACK, TIME_WAIT:
            if ( _state == ESTABLISHED )
                strln(@"state: ESTABLISHED")
            '1. check the seq num
            seq_accept := (check_seq_nr(dlen) == OK)
            if ( seq_accept )
                strln(@"        seq_nr acceptable")
                _rcv_nxt += dlen
                tcp_send(   _local_port, _remote_port, ...
                            _snd_nxt, _rcv_nxt, ...
                            tcp.ACK, ...
                            _rcv_wnd )
                return dlen
            else
                strln(@"        bad seq_nr - dropping")
                ifnot ( tcp.flags() & tcp.RST )
                    tcp_send(   _local_port, _remote_port, ...
                                _snd_nxt, _rcv_nxt, ...
                                tcp.ACK, ...
                                _rcv_wnd )
                return -1'xxx drop
            '2. check the RST bit
            str(@"    check the RST bit: ")
            if ( tcp.flags() & tcp.RST )
                strln(@" set")
                case _state
                    SYN_RECEIVED:
                        strln(@"    SYN_RECEIVED")
                        if ( _prev_state == LISTEN )
                        'xxx if this was a passive OPEN/LISTEN conn, return to that state
                            set_state(LISTEN)
                        elseif ( _prev_state == SYN_SENT )
                        'xxx if it was an active OPEN (came from SYN_SENT),
                        'xxx then the connection was refused
                            'xxx signal connection refused
                            set_state(CLOSED)
                        'xxx in either case, empty the retrans queue
                        'xxx if active open, enter CLOSED state, delete TCB, return
                        return -1'xxx
                    ESTABLISHED, FIN_WAIT_1, FIN_WAIT_2, CLOSE_WAIT:
                        strln(@"    ESTABLISHED, FIN_WAIT_1, FIN_WAIT_2, CLOSE_WAIT -> CLOSED")
                    'xxx if RST is set, any outstanding rx and tx should recv 'reset' resp
                    'xxx flush all segment queues
                    'xxx signal 'connection reset' to user
                    'xxx enter CLOSED state, delete TCB, return
                        set_state(CLOSED)
                    CLOSING, LAST_ACK, TIME_WAIT:
                        strln(@"    CLOSING, LAST_ACK, TIME_WAIT -> CLOSED")
                        set_state(CLOSED)
                        return -1'xxx
            '3. check security/precedence (ignore for now)
            '4. check the SYN bit
            str(@"check the SYN bit: ")
            if ( tcp.flags() & tcp.SYN )
                strln(@"set")
                if ( (tcp.seq_nr() => _rcv_nxt) and (tcp.seq_nr() < (_rcv_nxt+_rcv_wnd)) )
                    strln(@"    bad SEQ; sending reset")
                    seq := 0
                    ack := tcp.seq_nr()
                    tcp_send(   _local_port, _remote_port, ...
                                seq, ack, ...
                                tcp.RST, ...
                                0 )
                    'xxx flush queues
                    'xxx send connection reset signal to user
                    set_state(CLOSED)
                    'xxx delete TCB
                    return -1'xxx
            '5. check the ACK field
            str(@"check the ACK field: ")
            ifnot ( tcp.flags() & tcp.ACK )
                strln(@"not set; dropped")
                return -1'xxx drop
            else
                strln(@"set")
                case _state
                    SYN_RECEIVED:
                        strln(@"    SYN_RECEIVED")
                        if ( (tcp.ack_nr() => _snd_una) and (tcp.ack_nr() =< _snd_nxt) )
                            strln(@"    SYN_RECEIVED -> ESTABLISHED")
                            set_state(ESTABLISHED)
                            'xxx continue processing... put this case inside repeat loop?
                        else
                            'xxx explain this path
                            strln(@"    RESET")
                            seq := tcp.ack_nr()
                            ack := 0
                            tcp_send(   _local_port, _remote_port, ...
                                        seq, ack, ...
                                        tcp.RST, ...
                                        0 )
                            return -1'xxx
                    ESTABLISHED:
                        strln(@"    ESTABLISHED")
                        if ( (tcp.ack_nr() > _snd_una) and (tcp.ack_nr() =< _snd_nxt) )
                            strln(@"    OK: ACK > SND.UNA && ACK =< SND.NXT")
                            _snd_una := tcp.ack_nr()
                            'xxx any segs on the rt queue which that acks are removed
                            'xxx signal to user SEND was 'ok'
                        if ( tcp.ack_nr() < _snd_una )
                            strln(@"    duplicate ACK; dropped")
                            'duplicate ack
                            return 0'ignore
                        if ( tcp.ack_nr() > _snd_nxt )
                            strln(@"    ACK to segment not yet seen; dropped")
                            'segment not yet seen
                            'xxx RFC says to ACK this, but why?
                            'xxx other sources suggest some other TCP/IP stacks don't
                            return 0'drop
                        if ( (tcp.ack_nr() > _snd_una) and (tcp.ack_nr() =< _snd_nxt) )
                            'xxx update send window
                            strln(@"    OK: ACK > SND.UNA && ACK =< SND.NXT")
                            if (    ((tcp.seq_nr() > _snd_wl1) or (_snd_wl1 == tcp.seq_nr())) and ...
                                    (tcp.ack_nr() => _snd_wl2) )
                                strln(@"        OK: (SEQ > WL1 || WL1 == SEQ) && (ACK => WL2)")
                                _snd_wnd := tcp.window()
                                _snd_wl1 := tcp.seq_nr()    ' seq_nr of last seg used to update win
                                _snd_wl2 := tcp.ack_nr()    ' ack_nr of last seg used to update win
                    FIN_WAIT_1:
                        strln(@"    FIN_WAIT_1")
                    'xxx if our FIN is ack'd, enter FIN_WAIT_2, continue processing
                    FIN_WAIT_2:
                        strln(@"    FIN_WAIT_2")
                    'xxx if RT queue is empty, user's CLOSE can be ack'd (don't delete TCB yet)
                    CLOSING:
                        strln(@"    CLOSING")
                    'xxx same processing as ESTABLISHED
                    LAST_ACK:
                        strln(@"    LAST_ACK")
                    'xxx only ACK of our FIN is acceptable here. If it is, delete the TCB,
                    'xxx enter CLOSED state, return
                    TIME_WAIT:
                        strln(@"    TIME_WAIT")
                    'xxx only retransmission of remote FIN is acceptable here
                    'xxx ACK it, and restart the 2MSL timeout
            '6. check urgent bit
            str(@"check urgent bit: ")
            if ( tcp.flags() & tcp.URG )
                strln(@"set")
                case _state
                    ESTABLISHED, FIN_WAIT_1, FIN_WAIT_2:
                        strln(@"    ESTABLISHED, FIN_WAIT_1, FIN_WAIT_2")
                        _rcv_up := ( _rcv_up #> tcp.urgent_ptr() )
                        'xxx signal to user remote host has urgent data (if rcv_up is in advance of
                        'xxx    the data consumed
                        'xxx ifalready signalled, or still in urgent mode, don't repeat signal
                    CLOSE_WAIT, CLOSING, LAST_ACK, TIME_WAIT:
                        strln(@"    CLOSE_WAIT, CLOSING, LAST_ACK, TIME_WAIT")
                        return 0'ignore
            '7. process segment text
            str(@"process segment text: ")
            if ( dlen )
                printf1(@"%d bytes\n\r", dlen)
                case _state
                    ESTABLISHED, FIN_WAIT_1, FIN_WAIT_2:
                        strln(@"    ESTABLISHED, FIN_WAIT_1, FIN_WAIT_2")
                        'xxx this needs to use a circular buffer and receive only what's
                        'xxx    possible, i.e. how much there's existing space for
                        net[netif].rdblk_lsbf(@_rxbuff, dlen)
                    'xxx from the TCP RFC 793:
                    {Once in the ESTABLISHED state, it is possible to deliver segment
                            text to user RECEIVE buffers.  Text from segments can be moved
                            into buffers until either the buffer is full or the segment is
                            empty.  If the segment empties and carries an PUSH flag, then
                            the user is informed, when the buffer is returned, that a PUSH
                            has been received.

                            When the TCP takes responsibility for delivering the data to the
                            user it must also acknowledge the receipt of the data.

                            Once the TCP takes responsibility for the data it advances
                            RCV.NXT over the data accepted, and adjusts RCV.WND as
                            apporopriate to the current buffer availability.  The total of
                            RCV.NXT and RCV.WND should not be reduced.

                            Please note the window management suggestions in section 3.7.

                            Send an acknowledgment of the form:

                              <SEQ=SND.NXT><ACK=RCV.NXT><CTL=ACK>

                            This acknowledgment should be piggybacked on a segment being
                            transmitted if possible without incurring undue delay.
                    }
                    CLOSE_WAIT, CLOSING, LAST_ACK, TIME_WAIT:
                        strln(@"    EXCEPTION: dropped (CLOSE_WAIT, CLOSING, LAST_ACK, TIME_WAIT")
                    { this shouldn't happen; if we're in this state, we received a FIN }
                        return 0                ' ignore
            '8. check the FIN bit
            str(@"check FIN bit")
            if ( tcp.flags() & tcp.FIN )
                strln(@"set")
                case _state
                    CLOSED, LISTEN, SYN_SENT:
                        strln(@"    EXCEPTION: dropped (CLOSED, LISTEN, SYN_SENT)")
                        return -1               ' drop
                'xxx signal user the connection is closing
                'xxx deliver pending receives
                _rcv_nxt++
                tcp_send(   _local_port, _remote_port, ...
                            _snd_nxt, _rcv_nxt, ...
                            tcp.ACK, ...
                            0 )
                case _state
                    SYN_RECEIVED, ESTABLISHED:
                        strln(@"    SYN_RECEIVED, ESTABLISHED")
                        set_state(CLOSE_WAIT)
                    FIN_WAIT_1:
                        strln(@"    FIN_WAIT_1")
                        'xxx if our FIN has been ACKed, enter TIME_WAIT, start timer,
                        'xxx    turn off other timers; else, enter CLOSING state
                    FIN_WAIT_2:
                        strln(@"    FIN_WAIT_2")
                        'xxx enter TIME_WAIT; start timer, turn off other timers
                    CLOSE_WAIT:
                        strln(@"    CLOSE_WAIT")
                        'xxx remain here
                    CLOSING:
                        strln(@"    CLOSING")
                        'xxx remain here
                    LAST_ACK:
                        strln(@"    LAST_ACK")
                        'xxx remain here
                    TIME_WAIT:
                        strln(@"    TIME_WAIT")
                        'xxx remain here, but restart the 2MSL time-wait timeout

pub recv_segment(): len
' Receive a TCP segment
'   Returns: length of payload data read
    len := ( ip.dgram_len() - ip.IP_HDR_SZ - tcp.header_len() )

    'printf1(@"snd_wnd before: %d\n\r", _snd_wnd)
    _snd_wnd := tcp.window()
    'printf1(@"snd_wnd after: %d\n\r", _snd_wnd)
    if ( tcp.seq_nr() == _rcv_nxt )
        'strln(@"got expected seq_nr")
        if ( tcp.ack_nr() > _snd_una )          ' update unacknowledged sent data pointer
            'strln(@"ack_nr > snd_una")
            _snd_una := tcp.ack_nr()
        if ( len )                              ' read the payload, if specified
            net[netif].rdblk_lsbf(@_rxbuff, len <# RECVQ_SZ)
            'ser.hexdump(@_rxbuff, 0, 2, len, 16 <# len)
        _flags := tcp.ACK
        'printf1(@"final length: %d\n\r", len)
        if ( tcp.flags() & tcp.FIN )
            len := 1
        _rcv_nxt += len                         ' update the expected next seq # from the remote
        send_segment()                          ' acknowledge the segment
        return len
    else
        { out of order data? }
        return -1'XXX: specific error code
        'printf2(@"got seq_nr %d, expected %d\n\r", tcp.seq_nr(), _rcv_nxt)


pub resolve_ip(remote_ip): ent_nr
' Use ARP to resolve an IP address to a MAC address
'   remote_ip: IP address to resolve, in 32-bit form
'   Returns: entry number in the ARP cache/table, or -1 on failure
    ent_nr := -1'XXX specific error code

    { see if the IP is already in the ARP cache }
    ent_nr := arp.read_entry_by_proto_addr(remote_ip)
    if ( ent_nr > 0 )
        'xxx review: why were we setting these ARP params after the lookup? should we still?
        printf1(@"found IP in ARP cache entry %d\n\r", ent_nr)
        arp.set_target_hw_addr( arp.hw_ent(ent_nr) )
        arp.set_target_proto_addr( remote_ip )
        arp.set_sender_hw_addr( _ptr_my_mac )
        arp.set_sender_proto_addr( _my_ip )
        _last_arp_answer := ent_nr
        return ent_nr                           ' == the entry # in the table/cache

    { not yet cached; ask the network for who the IP belongs to }
    strln(@"not cached; requesting resolution...")
    net[netif].start_frame()
    ethii.new(_ptr_my_mac, @_mac_bcast, ETYP_ARP)
    arp.who_has(_my_ip, remote_ip)
    net[netif].send_frame()

    { wait for a reply }
    repeat
        repeat until net[netif].pkt_cnt()
        printf1(@"frame recvd: %04.4x\n\r", ethii.ethertype())
        net[netif].get_frame()
        ethii.rd_ethii_frame()
    until ( ethii.ethertype() == ETYP_ARP )

    'str(@"ARP ")
    arp.rd_arp_msg()
    if ( arp.opcode() == arp.ARP_REPL )
        if ( arp.sender_proto_addr() == remote_ip )
            { store this IP/MAC as the next available entry in the ARP table }
            ent_nr := arp.cache_entry( arp.sender_hw_addr(), arp.sender_proto_addr() )
            'printf1(@"caching as number %d\n\r", ent_nr)
            _last_arp_answer := ent_nr
        else
            strln(@"wrong ip")
            return -1'XXX specific error code


pub send_segment(len=0) | tcplen, frm_end
' Send a TCP segment
    'printf1(@"_snd_nxt: %d\n\r", _snd_nxt)
    'printf1(@"_snd_una: %d\n\r", _snd_una)
    'printf1(@"_snd_wnd: %d\n\r", _snd_wnd)
    'printf1(@"_snd_nxt-_snd_una: %d\n\r", _snd_nxt-_snd_una)

    if ( (_snd_nxt - _snd_una) < _snd_wnd )     'check for space in the send window first
        'strln(@"snd_nxt-snd_una < snd_wnd")
        tcp_send(   _local_port, _remote_port, ...
                    _snd_nxt, _rcv_nxt, ...
                    _flags, ...
                    _rcv_wnd, ...
                    len )
        _snd_nxt += len
        'printf1(@"snd_nxt now %d\n\r", _snd_nxt)
    'else
        'strln(@"snd_nxt-snd_una is not < snd_wnd")



pub set_state(new_state)
' Change the connection state of the socket
    _prev_state := _state                       ' record the previous state
    _state := new_state

pub tcp_send(sp, dp, seq, ack, flags, win, dlen=0) | tcplen, frm_end
' Send a TCP segment
'   sp, dp: source, destination ports
'   seq, ack: sequence, acknowledgement numbers
'   flags: control flags
'   win: TCP window
'   dlen (optional): payload data length
    ethii.new(_ptr_my_mac, _ptr_remote_mac, ETYP_IPV4)
        ip.new(ip.TCP, _my_ip, _remote_ip)
            tcp.set_source_port(sp)
            tcp.set_dest_port(dp)
            tcp.set_seq_nr(seq)
            tcp.set_ack_nr(ack)
            tcp.set_header_len(20)    ' XXX hardcode for now; no TCP options yet
            tcplen := tcp.header_len() + dlen
            tcp.set_flags(flags)
            tcp.set_window(win)
            tcp.set_checksum(0)
            tcp.wr_tcp_header()
            if ( dlen > 0 )                  ' attach payload (XXX untested)
                printf1(@"send_segment(): length is %d, attaching payload\n\r", dlen)
                net[netif].wrblk_lsbf(@_txbuff, dlen <# SENDQ_SZ)
            frm_end := net[netif].fifo_wr_ptr()
            net[netif].inet_checksum_wr(tcp._tcp_start, ...
                                        tcplen, ...
                                        tcp._tcp_start+TCPH_CKSUM, ...
                                        tcp.pseudo_header_cksum(_my_ip, _remote_ip, dlen))
        net[netif].fifo_set_wr_ptr(frm_end)
        ip.update_chksum(tcplen)
    net[netif].send_frame()


{ debugging methods }
pub set_debug_obj(p)

    dptr := p
    util.attach(p)


pub str(pstr)

    'dbg[dptr].str(@objname)
    dbg[dptr].str(pstr)


pub strln(pstr)

    'dbg[dptr].str(@objname)
    dbg[dptr].strln(pstr)


pub printf1(pfmt, p1)

    'dbg[dptr].str(@objname)
    dbg[dptr].printf1(pfmt, p1)


pub printf2(pfmt, p1, p2)

    'dbg[dptr].str(@objname)
    dbg[dptr].printf2(pfmt, p1, p2)


var long testflag
dat test_data byte "Test data", 10, 13, 0
pub send_test_data() | dlen

    dlen := strsize(@test_data)
    bytemove(@_txbuff, @test_data, dlen)
    send_segment(dlen)
    testflag := false


DAT
{
Copyright 2023 Jesse Burt

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
associated documentation files (the "Software"), to deal in the Software without restriction,
including without limitation the rights to use, copy, modify, merge, publish, distribute,
sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or
substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT
OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
}

