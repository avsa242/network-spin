{
    --------------------------------------------
    Filename: socketman-onesocket.spin
    Author: Jesse Burt
    Description: Socket manager
        * one TCP socket
    Started Nov 8, 2023
    Updated Nov 26, 2023
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
    _remote_ip := $01_00_2a_0a
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


pub check_seq_nr(seg_len): status | seq
' Check/validate the sequence number during a synchronized connection state
'   Returns:
'       0: sequence number acceptable
'       -1: sequence number bad
    strln(@"check the seq num")
    status := OK
    seq := tcp.seq_nr()
    if ( _rcv_wnd == 0 )
        if ( seg_len > 0 )
            strln(@"    SEQ bad")
            return -1'xxx
        else
            if ( seq == _rcv_nxt )
                return OK
    elseif ( _rcv_wnd > 0 )
        if ( seg_len > 0)
            if (    (seq => _rcv_nxt) and ( seq < (_rcv_nxt+_rcv_wnd) ) ...
                        or ...
                    (((seq+(seg_len-1)) => _rcv_nxt) and (seq+(seg_len-1)) < (_rcv_nxt+_rcv_wnd)) )
                return OK
        elseif ( seg_len == 0 )
            if ( (seq => _rcv_nxt) and (seq < (_rcv_nxt+_rcv_wnd)) )
                return OK


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


pub process_tcp(): tf | ack, seq, flags, seg_len, tcplen, frm_end, sp, dp, ack_accept, seq_accept
' Process incoming TCP segment
    tcp.rd_tcp_header()
    seg_len := ( ip.dgram_len() - ip.IP_HDR_SZ - tcp.header_len() )
    case _state
        CLOSED:
            { If the state is CLOSED (i.e., TCB does not exist) then all data in the incoming
                segment is discarded }
            strln(@"    state: CLOSED")
            if ( tcp.flags() & tcp.RST )
                { An incoming segment containing a RST is discarded }
                strln(@"    RST received; discard")
                return -1                       ' discard
            else
                { An incoming segment not containing a RST causes a RST to be sent in response }
                if ( tcp.flags() & tcp.ACK )    ' xxx behavior unverified
                    { If the ACK bit is on... }
                    seq := tcp.ack_nr()
                    ack := 0'xxx unspecified in RFC
                    flags := tcp.RST
                else
                    { If the ACK bit is off, sequence number zero is used }
                    seq := 0
                    ack := tcp.seq_nr()+seg_len
                    flags := tcp.RST | tcp.ACK
                strln(@"    sending reset")
                tcp_send(   tcp.dest_port(), tcp.source_port(), ...
                            ack, seq, ...
                            flags, ...
                            0 )
            return -1'xxx error: socket/TCB doesn't exist
        LISTEN:
            strln(@"    state: LISTEN")
            if ( tcp.flags() & tcp.RST )
                { first check for an RST }
                strln(@"    RST set")
                return 0                        ' ignore
            if ( tcp.flags() & tcp.ACK )        ' xxx behavior unverified
                { second, check for an ACK: Any acknowledgment is bad if it arrives on a
                    connection still in the LISTEN state }
                strln(@"    ACK set")
                tcp_send(   _local_port, tcp.source_port(), ...
                            tcp.ack_nr(), 0, ...
                            tcp.RST, ...
                            0 )
                return 0                        ' ignore
            if ( tcp.flags() & tcp.SYN )
                { third check for a SYN }
                { NOTE: security/compartment is ignored }
                strln(@"    SYN set")
                _rcv_nxt := tcp.seq_nr()+1
                _irs := tcp.seq_nr()
                _iss := math.rndi(posx)         ' select our initial send sequence
                { fill in the remote socket data and complete the handshake }
                _remote_ip := ip.src_addr()
                _remote_port := tcp.source_port()
                util.show_ip_addr(@"    remote socket: ", _remote_ip, @":")
                printf1(@"%d\n\r", _remote_port)
                tcp_send(   _local_port, _remote_port, ...
                            _iss, _rcv_nxt, ...
                            tcp.SYN | tcp.ACK, ...
                            _snd_wnd )
                _snd_nxt := _iss+1
                _snd_una := _iss
                _state := SYN_RECEIVED
                return 1
        SYN_SENT:
            { first, check the ACK bit }
            strln(@"    state: SYN_SENT")
            ack_accept := false
            if ( tcp.flags() & tcp.ACK )        ' if the ACK bit is set, check the ACK number
                strln(@"    ACK set")
                if ( (tcp.ack_nr() =< _iss) or (tcp.ack_nr() > _snd_nxt) )
                    { bad ACK number }
                    strln(@"    ACK number bad")'xxx behavior unverified
                    if ( tcp.flags() & tcp.RST )
                        { received with reset; ignore }
                        strln(@"    RST set; drop")
                        return -1'xxx           ' drop segment and return
                    else
                        { received without reset; send one }
                        strln(@"    RST not set; sending RST")
                        seq := tcp.ack_nr()
                        ack := 0
                        tcp_send(   _local_port, _remote_port, ...
                                    seq, ack, ...
                                    tcp.RST, ...
                                    0 )
                        return -1'xxx           ' drop segment and return
                if ( (tcp.ack_nr() > _snd_una) and (tcp.ack_nr() =< _snd_nxt) )
                    { ACK number is acceptable }
                    strln(@"    ACK number is good")
                    ack_accept := true
            { second, check the RST bit }
            if ( tcp.flags() & tcp.RST )        ' if the RST bit is set
                strln(@"    RST set")
                if ( ack_accept )
                    strln(@"    (ACK was acceptable)")
                    'xxx _signal := ECONN_RESET
                    'xxx callback function for user signals?
                    strln(@"    state -> CLOSED")
                    set_state(CLOSED)
                    'xxx delete_tcb()
                strln(@"    error: connection reset")
                return -1'xxx

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

pub tcp_send(sp, dp, seq, ack, flags, win, seg_len=0) | tcplen, frm_end
' Send a TCP segment
'   sp, dp: source, destination ports
'   seq, ack: sequence, acknowledgement numbers
'   flags: control flags
'   win: TCP window
'   seg_len (optional): payload data length
    ethii.new(_ptr_my_mac, _ptr_remote_mac, ETYP_IPV4)
        ip.new(ip.TCP, _my_ip, _remote_ip)
            tcp.set_source_port(sp)
            tcp.set_dest_port(dp)
            tcp.set_seq_nr(seq)
            tcp.set_ack_nr(ack)
            tcp.set_header_len(20)    ' XXX hardcode for now; no TCP options yet
            tcplen := tcp.header_len() + seg_len
            tcp.set_flags(flags)
            tcp.set_window(win)
            tcp.set_checksum(0)
            tcp.wr_tcp_header()
            if ( seg_len > 0 )                  ' attach payload (XXX untested)
                printf1(@"send_segment(): length is %d, attaching payload\n\r", seg_len)
                net[netif].wrblk_lsbf(@_txbuff, seg_len <# SENDQ_SZ)
            frm_end := net[netif].fifo_wr_ptr()
            net[netif].inet_checksum_wr(tcp._tcp_start, ...
                                        tcplen, ...
                                        tcp._tcp_start+TCPH_CKSUM, ...
                                        tcp.pseudo_header_cksum(_my_ip, _remote_ip, seg_len))
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
pub send_test_data() | seg_len

    seg_len := strsize(@test_data)
    bytemove(@_txbuff, @test_data, seg_len)
    send_segment(seg_len)
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

