{
    --------------------------------------------
    Filename: socketman-onesocket.spin
    Author: Jesse Burt
    Description: Socket manager
        * one TCP socket
    Started Nov 8, 2023
    Updated Dec 16, 2023
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
    MAX_ARP_ATTEMPTS    = 5


    { socket states }
    #0, CLOSED, SYN_SENT, SYN_RECEIVED, ESTABLISHED, FIN_WAIT_1, FIN_WAIT_2, CLOSE_WAIT, ...
    CLOSING, LAST_ACK, TIME_WAIT, LISTEN


    { error codes }
    OK                  = 0
    NO_ERROR            = OK


var

    long netif                                  ' pointer to network interface driver object

    long _cog                                   ' cog ID + 1 of main network I/O loop

    long _timestamp_last_arp_req                ' timestamp of last outgoing ARP request
    byte _last_arp_answer                       ' ARP cache entry # of answer to last request

    { socket }
    long _ptr_my_mac
    long _ptr_remote_mac
    byte _my_mac[MACADDR_LEN]

    { event callbacks/function pointers }
    long on_disconnect, on_connect


    { Transmission Control Block }
    long _local_ip                              ' local socket
    word _local_port
    long _remote_ip                             ' remote socket
    word _remote_port
    long _iss, _flags                           ' sequence number, segment control flags, send pointers
    long _snd_una, _snd_nxt, _snd_wnd, _snd_wl1, _snd_wl2, _snd_up
    long _irs, _rcv_wnd, _rcv_nxt, _rcv_up      ' remote sequence number, receive pointers
    byte _state, _prev_state                    ' connection state


obj

    net=    NETIF_DRIVER                        ' "virtual" network device object

    ethii:  "protocol.net.eth-ii"               ' OSI protocols
    arp:    "protocol.net.arp"
    ip:     "protocol.net.ip"
    tcp:    "protocol.net.tcp"

    crc:    "math.crc"
    math:   "math.int"
    time:   "time"

    { ring buffer objects }
    rxq:    "memory.ring-buffer" | RBUFF_SZ=RECVQ_SZ
    txq:    "memory.ring-buffer" | RBUFF_SZ=SENDQ_SZ

    { debugging output }
    util:   "net-util"
    dbg=    "com.serial.terminal.ansi"


pub null()
' This is not a top-level object


var long dptr
pub init(net_ptr): c
' Initialize the socket
'   net_ptr: pointer to the network device driver object
'   Returns: cog ID+1 of network I/O loop
    on_disconnect := @null                      ' set func pointers to safe defaults
    on_connect := @null

    netif := net_ptr

    math.rndseed(cnt)                           ' seed the RNG

    ethii.init(net_ptr)                         ' attach the OSI protocols to the network device
    arp.init(net_ptr)                           ' .
    ip.init(net_ptr)                            ' .
    tcp.init(net_ptr)                           ' .

    rxq.set_rdblk_lsbf(@net[netif].rdblk_lsbf)  ' bind the RXQ to the enet driver's read function
    txq.set_wrblk_lsbf(@net[netif].wrblk_lsbf)  ' bind the TXQ to the enet driver's write function

    _cog := c := cognew(loop(), @_loop_stk)
'{
    if ( _cog )
        printf1(@"network I/O loop started on cog #%d\n\r", _cog-1)
    else
        strln(@"error: no free cogs available")
'}


var long _loop_stk[200]
var long _pending_arp_request
var long _conn, _disc, _sendq  ' XXX temp, for testing
pub loop() | l, arp_ent, arp_attempt  ' XXX rename
' Main loop
    arp_attempt := 0
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
            'util.show_ip_addr(@"connecting to ", _remote_ip, string("...", 10, 13))
            arp_ent := arp.read_entry_by_proto_addr(_remote_ip)
            if ( arp_ent < 1 )
                ifnot ( _pending_arp_request )
                    strln(@"requesting IP resolution")
                    _pending_arp_request := _remote_ip
                'else
                    'strln(@"another ARP request is already queued")
            else
                _ptr_remote_mac := arp.hw_ent(arp_ent)
                util.show_mac_addr(@"Remote socket cached as ", _ptr_remote_mac, string(10, 13))
                tcp_send_socket( tcp.SYN )
                _snd_nxt++
                set_state(SYN_SENT)
                _conn := false
        if ( _pending_arp_request )
            if ( ||(cnt-_timestamp_last_arp_req) => clkfreq )
                strln(@"new pending ARP request")
                { don't send out another request unless at least 1 second has elapsed }
                if ( arp_attempt < MAX_ARP_ATTEMPTS )
                    arp_request()
                    arp_attempt++
                    printf1(@"attempt %d\n\r", arp_attempt)
                    if (    (_last_arp_answer > 0) and ...
                            (arp.read_entry_ip(_last_arp_answer) == _pending_arp_request) )
                        strln(@"last ARP reply was an answer to the pending ARP request; clearing")
                        _pending_arp_request := 0
                        arp_attempt := 0
                else
                    strln(@"error: MAX_ARP_ATTEMPTS exceeded")
                    _pending_arp_request := 0
                    arp_attempt := 0
                    _conn := false
        if ( _disc )
            strln(@"closing")
            disconnect()
            _disc := 0
        if ( _sendq )
            if ( _state == ESTABLISHED )
                if ( txq.unread_bytes() )
                    tcp_send_socket( (tcp.PSH|tcp.ACK), txq.unread_bytes() )
            _sendq := false


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
            arp.set_sender_hw_addr( net[netif].my_mac() )
            arp.set_sender_proto_addr( _local_ip )
            _last_arp_answer := ent_nr
            return ent_nr                       ' == the entry # in the table/cache

        { not yet cached; ask the network for who the IP belongs to }
        strln(@"arp_request(): not cached; requesting resolution...")
        net[netif].start_frame()
        ethii.new(net[netif].my_mac(), @_mac_bcast, ETYP_ARP)
        arp.who_has(_local_ip, _pending_arp_request)
        net[netif].send_frame()
        _timestamp_last_arp_req := cnt          ' mark now as the last time we sent a request


pub close()

    _disc := true


pub delete_tcb()
' Delete the transmission control block
    if ( _state <> CLOSED )
        strln(@"delete_tcb()")
        _ptr_remote_mac := 0
        _local_ip := 0
        _local_port := 0
        _remote_ip := 0
        _remote_port := 0
        longfill(@_iss, 0, 12)
        _state := _prev_state := CLOSED
        txq.flush()
        rxq.flush()


pub disconnect(): status
' Disconnect the socket
'   Returns:
'       0: success
'       -1: error (socket not open)
    case _state
        ESTABLISHED, CLOSE_WAIT:                ' connection must be established to close it
            tcp_send_socket(tcp.FIN | tcp.ACK)
            _snd_nxt++
            set_state(FIN_WAIT_1)
            on_disconnect()
        other:
            return -1'xxx specific error: socket not open


pub get_frame(): etype
' Get a frame of data from the network device
'   Returns: ethertype of frame
    'strln(@"get_frame()")
    net[netif].get_frame()
    ethii.rd_ethii_frame()                      ' read in the Ethernet-II header
    return ethii.ethertype()


con #0, PASSIVE, ACTIVE
con #0, UNSPEC
con O_BLOCK = (1 << 16)                         ' option: block until complete

pub open(lcl_ip, lcl_port=UNSPEC, rem_ip=UNSPEC, rem_port=UNSPEC, mode=PASSIVE, tmout=0): s | tm
' Open a new socket
'   lcl_ip: local IP address (always required)
'   lcl_port: local port
'       when mode == PASSIVE: required
'       when mode == ACTIVE: optional; will be randomly assigned if unspecified or set to 0
'   rem_ip: remote/foreign IP address
'       when mode == PASSIVE: optional
'       when mode == ACTIVE: required
'   rem_port: remote port
'       when mode == PASSIVE: optional (usually not known in this case)
'       when mode == ACTIVE: required
'   mode:
'       PASSIVE (0): open a listening socket (default, if unspecified)
'       ACITVE (1): actively open a connection to a remote host
'       options:
'           O_BLOCK ($1_00_00): block/wait until the connection is established
'   tmout: timeout in milliseconds to wait for the connection to be established
'       (ignored unless mode uses option O_BLOCK)
'   Returns:
'       socket number (0 or higher)
'       or a negative number, if an error occurs
    ifnot ( _state == CLOSED )
        strln(@"error: socket already in use")
        return -1'xxx                           ' error: socket already open

    _local_ip := lcl_ip
    _local_port := lcl_port                     ' required for PASSIVE; optional for ACTIVE
    _remote_ip := rem_ip                        ' optional for passive connections
    _remote_port := rem_port                    '   (usually these won't be known yet in that case)

    _rcv_wnd := RECVQ_SZ

    if ( mode.word[0] == PASSIVE )
        strln(@"PASSIVE mode")
        set_state(LISTEN)
        { validate the local IP address }
        ifnot ( _local_ip )
            strln(@"error: invalid local IP")
            return -1'xxx                       ' error: couldn't get a local IP address
        ifnot ( _local_port )
            strln(@"error: invalid local port")
            return -1'xxx
        s := 0
    elseif ( mode.word[1] == ACTIVE )
        strln(@"ACTIVE MODE")
        { validate the local IP address }
        ifnot ( _local_ip )
            strln(@"error: invalid local IP")
            return -1'xxx                       ' error: couldn't get a local IP address
        { check if a local port was specified; pick one at random if not }
        ifnot ( _local_port )
            strln(@"local port unspecified, picking a random one")
            _local_port := 49152+math.rndi(16383)
        { validate the remote IP address }
        ifnot ( _remote_ip )
            strln(@"error: invalid remote IP")
            return -1'xxx                       ' error: bad remote IP
        { validate the remote port }
        ifnot ( _remote_port )
            strln(@"error: invalid remote port")
            return -1'xxx                       ' error: bad remote port

        { set the initial send sequence # and the socket pointers }
        _flags := tcp.SYN                       ' will synchronize on first connection
        _snd_una := _iss := math.rndi(posx)     ' pick initial send sequence number
        _snd_wnd := 0
        _snd_wl1 := 0
        _snd_up := _iss
        _snd_nxt := _iss
        _rcv_nxt := 0
        _conn := true                           ' flag the main net loop we want to connect

    { bind the attached network device's MAC address to our chosen IP address }
    arp.cache_entry(net[netif].my_mac(), _local_ip)
    ip.set_my_ip32(_local_ip)

'{
    util.show_ip_addr(@"Local IP: ", _local_ip, @":")
    printf1(@"%d\n\r", _local_port)
    util.show_mac_addr(@"Local MAC: ", net[netif].my_mac(), string(10, 13))
    util.show_ip_addr(@"Remote IP: ", _remote_ip, @":")
    printf1(@"%d\n\r", _remote_port)
    if ( arp.find_mac_by_ip(_remote_ip) > 0 )
        util.show_mac_addr(@"Remote MAC: ", arp.find_mac_by_ip(_remote_ip), string(10, 13))
    else
        strln(@"Remote MAC undefined")
'}
    if ( mode & O_BLOCK )
        tm := cnt
        repeat until _state == ESTABLISHED
            if ( (||(cnt-tm) / 80_000) > tmout )
                return -1'xxx                   ' error: timeout waiting for connection

pub process_arp()
' Process received ARP messages
    arp.rd_arp_msg()
    case arp.opcode()
        arp.ARP_REQ:
            strln(@"process_arp(): REQ")
            if ( arp.target_proto_addr() == _local_ip )
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
    if ( (ip.dest_addr() == _local_ip) )
        'strln(@"frame is sent to us")
        if ( ip.layer4_proto() == L4_TCP )
            process_tcp()


pub process_tcp(): tf | ack, seq, flags, seg_len, seg_accept, loop_nr, reset
' Process incoming TCP segment
    tcp.rd_tcp_header()
    reset := false
    if ( (ip.src_addr() <> _remote_ip) )        ' source IP doesn't match the remote socket
        if ( _remote_ip )                       '   (only matters if it was specified with open() )
            strln(@"error: source address doesn't match remote socket")
            reset := true
    if ( (tcp.source_port() <> _remote_port) )  ' source port doesn't match the remote socket
        if ( _remote_port )                     '   (only matters if it was specified with open() )
            strln(@"error: source port doesn't match remote socket")
            reset := true
    if ( (tcp.dest_port() <> _local_port) )     ' destination port doesn't match the local socket
        reset := true                           '   this is always an error
        strln(@"error: destination port doesn't match local socket")

    if ( reset )
        { refuse connection if the socket doesn't exist }
        strln(@"connection refused (no matching socket)")
        ack := tcp.seq_nr()
        if ( tcp.flags() & tcp.FIN )            ' our ACK needs to be "believable" - inc by one
            ack++                               '   if the FIN bit was set
        tcp_send(   tcp.dest_port(), tcp.source_port(), ...
                    tcp.ack_nr(), ack, ...
                    (tcp.RST | tcp.ACK), ...
                    0 )
        return 0
    seg_len := ( ip.dgram_len() - ip.IP_HDR_SZ - tcp.header_len() )

    'str(@"process_tcp() ")
    util.show_tcp_flags(tcp.flags())
    'printf1(@"    SEG.LEN = %d\n\r", seg_len)
    printf2(@"    socket port: %d, segment dest port: %d\n\r", _local_port, tcp.dest_port())

    case _state
        CLOSED:
            { If the state is CLOSED (i.e., TCB does not exist) then all data in the incoming
                segment is discarded }
            'strln(@"    state: CLOSED")
            if ( tcp.flags() & tcp.RST )
                { An incoming segment containing a RST is discarded }
                'strln(@"    discard")
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
            'strln(@"    state: LISTEN")
            if ( tcp.flags() & tcp.RST )
                { first check for an RST }
                return 0                        ' ignore
            if ( tcp.flags() & tcp.ACK )        ' xxx behavior unverified
                { second, check for an ACK: Any acknowledgment is bad if it arrives on a
                    connection still in the LISTEN state }
                strln(@"    resetting connection (re: ACK)")
                tcp_send(   _local_port, tcp.source_port(), ...
                            tcp.ack_nr(), 0, ...
                            tcp.RST, ...
                            0 )
                return 0                        ' ignore
            if ( tcp.flags() & tcp.SYN )
                { third check for a SYN }
                { NOTE: security/compartment is ignored }
                _rcv_nxt := tcp.seq_nr()+1
                _irs := tcp.seq_nr()
                _iss := math.rndi(posx)         ' select our initial send sequence
                { fill in the remote socket data and complete the handshake }
                _remote_ip := ip.src_addr()
                _remote_port := tcp.source_port()
                arp.cache_entry(ethii.src_addr(), _remote_ip)
                _ptr_remote_mac := ethii.src_addr()'xxx should we really blindly do this? maybe validate with an ARP probe sometimes?
                util.show_ip_addr(@"    remote socket: ", _remote_ip, @":")
                printf1(@"%d\n\r", _remote_port)
                tcp_send(   _local_port, _remote_port, ...
                            _iss, _rcv_nxt, ...
                            tcp.SYN | tcp.ACK, ...
                            _rcv_wnd )
                _snd_nxt := _iss+1
                _snd_una := _iss
                set_state(SYN_RECEIVED)
                'print_ptrs()
                return 1
        SYN_SENT:
            { first, check the ACK bit }
            'strln(@"    state: SYN_SENT")
            if ( tcp.flags() & tcp.ACK )        ' if the ACK bit is set, check the ACK number
                if (    (tcp.ack_nr() =< _iss) or (tcp.ack_nr() > _snd_nxt) or ...
                        (tcp.ack_nr() < _snd_una) )
                    { bad ACK number }
                    strln(@"    ACK number bad")'xxx behavior unverified
                    if ( tcp.flags() & tcp.RST )
                        { received with reset; ignore }
                        strln(@"    drop (received RST)")
                    else
                        { received without reset; send one }
                        strln(@"    sending RST")
                        seq := tcp.ack_nr()
                        ack := 0
                        tcp_send(   _local_port, _remote_port, ...
                                    seq, ack, ...
                                    tcp.RST, ...
                                    0 )
                    return -1'xxx           ' drop segment and return
            { ACK number is acceptable }
            'strln(@"    ACK number is good")
            { second, check the RST bit }
            if ( tcp.flags() & tcp.RST )        ' if the RST bit is set
                'strln(@"    (ACK was acceptable)")
                'xxx _signal := ECONN_RESET
                'xxx callback function for user signals?
                set_state(CLOSED)
                delete_tcb()
                strln(@"    error: connection reset")
                return -1'xxx
            { third, check the security/compartment }
            { NOTE: ignored }
            { fourth, check the SYN bit }
            { NOTE: This step should be reached only if the ACK is ok, or there is
                no ACK, and if the segment did not contain a RST. }
            ifnot ( tcp.flags() & tcp.SYN )
                return 0                        ' discard
            _rcv_nxt := tcp.seq_nr()+1
            _irs := tcp.seq_nr()
            if ( tcp.flags() & tcp.ACK )
                _snd_una := tcp.ack_nr()
                'strln(@"    updating SND.UNA")
            'print_ptrs()
            { any segments on the retransmission queue that this acknowledges
                should be removed }
            if ( _snd_una > _iss )
                { our SYN has been ACKed }
                set_state(ESTABLISHED)
                '_snd_una := _snd_nxt       'xxx level-ip does this
                'print_ptrs()
                tcp_send_socket(tcp.ACK)
                on_connect()
                return 0
            else                            'xxx behavior unverified
                { Otherwise, enter SYN-RECEIVED, form a SYN,ACK segment and send it }
                set_state(SYN_RECEIVED)
                '_snd_una := _iss           ' xxx level-ip does this
                _snd_wnd := tcp.window()
                _snd_wl1 := tcp.seq_nr()
                _snd_wl2 := tcp.ack_nr()
                'print_ptrs()
                tcp_send(   _local_port, _remote_port, ...
                            _iss, _rcv_nxt, ...
                            tcp.SYN | tcp.ACK, ...
                            _rcv_wnd )
                return 0
            { Fifth, if neither of the SYN or RST bits is set, then drop the segment and return.
                NOTE: This would've been caught by fourth and second steps above, respectively. }

    { Otherwise, ... }

    { first, check the sequence number }
    'strln(@"    1. Check the sequence number")
    if ( (_rcv_wnd == 0) and (seg_len > 0) )
        { data received in segment, but the receive window is closed: not acceptable }
        strln(@"    error: SEG.LEN > 0, but RCV.WND == 0")
        seg_accept := false
    ifnot ( (tcp.seq_nr() => _rcv_nxt) and (tcp.seq_nr() < (_rcv_nxt+_rcv_wnd)) or ...
            ( (tcp.seq_nr()+seg_len-1) => _rcv_nxt) and ...
            (tcp.seq_nr()+seg_len-1) < (_rcv_nxt+_rcv_wnd) )
        strln(@"    error: SEG.SEQ or SEG.SEQ+SEG.LEN-1 outside receive window")
        seg_accept := false
    { If an incoming segment is not acceptable, an acknowledgment should be sent in reply
        (unless the RST bit is set, if so drop the segment and return) }
    ifnot ( seg_accept )
        { If an incoming segment is not acceptable, an acknowledgment should be sent
            in reply... }
        strln(@"    error: segment not acceptable (seq_nr)")
        ifnot ( tcp.flags() & tcp.RST )
            { ...(unless the RST bit is set, if so drop the segment and return) }
            tcp_send_socket(tcp.ACK)
        return 0'xxx                    ' drop the unacceptable segment and return

    { second, check the RST bit }
    'strln(@"    2. Check the RST bit")
    if ( tcp.flags() & tcp.RST )
        case _state
            SYN_RECEIVED:
                'strln(@"    state: SYN_RECEIVED")
                if ( _prev_state == LISTEN )
                    { connection was initiated with a passive open }
                    'strln(@"    was passive OPEN")
                    set_state(LISTEN)
                    'xxx the retransmission queue should be flushed
                    return 0'
                elseif ( _prev_state == SYN_SENT )
                    { connection was initiated with an active open }
                    'strln(@"    was active OPEN")
                    'strln(@"    error: connection refused")
                    '_signal := ECONN_REFUSED   ' remote incoming connection refused
                    'xxx the retransmission queue should be flushed
                    set_state(CLOSED)
                    delete_tcb()
                    return -1'xxx error: connection refused
            ESTABLISHED, FIN_WAIT_1, FIN_WAIT_2, CLOSE_WAIT:
                { any outstanding RECEIVEs and SEND should receive "reset" responses.
                    All segment queues should be flushed. }
                '_signal := ECONN_RESET ' signal to the user the connection was reset
                set_state(CLOSED)
                delete_tcb()
                on_disconnect()
                return -1'xxx error: connection reset
            CLOSING, LAST_ACK, TIME_WAIT:
                set_state(CLOSED)
                delete_tcb()
                return -1

    { third, check security and precedence }
    { NOTE: ignored }
    'strln(@"    3. Check security and precedence (IGNORED)")

    { fourth, check the SYN bit (NOTE: implementation follows RFC793) }
    'strln(@"    4. Check the SYN bit")
    if ( tcp.flags() & tcp.SYN )
        case _state
            SYN_RECEIVED:
                if ( _prev_state == LISTEN )
                    { connection was initiated with a passive OPEN }
                    set_state(LISTEN)
                    return 0
            ESTABLISHED, FIN_WAIT_1, FIN_WAIT_2, CLOSE_WAIT, CLOSING, LAST_ACK, TIME_WAIT:
                { RFC 5961 recommends that in these synchronized states,
                    if the SYN bit is set, irrespective of the sequence number,
                    TCP endpoints MUST send a "challenge ACK" to the remote peer }
                tcp_send_socket(tcp.ACK)
                return 0                        ' drop unacceptable segment

    { fifth, check the ACK field }
    'strln(@"    5. Check the ACK field")
    ifnot ( tcp.flags() & tcp.ACK )
        { if the ACK bit is off drop the segment and return }
        return 0'xxx                            ' drop segment, return

    { ACK bit is set, if we got here }
    'xxx decide if we should implement MAY-12 (check ACK value is in range)
    loop_nr := 1
    repeat
        'printf1(@"        loop_nr=%d\n\r", loop_nr)
        case _state
            SYN_RECEIVED:               'xxx behavior unverified
                'strln(@"        state: SYN_RECEIVED")
                if ( (tcp.ack_nr() > _snd_una) and (tcp.ack_nr() =< _snd_nxt) )
                    'xxx level-ip does first comparison with > (actually, 'snd_una =< ack')
                    'xxx    and second comparison with '<'
                    'strln(@"        good ACK")
                    set_state(ESTABLISHED)
                    'print_ptrs()
                    { continue processing in the ESTABLISHED state with the variables
                        below }
                    _snd_wnd := tcp.window()
                    _snd_wl1 := tcp.seq_nr()
                    _snd_wl2 := tcp.ack_nr()
                    on_connect()
                else
                    { the acknowledgement is unacceptable }
                    strln(@"        bad ACK")
                    tcp_send(   _local_port, _remote_port, ...
                                tcp.ack_nr(), 0, ...
                                tcp.RST, ...
                                0 ) 'xxx verify window setting
                    'xxx should we send the user a signal?
                    return 0'xxx
            ESTABLISHED, FIN_WAIT_1, FIN_WAIT_2, CLOSE_WAIT, CLOSING, LAST_ACK:
                if ( (tcp.ack_nr() > _snd_una) and (tcp.ack_nr() =< _snd_nxt) )
                    'strln(@"        updating unacknowledged ptr")
                    _snd_una := tcp.ack_nr()
                    'xxx any segments on the retransmission queue that this acknowledges
                    '   are removed
                    'xxx signal user buffers that've been sent and fully ACKed
                if ( tcp.ack_nr() < _snd_una )'xxx RFC9293 says use =<, but that doesn't seem to work?
                    { duplicate ACK: ACK num is older than the oldest unacknowledged data }
                    strln(@"        duplicate ACK")
                    return 0                ' ignore
                if ( tcp.ack_nr() > _snd_nxt )
                    { segment ACKs something that hasn't even been sent yet }
                    'xxx level-ip just drops segs here, and suggests that Linux does also.
                    'xxx investigate more. Is it meant to be a 'challenge ACK?'
                    strln(@"        warning: ACKed unsent segment")
                    tcp_send_socket(tcp.ACK)
                    return 0
                if (    (_snd_wl1 < tcp.seq_nr()) or ...
                        ((_snd_wl1 == tcp.seq_nr()) and (_snd_wl2 =< tcp.ack_nr())) )
                    { update the send window }
                    'strln(@"        updating send window")
                    _snd_wnd := tcp.window()
                    _snd_wl1 := tcp.seq_nr()
                    _snd_wl2 := tcp.ack_nr()
                    'print_ptrs()
                case _state
                    FIN_WAIT_1:
                        'strln(@"        state: FIN_WAIT_1")
                        set_state(FIN_WAIT_2)
                    FIN_WAIT_2:
                        'strln(@"        state: FIN_WAIT_2")
                        { if the retransmission queue is empty, the user's CLOSE can be
                            acknowledged ("ok") but do not delete the TCB. }
                        quit
                    CLOSE_WAIT:
                        'strln(@"        state: CLOSE_WAIT")
                        quit
                    CLOSING:
                        'strln(@"        state: CLOSING")
                        set_state(TIME_WAIT)
                        quit
                    LAST_ACK:
                        { The only thing that can arrive in this state is an acknowledgment of our
                            FIN. If our FIN is now acknowledged, delete the TCB,
                            enter the CLOSED state, and return. }
                        delete_tcb()
                        'strln(@"        state: LAST_ACK")
                        set_state(CLOSED)
                        return 0
                    TIME_WAIT:
                        { The only thing that can arrive in this state is a retransmission of the
                            remote FIN. Acknowledge it, and restart the 2 MSL timeout. }
                        'strln(@"        state: TIME_WAIT")
                        if ( tcp.seq_nr() == _rcv_nxt )
                            tcp_send_socket(tcp.FIN | tcp.ACK)
                        'xxx restart 2MSL timeout
                        quit
                quit
        loop_nr++

    { Sixth, check the URG bit }        ' xxx behavior unverified
    'strln(@"    6. Check the URG bit")
    if ( tcp.flags() & tcp.URG )
        case _state
            ESTABLISHED, FIN_WAIT_1, FIN_WAIT_2:
                _rcv_up := _rcv_up #> tcp.urgent_ptr()
                { signal the user that the remote side has urgent data if the
                    urgent pointer (RCV.UP) is in advance of the data consumed.
                    If the user has already been signaled (or is still in the
                    "urgent mode") for this continuous sequence of urgent data,
                    do not signal the user again. }
            CLOSE_WAIT, CLOSING, LAST_ACK, TIME_WAIT:
                { This should not occur since a FIN has been received from the
                    remote side. Ignore the URG. }

    { Seventh, process the segment text }
    'strln(@"    7. Process the segment text")
    if ( seg_len )                      ' process only if there's actually a payload
        'printf1(@"        SEG.LEN = %d\n\r", seg_len)
        case _state
            ESTABLISHED, FIN_WAIT_1, FIN_WAIT_2:
                { Once the TCP endpoint takes responsibility for the data,
                    it advances RCV.NXT over the data accepted, and adjusts RCV.WND
                    as appropriate to the current buffer availability. The total of
                    RCV.NXT and RCV.WND should not be reduced. }
                'printf1(@"        state: %s\n\r", state_str(_state))
                _rcv_nxt += rxq.xput(seg_len)
                _rcv_wnd := rxq.available()
                'print_ptrs()
                tcp_send_socket(tcp.ACK)
            CLOSE_WAIT, CLOSING, LAST_ACK, TIME_WAIT:
                { This should not occur since a FIN has been received from the
                    remote side. }
                return 0                ' ignore segment text

    { Eighth, check the FIN bit }
    'strln(@"    8. Check the FIN bit")
    ifnot ( tcp.flags() & tcp.FIN )
        return 0

    if ( lookdown(_state: CLOSED, LISTEN, SYN_SENT) )
        { Do not process the FIN if the state is CLOSED, LISTEN, or SYN-SENT since the
            SEG.SEQ cannot be validated; drop the segment and return. }
        return 0

    { If the FIN bit is set (if we got here, it is), }

    { signal the user "connection closing" and return any pending
        RECEIVEs with same message, }

    flags := tcp.ACK
    case _state
        SYN_RECEIVED, ESTABLISHED:
            set_state(CLOSE_WAIT)
            flags |= tcp.FIN
        FIN_WAIT_1:
            { If our FIN has been ACKed (perhaps in this segment), then enter TIME-WAIT,
                start the time-wait timer, turn off the other timers; otherwise,
                enter the CLOSING state }
            set_state(CLOSING)
        FIN_WAIT_2:
            set_state(TIME_WAIT)
        CLOSE_WAIT, CLOSING, LAST_ACK:
            { remain in this state }
        TIME_WAIT:
            { Remain in the TIME-WAIT state. Restart the 2 MSL time-wait timeout. }

    { advance RCV.NXT over the FIN, and send an acknowledgment for the FIN.
        Note that FIN implies PUSH for any segment text not yet delivered to the user. }
    _rcv_nxt++
    tcp_send_socket(flags)
    _snd_nxt++
    on_disconnect()
    return 0


pub read(ptr_buff, len=UNSPEC): l
' Read socket buffer data
'   ptr_buff: buffer to copy data to
'   len (optional): length of data to copy - copy all available, if unspecified
'   Returns: number of bytes actually copied
    ifnot ( len )
        len := RECVQ_SZ                         ' read whatever's available, if unspecified

    l := rxq.get(ptr_buff, len)
    if ( l => 0 )
        _rcv_wnd += l                           ' open the receive window by how much was read


pub send(ptr_buff, len, push=false): l
' Send data to socket
'   ptr_buff: buffer to copy data from
'   len: length of data to copy
'   Returns: number of bytes actually copied
    l := txq.put(ptr_buff, len)                 ' put the data into the send buffer
    if ( l < 0 )
        return l                                ' error: buffer full
    if ( push )
        _sendq := true


pub set_connect_event_func(ptr)
' Set function to call when the socket is connected
    on_connect := ptr


pub set_disconnect_event_func(ptr)
' Set function to call when the socket is disconnected
    on_disconnect := ptr


pub set_state(new_state)
' Change the connection state of the socket
    _prev_state := _state                       ' record the previous state
    _state := new_state
    printf2(@"state change %s -> %s\n\r", state_str(_prev_state), state_str(_state))


pub tcp_send(sp, dp, seq, ack, flags, win, seg_len=0) | tcplen, frm_end
' Send a TCP segment with arbitrary socket settings
'   sp, dp: source, destination ports
'   seq, ack: sequence, acknowledgement numbers
'   flags: control flags
'   win: TCP window
'   seg_len (optional): payload data length
    str(@"tcp_send() ")

    net[netif].start_frame()
        ethii.new(net[netif].my_mac(), _ptr_remote_mac, ETYP_IPV4)
            ip.new(ip.TCP, _local_ip, _remote_ip)
                tcp.set_source_port(sp)
                tcp.set_dest_port(dp)
                tcp.set_seq_nr(seq)
                tcp.set_ack_nr(ack)
                tcp.set_header_len(20)    ' XXX hardcode for now; no TCP options yet
                tcplen := tcp.header_len() + seg_len
                tcp.set_flags(flags)
                util.show_tcp_flags(tcp.flags())
                tcp.set_window(win)
                tcp.set_checksum(0)
                tcp.wr_tcp_header()
                if ( seg_len > 0 )                  ' attach payload (XXX untested)
                    printf1(@"    length is %d, attaching payload\n\r", seg_len)
                    txq.xget(seg_len)               ' get data from ring buffer into netif's FIFO
                    _snd_nxt += seg_len
                frm_end := net[netif].fifo_wr_ptr()
                net[netif].inet_checksum_wr(tcp._tcp_start, ...
                                            tcplen, ...
                                            tcp._tcp_start+TCPH_CKSUM, ...
                                            tcp.pseudo_header_cksum(_local_ip, _remote_ip, seg_len))
            net[netif].fifo_set_wr_ptr(frm_end)
            ip.update_chksum(tcplen)
    net[netif].send_frame()


pub tcp_send_socket(flags, seg_len=0)
' Send a TCP segment to the active socket
    tcp_send(   _local_port, _remote_port, ...
                _snd_nxt, _rcv_nxt, ...
                flags, _rcv_wnd, ...
                seg_len )


{ debugging methods }
pub print_ptrs()

    printf1(@"    SND.UNA: %d\n\r", _snd_una)
    printf1(@"    SND.NXT: %d\n\r", _snd_nxt)
    printf1(@"    SND.WND: %d\n\r", _snd_wnd)
    printf1(@"    SND.WL1: %d\n\r", _snd_wl1)
    printf1(@"    SND.WL2: %d\n\r", _snd_wl2)
    printf1(@"    RCV.NXT: %d\n\r", _rcv_nxt)
    printf1(@"    RCV.WND: %d\n\r", _rcv_wnd)


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


pub state_str(st): pstr

    pstr := @"???"
    case st
        CLOSED: return @"CLOSED"
        SYN_SENT: return @"SYN_SENT"
        SYN_RECEIVED: return @"SYN_RECEIVED"
        ESTABLISHED: return @"ESTABLISHED"
        FIN_WAIT_1: return @"FIN_WAIT_1"
        FIN_WAIT_2: return @"FIN_WAIT_2"
        CLOSE_WAIT: return @"CLOSE_WAIT"
        CLOSING: return @"CLOSING"
        LAST_ACK: return @"LAST_ACK"
        TIME_WAIT: return @"TIME_WAIT"
        LISTEN: return @"LISTEN"

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

