{
    --------------------------------------------
    Filename: protocol.net.udp.spin
    Author: Jesse Burt
    Description: Universal Datagram Protocol
    Started Feb 28, 2022
    Updated Apr 21, 2022
    Copyright 2022
    See end of file for terms of use.
    --------------------------------------------
}
#ifndef NET_COMMON
#include "net-common.spinh"
#endif

CON

    { limits }
    UDP_MSG_SZ      = 8                         ' message length

    { offsets within header }
    UDP_ABS_ST      = IP_DSTIP + 4              ' add to the below for abs. position within frame

    UDP_SRC_PORT    = 0
     UDP_SRC_PORT_L = 1
    UDP_DEST_PORT   = 2
     UDP_DEST_PORT_L= 3
    UDP_DGRAM_LEN   = 4
     UDP_DGRAM_LEN_L= 5
    UDP_CKSUM       = 6
     UDP_CKSUM_L    = 7

VAR

    byte _udp_data[UDP_MSG_SZ]

PUB UDP_SetChksum(ck)
' Set checksum (optional; set to 0 to ignore)
    _udp_data[UDP_CKSUM] := ck.byte[1]
    _udp_data[UDP_CKSUM_L] := ck.byte[0]

PUB UDP_SetDestPort(p)
' Set destination port field
    _udp_data[UDP_DEST_PORT] := p.byte[1]
    _udp_data[UDP_DEST_PORT_L] := p.byte[0]

PUB UDP_SetDgramLen(len)
' Set length of UDP datagram
    _udp_data[UDP_DGRAM_LEN] := len.byte[1]
    _udp_data[UDP_DGRAM_LEN_L] := len.byte[0]

PUB UDP_SetSrcPort(p)
' Set source port field
    _udp_data[UDP_SRC_PORT] := p.byte[1]
    _udp_data[UDP_SRC_PORT_L] := p.byte[0]

PUB UDP_Chksum{}: ck
' Get checksum
    ck.byte[1] := _udp_data[UDP_CKSUM]
    ck.byte[0] := _udp_data[UDP_CKSUM_L]

PUB UDP_DestPort{}: p
' Get destination port field
    p.byte[1] := _udp_data[UDP_DEST_PORT]
    p.byte[0] := _udp_data[UDP_DEST_PORT_L]

PUB UDP_DgramLen{}: len
' Get length of UDP datagram
    len.byte[1] := _udp_data[UDP_DGRAM_LEN]
    len.byte[0] := _udp_data[UDP_DGRAM_LEN_L]

PUB UDP_HdrLen{}: len
' Get current header length
    return UDP_MSG_SZ

PUB UDP_SrcPort{}: p
' Get source port field
    p.byte[1] := _udp_data[UDP_SRC_PORT]
    p.byte[0] := _udp_data[UDP_SRC_PORT_L]

PUB Reset_UDP{}
' Reset all values to defaults
    bytefill(@_udp_data, 0, UDP_MSG_SZ)

PUB Rd_UDP_Header{}
' Read/disassemble UDP header
'   Returns: length of read header, in bytes
    rdblk_lsbf(@_udp_data, UDP_MSG_SZ)
    return currptr{}

PUB Wr_UDP_Header{}: ptr
' Write/assemble UDP header
'   Returns: length of assembled header, in bytes
    wrblk_lsbf(@_udp_data, UDP_MSG_SZ)
    return currptr{}

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

