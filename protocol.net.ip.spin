{
    --------------------------------------------
    Filename: protocol.net.ip.spin
    Author: Jesse Burt
    Description: Internet Protocol
    Started Feb 27, 2022
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
    IP_HDR_SZ       = 20                        ' header length

    { layer 4 protocols }
    RSVD            = $00
    ICMP            = $01
    IGMP            = $02
    GGP             = $03
    IP_IN_IP        = $04
    TCP             = $06
    EGP             = $08
    UDP             = $11
    ESP             = $32
    AH              = $33

    { Differentiated Services Codepoints }
    CS6             = $30

OBJ

    { virtual instance of network device object }
    net=    NETDEV_OBJ

VAR

    { obj pointer }
    long _dev

    long _my_ip
    word _ip_start
    byte _ip_data[IP_HDR_SZ]

pub init(optr)
' Set pointer to network device object
    _dev := optr

PUB dest_addr(): addr | i
' Get destination address of IP datagram
'   Returns: 4 IPv4 address bytes packed into long
    repeat i from 0 to 3
        addr.byte[i] := _ip_data[IP_DSTIP+i]

PUB dgram_len(): len
' Return total length of IP datagram, in bytes
'   Returns: word
    len.byte[0] := _ip_data[IP_TLEN_L]
    len.byte[1] := _ip_data[IP_TLEN_M]

PUB dscp(): cp
' Differentiated services code point
'   Returns: 6-bit code point
   cp := _ip_data[IP_DSCP] >> 2 ' & $fc

PUB ecn(): state
' Explicit Congestion Notification
'   Returns: 2-bit ECN state
    state := _ip_data[IP_ECN] & $03

PUB flags(): f  'XXX methods to set DF and MF
' Get fragmentation control flags
'   Returns: 3-bit field
    f := _ip_data[IP_FLAGS_FRGH] >> 5 ' & $e0

PUB frag_offset(): offs
' Get offset in overall message of this fragment
'   Returns: 13-bit offset
    offs.byte[0] := _ip_data[IP_FLAGS_FRGH]
    offs.byte[1] := _ip_data[IP_FRGL]

PUB hdr_chk(): cksum
' Get header checksum
'   Returns: word
    cksum.byte[0] := _ip_data[IP_CKSUM_L]
    cksum.byte[1] := _ip_data[IP_CKSUM_M]

PUB hdr_len(): len
' Get header length, in bytes
'   Returns: byte
    len := (_ip_data[IP_HDRLEN] & $0f) << 2 ' * 4

PUB l4_proto(): proto
' Get layer 4/transport protocol carried in datagram
'   Returns: byte
    proto := _ip_data[IP_PRTCL]

PUB msg_ident(): id
' Get identification common to all fragments in a message
'   Returns: word
    id.byte[0] := _ip_data[IP_IDENT+1]
    id.byte[1] := _ip_data[IP_IDENT]

PUB src_addr(): addr | i
' Get source/originator of IP datagram
'   Returns: 4 IPv4 address bytes packed into long
    repeat i from 0 to 3
        addr.byte[i] := _ip_data[IP_SRCIP+i]

PUB ttl(): ttl
' Get number of router hops datagram is allowed to traverse
'   Returns: byte
    ttl := _ip_data[IP_T2L]

PUB version(): ver
' Get IP version
'   Returns: byte
    ver := _ip_data[IP_VERS]

PUB set_dest_addr(addr) | i
' Set destination address of IP datagram
    repeat i from 0 to 3
        _ip_data[IP_DSTIP+i] := addr.byte[i]

PUB set_dgram_len(len)
' Set total length of IP datagram, in bytes
'   IP header length + L4 header length + data length
    _ip_data[IP_TLEN_M] := len.byte[1]
    _ip_data[IP_TLEN_L] := len.byte[0]

PUB set_dscp(cp)
' Set Differentiated services code point
    _ip_data[IP_DSCP_ECN] |= (cp << 2)          ' combine with ECN

PUB set_ecn(state)
' Set Explicit Congestion Notification state
    _ip_data[IP_DSCP_ECN] |= (state & $03)      ' combine with DSCP

PUB set_flags(f)  'XXX methods to set DF and MF
' Set fragmentation control flags
    _ip_data[IP_FLAGS_FRGH] |= (f << 5)

PUB set_frag_offset(offs)
' Set offset in overall message of this fragment
    _ip_data[IP_FLAGS_FRGH] |= (offs.byte[1] & $1f) | offs.byte[0]

PUB set_hdr_chk(cksum)
' Set header checksum
    _ip_data[IP_CKSUM_M] := cksum.byte[1]
    _ip_data[IP_CKSUM_L] := cksum.byte[0]

PUB set_hdr_len(len)
' Set header length, in bytes
'   NOTE: len must be a multiple of 4
    _ip_data[IP_HDRLEN] |= len >> 2            ' / 4

PUB set_l4_proto(proto)
' Set layer 4 protocol carried in datagram
    _ip_data[IP_PRTCL] := proto

PUB set_msg_ident(id)
' Set identification common to all fragments in a message
    _ip_data[IP_IDENT_M] := id.byte[1]
    _ip_data[IP_IDENT_L] := id.byte[0]

PUB ip_set_my_ip(o3, o2, o1, o0)
' Set this node's IP address
'   o3..o0: IP address octets, MSB to LSB (e.g. 192,168,1,10)
    _my_ip.byte[0] := o3
    _my_ip.byte[1] := o2
    _my_ip.byte[2] := o1
    _my_ip.byte[3] := o0

PUB set_src_addr(addr) | i
' Set source/originator of IP datagram
    repeat i from 0 to 3
        _ip_data[IP_SRCIP+i] := addr.byte[i]

PUB set_ttl(ttl)
' Set number of router hops datagram is allowed to traverse
    _ip_data[IP_T2L] := ttl

PUB set_version(ver)
' Set IP version
    _ip_data[IP_VERS] |= (ver << 4)

PUB ip_start(): p
' Get pointer to start of IP header
    return _ip_start

PUB new(l4_proto, src_ip, dest_ip) | i
' Construct an IPV4 header
'   l4_proto: OSI Layer-4 protocol (TCP, UDP, *ICMP)
    _ip_start := net[_dev].fifo_wr_ptr()
    reset_ipv4()
    _ip_data[IP_PRTCL] := l4_proto
    repeat i from 0 to 3
        _ip_data[IP_SRCIP+i] := src_ip.byte[i]
    repeat i from 0 to 3
        _ip_data[IP_DSTIP+i] := dest_ip.byte[i]
'    wr_ip_header()

PUB reply(): p
' Set up/write IPv4 header as a reply to last received header
    set_hdr_chk(0)                         ' init header checksum to 0
'    fifo_wr_ptr()
    new(l4_proto(), my_ip(), src_addr())
'    return fifo_wr_ptr()

pub tle

    return ip_start() + IP_TLEN

PUB update_chksum(len) | ptr_tmp
' Update IP header with checksum
'   len: length of IP datagram (header plus payload)
    ptr_tmp := net[_dev].fifo_wr_ptr()                ' cache current pointer

    { update IP header with specified length and calculate checksum }
    set_dgram_len(len)
    net[_dev].fifo_set_wr_ptr(TXSTART+IP_ABS_ST+IP_TLEN)
'    fifo_set_wr_ptr(ip_start() + IP_TLEN)
    net[_dev].wrword_lsbf(dgram_len())

    net[_dev].inet_chksum(IP_ABS_ST, IP_ABS_ST+IP_HDR_SZ, IP_ABS_ST+IP_CKSUM)

    net[_dev].fifo_set_wr_ptr(ptr_tmp)                         ' restore pointer pos

PUB my_ip(): addr | i
' Get this node's IP address
    bytemove(@addr, @_my_ip, IPV4ADDR_LEN)

PUB reset_ipv4()
' Reset all values to defaults for an IPV4 header
    bytefill(@_ip_data, 0, IP_HDR_SZ)
    _ip_data[IP_VERS] |= $40
    _ip_data[IP_HDRLEN] |= $05
    _ip_data[IP_FLAGS_FRGH] |= (%010 << 5)
    _ip_data[IP_T2L] := 128
    _ip_data[IP_IDENT_M] := $00
    _ip_data[IP_IDENT_L] := $01

PUB rd_ip_header(): ptr
' Read IP header from buffer
    _ip_start := net[_dev].fifo_rd_ptr()
    net[_dev].rdblk_lsbf(@_ip_data, IP_HDR_SZ)
    return net[_dev].fifo_wr_ptr()

PUB wr_ip_header(): ptr
' Write IP header to buffer
'   Returns: length of assembled header, in bytes
    net[_dev].wrblk_lsbf(@_ip_data, IP_HDR_SZ)
    return net[_dev].fifo_wr_ptr()

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

