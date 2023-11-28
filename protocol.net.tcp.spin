{
    --------------------------------------------
    Filename: protocol.net.tcp.spin
    Author: Jesse Burt
    Description: Transmission Control Protocol
    Started Apr 5, 2022
    Updated Nov 28, 2023
    Copyright 2023
    See end of file for terms of use.
    --------------------------------------------
}
#ifndef NET_COMMON
#include "net-common.spinh"
#endif

CON

    { limits }
    TCP_HDR_SZ      = 20

    { TCP flags/control bits }
    CWR_BIT         = 7
    ECN_ECHO_BIT    = 6
    URG_BIT         = 5
    ACK_BIT         = 4
    PSH_BIT         = 3
    RST_BIT         = 2
    SYN_BIT         = 1
    FIN_BIT         = 0

    CWR             = 1 << CWR_BIT
    ECN_ECHO        = 1 << ECN_ECHO_BIT
    URG             = 1 << URG_BIT
    ACK             = 1 << ACK_BIT
    PSH             = 1 << PSH_BIT
    RST             = 1 << RST_BIT
    SYN             = 1 << SYN_BIT
    FIN             = 1 << FIN_BIT

    { TCP options }
    NOOP            = $01
    MSS             = $02
    WIN_SCALE       = $03
    SACK_PRMIT      = $04
    TMSTAMPS        = $08

    PSRC            = 0                         ' _tcp_port.word[n]
    PDEST           = 1

OBJ

    { virtual instance of network device object }
    net=    NETIF_DRIVER
    crc:    "math.crc"


VAR

    { obj pointer }
    long dev

    word _tcp_start, _tcp_msglen

    byte _tcp_data[TCP_HDR_SZ]


pub init(optr)
' Set pointer to network device object
    dev := optr

PUB pseudo_header_cksum(ip_src, ip_dest, len=0): ck | phdr[12/4]
' Calculate TCP pseudo-header checksum
'   ip_src: IPv4 source address
'   ip_dest: IPv4 destination address
'   len: TCP payload length (the TCP header length is already included)
    bytefill(@phdr, 0, 12)
    phdr[0] := ip_src                           ' 0..3
    phdr[1] := ip_dest                          ' 4..7
                                                ' 8 = reserved
    phdr.word[4] := (L4_TCP << 8) | 0
    phdr.word[5] := (header_len() + len) << 8   ' length of TCP header plus the payload length

    return crc.inet_chksum(@phdr, 12, $00)

PUB reply(ack_inc)
' Set up the TCP segment to "reply" to the last received segment
'   ack_inc: value to increase the outgoing acknowledgement number by
    swap_ports()
    swap_seq_nrs()
    inc_ack_nr(ack_inc)
    set_checksum(0)

PUB reset()
' Reset/initialize all stored data to 0
    bytefill(@_tcp_data, 0, TCP_HDR_SZ)


PUB set_ack_nr(ack_nr)
' Set TCP acknowledgement number
    _tcp_data[TCPH_ACKNR] := ack_nr.byte[3]
    _tcp_data[TCPH_ACKNR+1] := ack_nr.byte[2]
    _tcp_data[TCPH_ACKNR+2] := ack_nr.byte[1]
    _tcp_data[TCPH_ACKNR+3] := ack_nr.byte[0]

PUB set_checksum(ck)
' Set checksum
    _tcp_data[TCPH_CKSUM] := ck.byte[1]
    _tcp_data[TCPH_CKSUM+1] := ck.byte[0]


PUB set_dest_port(p)
' Set destination port field
    _tcp_data[TCPH_DESTP] := p.byte[1]
    _tcp_data[TCPH_DESTP+1] := p.byte[0]


PUB set_flags(flags)
' Set TCP header flags
    _tcp_data[TCPH_FLAGS] := (flags & $ff)


PUB set_header_len(length)
' Set TCP header length, in bytes
    _tcp_data[TCPH_HDRLEN] := ((length / 4) << 4)


PUB set_mss(sz)
' Set TCP maximum segment size
    '_tcp_mss := sz


