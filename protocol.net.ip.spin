{
    --------------------------------------------
    Filename: protocol.net.ip.spin
    Author: Jesse Burt
    Description: Internet Protocol
    Started Feb 27, 2022
    Updated Jan 15, 2022
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

    { offsets within header}
    IP_ABS_ST       = ETH_TYPE+2                ' add to the below for abs. position within frame

    IP_VERS         = 0
    IP_HDRLEN       = 0
    IP_DSCP_ECN     = 1
    IP_TLEN         = 2
     IP_TLEN_LSB    = 3
    IP_IDENT        = 4
     IP_IDENT_LSB   = 5
    IP_FLAGS_FRGH   = 6
    IP_FRGL         = 7
    IP_T2L          = 8
    IP_PRTCL        = 9
    IP_CKSUM        = 10
     IP_CKSUM_LSB   = 11
    IP_SRCIP        = 12'..15
    IP_DSTIP        = 16'..19

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

VAR

    byte _ip_data[IP_HDR_SZ]

PUB ip_dest_addr{}: addr | i
' Get destination address of IP datagram
'   Returns: 4 IPv4 address bytes packed into long
    repeat i from 0 to 3
        addr.byte[i] := _ip_data[IP_DSTIP+i]

PUB ip_dgram_len{}: len
' Return total length of IP datagram, in bytes
'   Returns: word
    len.byte[0] := _ip_data[IP_TLEN_LSB]
    len.byte[1] := _ip_data[IP_TLEN]

PUB ip_dscp{}: cp
' Differentiated services code point
'   Returns: 6-bit code point
   cp := _ip_data[IP_DSCP] >> 2 ' & $fc

PUB ip_ecn{}: state
' Explicit Congestion Notification
'   Returns: 2-bit ECN state
    state := _ip_data[IP_ECN] & $03

PUB ip_flags{}: f  'XXX methods to set DF and MF
' Get fragmentation control flags
'   Returns: 3-bit field
    f := _ip_data[IP_FLAGS_FRGH] >> 5 ' & $e0

PUB ip_frag_offset{}: offs
' Get offset in overall message of this fragment
'   Returns: 13-bit offset
    offs.byte[0] := _ip_data[IP_FLAGS_FRGH]
    offs.byte[1] := _ip_data[IP_FRGL]

PUB ip_hdr_chk{}: cksum
' Get header checksum
'   Returns: word
    cksum.byte[0] := _ip_data[IP_CKSUM_LSB]
    cksum.byte[1] := _ip_data[IP_CKSUM]

PUB ip_hdr_len{}: len
' Get header length, in bytes
'   Returns: byte
    len := (_ip_data[IP_HDRLEN] & $0f) << 2 ' * 4

PUB ip_l4_proto{}: proto
' Get layer 4/transport protocol carried in datagram
'   Returns: byte
    proto := _ip_data[IP_PRTCL]

PUB ip_msg_ident{}: id
' Get identification common to all fragments in a message
'   Returns: word
    id.byte[0] := _ip_data[IP_IDENT+1]
    id.byte[1] := _ip_data[IP_IDENT]

PUB ip_src_addr{}: addr | i
' Get source/originator of IP datagram
'   Returns: 4 IPv4 address bytes packed into long
    repeat i from 0 to 3
        addr.byte[i] := _ip_data[IP_SRCIP+i]

PUB ip_ttl{}: ttl
' Get number of router hops datagram is allowed to traverse
'   Returns: byte
    ttl := _ip_data[IP_T2L]

PUB ip_version{}: ver
' Get IP version
'   Returns: byte
    ver := _ip_data[IP_VERS]

PUB ip_set_dest_addr(addr) | i
' Set destination address of IP datagram
    repeat i from 0 to 3
        _ip_data[IP_DSTIP+i] := addr.byte[i]

PUB ip_set_dgram_len(len)
' Set total length of IP datagram, in bytes
'   IP header length + L4 header length + data length
    _ip_data[IP_TLEN] := len.byte[1]
    _ip_data[IP_TLEN_LSB] := len.byte[0]

PUB ip_set_dscp(cp)
' Set Differentiated services code point
    _ip_data[IP_DSCP_ECN] |= (cp << 2)          ' combine with ECN

PUB ip_set_ecn(state)
' Set Explicit Congestion Notification state
    _ip_data[IP_DSCP_ECN] |= (state & $03)      ' combine with DSCP

PUB ip_set_flags(f)  'XXX methods to set DF and MF
' Set fragmentation control flags
    _ip_data[IP_FLAGS_FRGH] |= (f << 5)

PUB ip_set_frag_offset(offs)
' Set offset in overall message of this fragment
    _ip_data[IP_FLAGS_FRGH] |= (offs.byte[1] & $1f) | offs.byte[0]

PUB ip_set_hdr_chk(cksum)
' Set header checksum
    _ip_data[IP_CKSUM] := cksum.byte[1]
    _ip_data[IP_CKSUM_LSB] := cksum.byte[0]

PUB ip_set_hdr_len(len)
' Set header length, in bytes
'   NOTE: len must be a multiple of 4
    _ip_data[IP_HDRLEN] |= len >> 2            ' / 4

PUB ip_set_l4_proto(proto)
' Set layer 4 protocol carried in datagram
    _ip_data[IP_PRTCL] := proto

PUB ip_set_msg_ident(id)
' Set identification common to all fragments in a message
    _ip_data[IP_IDENT] := id.byte[1]
    _ip_data[IP_IDENT_LSB] := id.byte[0]

PUB ip_set_src_addr(addr) | i
' Set source/originator of IP datagram
    repeat i from 0 to 3
        _ip_data[IP_SRCIP+i] := addr.byte[i]

PUB ip_set_ttl(ttl)
' Set number of router hops datagram is allowed to traverse
    _ip_data[IP_T2L] := ttl

PUB ip_set_version(ver)
' Set IP version
    _ip_data[IP_VERS] |= (ver << 4)

PUB ipv4_new(l4_proto, src_ip, dest_ip) | i
' Construct an IPV4 header
'   l4_proto: OSI Layer-4 protocol (TCP, UDP, *ICMP)
    reset_ipv4{}
    _ip_data[IP_PRTCL] := l4_proto
    repeat i from 0 to 3
        _ip_data[IP_SRCIP+i] := src_ip.byte[i]
    repeat i from 0 to 3
        _ip_data[IP_DSTIP+i] := dest_ip.byte[i]
    wr_ip_header{}

PUB reset_ipv4{}
' Reset all values to defaults for an IPV4 header
    bytefill(@_ip_data, 0, IP_HDR_SZ)
    _ip_data[IP_VERS] |= $40
    _ip_data[IP_HDRLEN] |= $05
    _ip_data[IP_FLAGS_FRGH] |= (%010 << 5)
    _ip_data[IP_T2L] := 128
    _ip_data[IP_IDENT] := $00
    _ip_data[IP_IDENT+1] := $01

PUB rd_ip_header{}: ptr
' Read IP header from buffer
    rdblk_lsbf(@_ip_data, IP_HDR_SZ)
    return fifo_wr_ptr{}

PUB wr_ip_header{}: ptr
' Write IP header to buffer
'   Returns: length of assembled header, in bytes
    wrblk_lsbf(@_ip_data, IP_HDR_SZ)
    return fifo_wr_ptr{}

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

