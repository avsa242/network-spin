{
    --------------------------------------------
    Filename: socketman-onesocket.spin
    Author: Jesse Burt
    Description: Socket manager
        * one TCP socket
    Started Nov 8, 2023
    Updated Nov 9, 2023
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
    #0, CLOSED, SYN_SENT, ESTABLISHED


var

    long netif                                  ' pointer to network interface driver object

    { socket }
    long _ptr_my_mac
    long _ptr_remote_mac
    byte _my_mac[MACADDR_LEN]

    long _my_ip
    word _local_port
    long _remote_ip
    word _remote_port
    long _isn, _ack_nr, _flags
    long _snd_una, _snd_nxt, _snd_wnd
    long _rcv_wnd, _rcv_nxt
    byte _state
    word _our_window

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

    { set up the socket's initial state:
        * choose a random local port from the 49152..65535 range
        * choose a random initial sequence number
        * set the send window }
    _state := CLOSED


var long _conn  ' XXX temp, for testing
pub loop() | l  ' XXX rename
' Main loop
    _conn := 1  'XXX temp, for testing
    testflag := true
    repeat
        if ( net[netif].pkt_cnt() )
            get_frame()
            strln(@"new frame")
            if ( ethii.ethertype() == ETYP_ARP )
                process_arp()
            elseif ( ethii.ethertype() == ETYP_IPV4 )
                if ( segment_matches_this_socket() )
                { see if the segment is for this socket }
                    strln(@"for this socket")
                    l := recv_segment(  ip.dgram_len() - ...
                                        ip.IP_HDR_SZ - ...
                                        tcp.header_len_bytes() )
                    printf1(@"flags: %09.9b\n\r", tcp.flags())
                    printf2(@"ack_nr=%d  _snd_nxt=%d\n\r", tcp.ack_nr(), _snd_nxt)
                    if (    (tcp.flags() == (tcp.SYN|tcp.ACK)) and ...
                            (tcp.ack_nr() == _snd_nxt) and ...
                            _state == SYN_SENT )
                    { in the middle of a 3-way handshake? }
                        strln(@"SYN_SENT")
                        _flags := tcp.ACK
                        _rcv_nxt := tcp.seq_nr()+1
                        send_segment()
                        _state := ESTABLISHED
                        strln(@"connected")
        if ( _conn )    ' XXX temp, for testing
            connect(10,42,0,1, 23)
            _conn := false
        if ( _state == ESTABLISHED and testflag == true)
            send_test_data()

var long testflag
dat test_data byte "Test data", 10, 13, 0
pub send_test_data() | dlen

    dlen := strsize(@test_data)
    bytemove(@_txbuff, @test_data, dlen)
    send_segment(dlen)
    testflag := false


pub connect(ip0, ip1, ip2, ip3, dest_port): status | dest_addr, arp_ent, dest_mac, attempt
' Connect to a remote host
'   ip0..ip3: IP address octets (e.g., for 192.168.1.1: 192,168,1,1)
'   dest_port: remote port
    dest_addr := ip0 | (ip1 << 8) | (ip2 << 16) | (ip3 << 24)
    if ( _state == CLOSED )                     ' only attempt if not already trying to connect
        util.show_ip_addr(@"connecting to ", dest_addr, @"...")
        repeat attempt from 1 to MAX_ARP_ATTEMPTS
            printf1(@"[ARP] resolve IP (attempt %d)\n\r", attempt)
            { first, try to resolve the IP address to a MAC address }
            arp_ent := resolve_ip(dest_addr)
            if ( arp_ent > 0 )
                { found a matching MAC - now initiate the connection }
                strln(@"arp ok")
                dest_mac := arp.read_entry_mac(arp_ent)
                util.show_mac_addr(@"    mac: ", dest_mac, string(10, 13))
                util.show_ip_addr(@"    ip: ", dest_addr, string(10, 13))

                { set up the remote node in the socket }
                _remote_ip := dest_addr
                _remote_port := dest_port
                _ptr_remote_mac := dest_mac
                _local_port := 49152+math.rndi(16383)
                _flags := tcp.SYN                           ' will synchronize on first connection
                _our_window := RECVQ_SZ
                _rcv_wnd := RECVQ_SZ
                _rcv_nxt := 0
                _snd_wnd := SENDQ_SZ
                _snd_una := _isn := math.rndi(posx)
                _snd_nxt := _isn

                send_segment()
                _snd_nxt++
                _state := SYN_SENT
                return 1
            time.sleep(1)                       ' wait between attempts
        return -1'XXX specific error code: arp failure
    return -1'XXX specific error code: socket already open


pub get_frame(): etype
' Get a frame of data from the network device
'   Returns: ethertype of frame
    net[netif].get_frame()
    ethii.rd_ethii_frame()                      ' read in the Ethernet-II header
    return ethii.ethertype()


pub process_arp()
' Process received ARP messages
    arp.rd_arp_msg()
    case arp.opcode()
        arp.ARP_REQ:
            strln(@"[ARP]: REQ")
            if (dptr)
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
                strln(@"gratuitous ARP")
                arp.cache_entry( arp.sender_hw_addr(), arp.sender_proto_addr() )
        arp.ARP_REPL:
            strln(@"[ARP]: REPL")
            arp.cache_entry( arp.sender_hw_addr(), arp.sender_proto_addr() )


pub recv_segment(len=0)
' Receive a TCP segment
'   len (optional): length of payload data to read (up to RECVQ_SZ)
    printf1(@"snd_wnd before: %d\n\r", _snd_wnd)
    _snd_wnd := tcp.window()
    printf1(@"snd_wnd after: %d\n\r", _snd_wnd)
    if ( tcp.seq_nr() == _rcv_nxt )
        strln(@"got expected seq_nr")
        if ( tcp.ack_nr() > _snd_una )          ' update unacknowledged sent data pointer
            strln(@"ack_nr > snd_una")
            _snd_una := tcp.ack_nr()
        if ( len )                              ' read the payload, if specified
            net[netif].rdblk_lsbf(@_rxbuff, len <# RECVQ_SZ)
            'ser.hexdump(@_rxbuff, 0, 2, len, 16 <# len)
        _flags := tcp.ACK
        'printf1(@"final length: %d\n\r", len)
        _rcv_nxt += len                         ' update the expected next seq # from the remote
        send_segment()                          ' acknowledge the segment
    else
        { out of order data? }
        return -1'XXX: specific error code
        printf2(@"got seq_nr %d, expected %d\n\r", tcp.seq_nr(), _rcv_nxt)


pub resolve_ip(remote_ip): ent_nr
' Use ARP to resolve an IP address to a MAC address
'   remote_ip: IP address to resolve, in 32-bit form
'   Returns: entry number in the ARP cache/table, or -1 on failure
    ent_nr := -1'XXX specific error code

    { see if the IP is already in the ARP cache }
    ent_nr := arp.read_entry_by_proto_addr(remote_ip)
    if ( ent_nr > 0 )
        printf1(@"found IP in ARP cache entry %d\n\r", ent_nr)
        arp.set_target_hw_addr( arp.hw_ent(ent_nr) )
        arp.set_target_proto_addr( remote_ip )
        arp.set_sender_hw_addr( _ptr_my_mac )
        arp.set_sender_proto_addr( _my_ip )
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
            printf1(@"caching as number %d\n\r", ent_nr)
        else
            strln(@"wrong ip")
            return -1'XXX specific error code


pub segment_matches_this_socket(): tf
' Verify the segment received is for this socket
'   Returns: TRUE (-1) or FALSE
    tf := false

    ip.rd_ip_header()
    if ( (ip.dest_addr() == _my_ip) and (ip.src_addr() == _remote_ip) )
        if ( ip.layer4_proto() == L4_TCP )
            tcp.rd_tcp_header()
            if (    (tcp.dest_port() == _local_port) and ...
                    (tcp.source_port() == _remote_port) )
                return true


pub send_segment(len=0) | tcplen, frm_end
' Send a TCP segment
    printf1(@"_snd_nxt: %d\n\r", _snd_nxt)
    printf1(@"_snd_una: %d\n\r", _snd_una)
    printf1(@"_snd_wnd: %d\n\r", _snd_wnd)
    printf1(@"_snd_nxt-_snd_una: %d\n\r", _snd_nxt-_snd_una)

    if ( (_snd_nxt - _snd_una) < _snd_wnd )     'check for space in the send window first
        strln(@"snd_nxt-snd_una < snd_wnd")
        ethii.new(_ptr_my_mac, _ptr_remote_mac, ETYP_IPV4)
            ip.new(ip.TCP, _my_ip, _remote_ip)
                tcp.set_source_port(_local_port)
                tcp.set_dest_port(_remote_port)
                tcp.set_seq_nr(_snd_nxt)
                tcp.set_ack_nr(_rcv_nxt)
                tcp.set_header_len_bytes(20)    ' XXX hardcode for now; no TCP options yet
                tcplen := tcp.header_len_bytes() + len
                tcp.set_flags(_flags)
                tcp.set_window(_our_window)
                tcp.set_checksum(0)
                tcp.wr_tcp_header()
                if ( len > 0 )                  ' attach payload (XXX untested)
                    printf1(@"length is %d, attaching payload\n\r", len)
                    net[netif].wrblk_lsbf(@_txbuff, len <# SENDQ_SZ)
                frm_end := net[netif].fifo_wr_ptr()
                net[netif].inet_checksum_wr(tcp._tcp_start, ...
                                            tcplen, ...
                                            tcp._tcp_start+TCPH_CKSUM, ...
                                            tcp.pseudo_header_cksum(_my_ip, _remote_ip, len))
            net[netif].fifo_set_wr_ptr(frm_end)
            ip.update_chksum(tcplen)
        net[netif].send_frame()
        _snd_nxt += len
        printf1(@"snd_nxt now %d\n\r", _snd_nxt)
    else
        strln(@"snd_nxt-snd_una is not < snd_wnd")


{ debugging methods }
pub set_debug_obj(p)

    dptr := p
    util.attach(p)


pub str(pstr)

    dbg[dptr].str(@objname)
    dbg[dptr].str(pstr)


pub strln(pstr)

    dbg[dptr].str(@objname)
    dbg[dptr].strln(pstr)


pub printf1(pfmt, p1)

    dbg[dptr].str(@objname)
    dbg[dptr].printf1(pfmt, p1)


pub printf2(pfmt, p1, p2)

    dbg[dptr].str(@objname)
    dbg[dptr].printf2(pfmt, p1, p2)



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