PUB set_sack_perm(sp)
' Set selective-acknowledge permitted flag
    { equal to the length in a SACK_PERMIT KLV option? }
    '_tcp_sack_perm := (sp <> 0)


PUB set_seq_nr(seq_nr)
' Set TCP sequence number
    _tcp_data[TCPH_SEQNR] := seq_nr.byte[3]
    _tcp_data[TCPH_SEQNR+1] := seq_nr.byte[2]
    _tcp_data[TCPH_SEQNR+2] := seq_nr.byte[1]
    _tcp_data[TCPH_SEQNR+3] := seq_nr.byte[0]


PUB set_source_port(p)
' Set source port field
    _tcp_data[TCPH_SRCP] := p.byte[1]
    _tcp_data[TCPH_SRCP+1] := p.byte[0]

PUB set_timest(tm)
' Set timestamp (TCP option)
    '_tmstamps[0] := tm


PUB set_timest_echo(tm)
' Set timestamp echo (TCP option)
    '_tmstamps[1] := tm


PUB set_urgent_ptr(uptr)
' Set TCP urgent pointer
    _tcp_data[TCPH_URGPTR] := uptr.byte[1]
    _tcp_data[TCPH_URGPTR+1] := uptr.byte[0]


PUB set_window(win)
' Set TCP window
    _tcp_data[TCPH_WIN] := win.byte[1]
    _tcp_data[TCPH_WIN+1] := win.byte[0]


PUB inc_ack_nr(amt)
' Increment acknowledgement number by amt
    '_ack_nr += amt


PUB inc_seq_nr(amt)
' Increment sequence number by amt
    '_seq_nr += amt


PUB ack_nr(): ack_nr
' Get TCP acknowledgement number
    ack_nr.byte[3] := _tcp_data[TCPH_ACKNR]
    ack_nr.byte[2] := _tcp_data[TCPH_ACKNR+1]
    ack_nr.byte[1] := _tcp_data[TCPH_ACKNR+2]
    ack_nr.byte[0] := _tcp_data[TCPH_ACKNR+3]


PUB chksum(): ck
' Get TCP header checksum
    ck.byte[1] := _tcp_data[TCPH_CKSUM]
    ck.byte[0] := _tcp_data[TCPH_CKSUM+1]

PUB dest_port(): p
' Get destination port field
    p.byte[1] := _tcp_data[TCPH_DESTP]
    p.byte[0] := _tcp_data[TCPH_DESTP+1]


PUB flags(): flags
' Get TCP header flags
    flags := _tcp_data[TCPH_FLAGS]


PUB header_len(): len
' Get current header length, in bytes
    return (_tcp_data[TCPH_HDRLEN] >> 4) * 4


PUB msg_len(): len
' Get current message length
    'return _tcp_msglen


PUB max_seg_sz(): sz
' Get current maximum segment size (TCP option)
    'return _tcp_mss


PUB sack_perm(): sp
' Get selective-acknowledge permitted flag (TCP option)
    { equal to the length in a SACK_PERMIT KLV option? }
    'return (_tcp_sack_perm == 2)


PUB seq_nr(): seq_nr
' Get TCP sequence number
    seq_nr.byte[3] := _tcp_data[TCPH_SEQNR]
    seq_nr.byte[2] := _tcp_data[TCPH_SEQNR+1]
    seq_nr.byte[1] := _tcp_data[TCPH_SEQNR+2]
    seq_nr.byte[0] := _tcp_data[TCPH_SEQNR+3]


PUB source_port(): p
' Get source port field
    p.byte[1] := _tcp_data[TCPH_SRCP]
    p.byte[0] := _tcp_data[TCPH_SRCP+1]


PUB swap_ports()
' swap_ source and destination ports, for use when sending a response
    '_tcp_port ->= 16


PUB swap_seq_nrs() | tmp
' swap_ sequence and acknowledgement numbers, for use when sending a response
    'tmp := _seq_nr
    '_seq_nr := _ack_nr
    '_ack_nr := tmp


