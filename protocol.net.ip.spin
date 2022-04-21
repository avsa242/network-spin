{
    --------------------------------------------
    Filename: protocol.net.ip.spin
    Author: Jesse Burt
    Description: Internet Protocol
    Started Feb 27, 2022
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
    IP_HDR_SZ       = 20                        ' header length

    { offsets within header}
    IP_ABS_ST       = ETH_TYPE+2                ' add to the below for abs. position within frame

    IP_VERS         = 0
    IP_HDR_LEN      = 0
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

PUB IP_DestAddr{}: addr | i
' Get destination address of IP datagram
'   Returns: 4 IPv4 address bytes packed into long
    repeat i from 0 to 3
        addr.byte[i] := _ip_data[IP_DSTIP+i]

PUB IP_DgramLen{}: len
' Return total length of IP datagram, in bytes
'   Returns: word
    len.byte[0] := _ip_data[IP_TLEN_LSB]
    len.byte[1] := _ip_data[IP_TLEN]

PUB IP_DSCP{}: cp
' Differentiated services code point
'   Returns: 6-bit code point
   cp := _ip_data[IP_DSCP] >> 2 ' & $fc

PUB IP_ECN{}: state
' Explicit Congestion Notification
'   Returns: 2-bit ECN state
    state := _ip_data[IP_ECN] & $03

PUB IP_Flags{}: f  'XXX methods to set DF and MF
' Get fragmentation control flags
'   Returns: 3-bit field
    f := _ip_data[IP_FLAGS_FRGH] >> 5 ' & $e0

PUB IP_FragOffset{}: offs
' Get offset in overall message of this fragment
'   Returns: 13-bit offset
    offs.byte[0] := _ip_data[IP_FLAGS_FRGH]
    offs.byte[1] := _ip_data[IP_FRGL]

PUB IP_HdrChk{}: cksum
' Get header checksum
'   Returns: word
    cksum.byte[0] := _ip_data[IP_CKSUM_LSB]
    cksum.byte[1] := _ip_data[IP_CKSUM]

PUB IP_HdrLen{}: len
' Get header length, in bytes
'   Returns: byte
    len := (_ip_data[IP_HDR_LEN] & $0f) << 2 ' * 4

PUB IP_L4Proto{}: proto
' Get layer 4/transport protocol carried in datagram
'   Returns: byte
    proto := _ip_data[IP_PRTCL]

PUB IP_MsgIdent{}: id
' Get identification common to all fragments in a message
'   Returns: word
    id.byte[0] := _ip_data[IP_IDENT+1]
    id.byte[1] := _ip_data[IP_IDENT]

PUB IP_SrcAddr{}: addr | i
' Get source/originator of IP datagram
'   Returns: 4 IPv4 address bytes packed into long
    repeat i from 0 to 3
        addr.byte[i] := _ip_data[IP_SRCIP+i]

PUB IP_TTL{}: ttl
' Get number of router hops datagram is allowed to traverse
'   Returns: byte
    ttl := _ip_data[IP_T2L]

PUB IP_Version{}: ver
' Get IP version
'   Returns: byte
    ver := _ip_data[IP_VERS]

PUB IP_SetDestAddr(addr) | i
' Set destination address of IP datagram
    repeat i from 0 to 3
        _ip_data[IP_DSTIP+i] := addr.byte[i]

PUB IP_SetDgramLen(len)
' Set total length of IP datagram, in bytes
'   IP header length + L4 header length + data length
    _ip_data[IP_TLEN] := len.byte[1]
    _ip_data[IP_TLEN_LSB] := len.byte[0]

PUB IP_SetDSCP(cp)
' Set Differentiated services code point
    _ip_data[IP_DSCP_ECN] |= (cp << 2)          ' combine with ECN

PUB IP_SetECN(state)
' Set Explicit Congestion Notification state
    _ip_data[IP_DSCP_ECN] |= (state & $03)      ' combine with DSCP

PUB IP_SetFlags(f)  'XXX methods to set DF and MF
' Set fragmentation control flags
    _ip_data[IP_FLAGS_FRGH] |= (f << 5)

PUB IP_SetFragOffset(offs)
' Set offset in overall message of this fragment
    _ip_data[IP_FLAGS_FRGH] |= (offs.byte[1] & $1f) | offs.byte[0]

PUB IP_SetHdrChk(cksum)
' Set header checksum
    _ip_data[IP_CKSUM] := cksum.byte[1]
    _ip_data[IP_CKSUM_LSB] := cksum.byte[0]

PUB IP_SetHdrLen(len)
' Set header length, in bytes
'   NOTE: len must be a multiple of 4
    _ip_data[IP_HDR_LEN] |= len >> 2            ' / 4

PUB IP_SetL4Proto(proto)
' Set layer 4 protocol carried in datagram
    _ip_data[IP_PRTCL] := proto

PUB IP_SetMsgIdent(id)
' Set identification common to all fragments in a message
    _ip_data[IP_IDENT] := id.byte[1]
    _ip_data[IP_IDENT_LSB] := id.byte[0]

PUB IP_SetSrcAddr(addr) | i
' Set source/originator of IP datagram
    repeat i from 0 to 3
        _ip_data[IP_SRCIP+i] := addr.byte[i]

PUB IP_SetTTL(ttl)
' Set number of router hops datagram is allowed to traverse
    _ip_data[IP_T2L] := ttl

PUB IP_SetVersion(ver)
' Set IP version
    _ip_data[IP_VERS] |= (ver << 4)

PUB Reset_IPV4{}
' Reset all values to defaults for an IPV4 header
    bytefill(@_ip_data, 0, IP_HDR_SZ)
    _ip_data[IP_VERS] |= $40
    _ip_data[IP_HDR_LEN] |= $05
    _ip_data[IP_FLAGS_FRGH] |= (%010 << 5)
    _ip_data[IP_T2L] := 128
    _ip_data[IP_IDENT] := $00
    _ip_data[IP_IDENT+1] := $01

PUB Rd_IP_Header{}: ptr
' Read IP header from buffer
    rdblk_lsbf(@_ip_data, IP_HDR_SZ)
    return currptr{}

PUB Wr_IP_Header{}: ptr
' Write IP header to buffer
'   Returns: length of assembled header, in bytes
    wrblk_lsbf(@_ip_data, IP_HDR_SZ)
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

