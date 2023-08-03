{
    --------------------------------------------
    Filename: protocol.net.udp.spin
    Author: Jesse Burt
    Description: Universal Datagram Protocol
    Started Feb 28, 2022
    Updated Aug 2, 2023
    Copyright 2023
    See end of file for terms of use.
    --------------------------------------------
}
#ifndef NET_COMMON
#include "net-common.spinh"
#endif

CON

    { limits }
    UDP_MSG_SZ      = 8                         ' message length

OBJ

    { virtual instance of network device object }
    net=    NETDEV_OBJ

VAR

    { obj pointer }
    long dev

    long _udp_fifo_pos                          ' start of the datagram in the FIFO

    byte _udp_data[UDP_MSG_SZ]

pub init(optr)
' Set pointer to network device object
    dev := optr

PUB new(src_port, dest_port)
' Construct new UDP datagram
    bytefill(@_udp_data, 0, UDP_MSG_SZ)
    _udp_data[UDP_SRCPORT] := src_port.byte[1]
    _udp_data[UDP_SRCPORT_L] := src_port.byte[0]
    _udp_data[UDP_DESTPORT] := dest_port.byte[1]
    _udp_data[UDP_DESTPORT_L] := dest_port.byte[0]

    wr_udp_header{}

PUB set_chksum(ck)
' Set checksum (optional; set to 0 to ignore)
    _udp_data[UDP_CKSUM] := ck.byte[1]
    _udp_data[UDP_CKSUM_L] := ck.byte[0]

PUB set_dest_port(p)
' Set destination port field
    _udp_data[UDP_DESTPORT] := p.byte[1]
    _udp_data[UDP_DESTPORT_L] := p.byte[0]

PUB set_dgram_len(len)
' Set length of UDP datagram
    _udp_data[UDP_DGRAMLEN] := len.byte[1]
    _udp_data[UDP_DGRAMLEN_L] := len.byte[0]

PUB set_src_port(p)
' Set source port field
    _udp_data[UDP_SRCPORT] := p.byte[1]
    _udp_data[UDP_SRCPORT_L] := p.byte[0]

PUB chksum{}: ck
' Get checksum
    ck.byte[1] := _udp_data[UDP_CKSUM]
    ck.byte[0] := _udp_data[UDP_CKSUM_L]

PUB dest_port{}: p
' Get destination port field
    p.byte[1] := _udp_data[UDP_DESTPORT]
    p.byte[0] := _udp_data[UDP_DESTPORT_L]

PUB dgram_len{}: len
' Get length of UDP datagram
    len.byte[1] := _udp_data[UDP_DGRAMLEN]
    len.byte[0] := _udp_data[UDP_DGRAMLEN_L]

PUB hdr_len{}: len
' Get current header length
    return UDP_MSG_SZ

PUB src_port{}: p
' Get source port field
    p.byte[1] := _udp_data[UDP_SRCPORT]
    p.byte[0] := _udp_data[UDP_SRCPORT_L]

PUB reset_udp{}
' Reset all values to defaults
    bytefill(@_udp_data, 0, UDP_MSG_SZ)

PUB rd_udp_header{}
' Read/disassemble UDP header
'   Returns: length of read header, in bytes
    net[dev].rdblk_lsbf(@_udp_data, UDP_MSG_SZ)
    return net[dev].fifo_wr_ptr{}

pub start_pos(): p
' Get the start position of the last written UDP message in the FIFO
    return _udp_fifo_pos

PUB wr_udp_header{}: ptr
' Write/assemble UDP header
'   Returns: length of assembled header, in bytes
    _udp_fifo_pos := net[dev].fifo_wr_ptr()    ' save this FIFO position as the start of UDP
    net[dev].wrblk_lsbf(@_udp_data, UDP_MSG_SZ)
    return net[dev].fifo_wr_ptr{}

DAT

{
TERMS OF USE: MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
}