PUB timest(): tm
' Get timestamp (TCP option)
    'return _tmstamps[0]


PUB timest_echo(): tm
' Get timestamp echo (TCP option)
    'return _tmstamps[1]


PUB timest_ptr(): ptr
' Get pointer to timestamp data
    'return @_tmstamps


PUB urgent_ptr(): uptr
' Get TCP urgent pointer
    uptr.byte[1] := _tcp_data[TCPH_URGPTR]
    uptr.byte[0] := _tcp_data[TCPH_URGPTR+1]

PUB window(): win
' Get TCP header window
    win.byte[1] := _tcp_data[TCPH_WIN]
    win.byte[0] := _tcp_data[TCPH_WIN+1]


PUB rd_tcp_header(): rl
' Read/disassemble TCP header
'   Returns: length of read header, in bytes
    net[dev].rdblk_lsbf(@_tcp_data, TCP_HDR_SZ)
    return TCP_HDR_SZ


PUB rd_tcp_opts(): ptr | kind, st, opts_len
' Read TCP options
    st := net[dev].fifo_wr_ptr()

    { TCP header length is the header itself plus the options; }
    {   subtract out the header to get the length of the options }
    opts_len := header_len() - 20

    { read through all KLVs }
    repeat
        kind := net[dev].rd_byte()
        case kind
            MSS:
                net[dev].rd_byte()                       ' skip over the length byte
                _tcp_mss := net[dev].rdword_msbf()
            SACK_PRMIT:
                _tcp_sack_perm := net[dev].rd_byte()     ' actually the length byte
            TMSTAMPS:
                net[dev].rd_byte()
                _tmstamps[0] := net[dev].rdlong_msbf()
                _tmstamps[1] := net[dev].rdlong_msbf()
            NOOP:
                ' only one byte - do nothing
            WIN_SCALE:
                _tcp_winscale := net[dev].rd_byte()
    until ( net[dev].fifo_wr_ptr()-st ) > opts_len
    return net[dev].fifo_wr_ptr()

PUB wr_tcp_header(): ptr | st
' Write/assemble TCP header
'   Returns: length of assembled header, in bytes
    _tcp_start := net[dev].fifo_wr_ptr()
    net[dev].wrblk_lsbf(@_tcp_data, TCP_HDR_SZ)
    _tcp_msglen := net[dev].fifo_wr_ptr()-_tcp_start
    return _tcp_msglen

CON #0, LSBF, MSBF
PUB write_klv(kind, len, wr_val, val, byte_ord): tlvlen
' Write KLV to ptr_buff
'   kind:
'       option kind
'   len:
'       length of KLV, 1..255 (includes kind byte, length byte, and
'           number of option bytes)
'       any other value: only the type will be written
'   wr_val:
'       Whether to write the value data (0: ignore, non-zero: write val)
'   val:
'       value of option data
'       When len is 1..4, values will be read directly from parameter
'       When len is 5..255, val is expected to be a pointer to value data
'       (ignored if len is outside valid range or if wr_val is 0)
'   byte_ord:
'       byte order to write option data (LSBF or MSBF)
'   Returns: total length of KLV (includes: kind, length, and all values)

    { track length of options; it'll be needed later for padding
        the end of the message }
    _options_len += net[dev].wr_byte(kind)
    case len
        { immediate value }
        1..4:
            _options_len += net[dev].wr_byte(len)        ' write length byte
            { only write the value data if explicitly called to; }
            {   some options only consist of the TYPE and LENGTH fields }
            if ( wr_val )                         ' write value
                if ( byte_ord == LSBF )
                    _options_len += net[dev].wrblk_lsbf(@val, len-2)
                else
                    _options_len += net[dev].wrblk_msbf(@val, len-2)
        { values pointed to }
        5..255:
            _options_len += net[dev].wr_byte(len)
            if ( wr_val )
                if ( byte_ord == LSBF )
                    _options_len += net[dev].wrblk_lsbf(val, len-2)
                else
                    _options_len += net[dev].wrblk_msbf(val, len-2)
        { write type only }
        other:
    return _options_len

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

