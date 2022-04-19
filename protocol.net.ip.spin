{
    --------------------------------------------
    Filename: protocol.net.ip.spin
    Author: Jesse Burt
    Description: Internet Protocol
    Started Feb 27, 2022
    Updated Apr 19, 2022
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
    IP_IDENT        = 4'..5
    IP_FLAGS_FRGH   = 6
    IP_FRGL         = 7
    IP_T2L          = 8
    IP_PRTCL        = 9
    IP_CKSUM        = 10'..11
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

    long _ip_src_addr, _ip_dest_addr

    word _tot_len
    word _ident
    word _frag_offs                             ' flags[15..13]:frag[12..0]
    word _hdr_chk

    byte _ver                                   ' version[7..4]:IHL[3..0]
    byte _hdr_len                               ' in 32-bit words; bytes = *4
    byte _dsvc                                  ' dsc[7..2]:ecn[1..0]
    byte _ecn
    byte _ip_flags
    byte _ttl
    byte _proto

PUB IP_DestAddr{}: addr
' Get destination address of IP datagram
'   Returns: 4 IPv4 address bytes packed into long
    return _ip_dest_addr

PUB IP_DgramLen{}: len
' Return total length of IP datagram, in bytes
'   Returns: word
    return _tot_len

PUB IP_DSCP{}: cp
' Differentiated services code point
'   Returns: 6-bit code point
    return _dsvc

PUB IP_ECN{}: state
' Explicit Congestion Notification
'   Returns: 2-bit ECN state
    return _ecn

PUB IP_Flags{}: f  'XXX methods to set DF and MF
' Get fragmentation control flags
'   Returns: 3-bit field
    return _ip_flags

PUB IP_FragOffset{}: o
' Get offset in overall message of this fragment
'   Returns: 13-bit offset
    return _frag_offs

PUB IP_HdrChk{}: cksum
' Get header checksum
'   Returns: word
    return _hdr_chk

PUB IP_HdrLen{}: len
' Get header length, in bytes
'   Returns: byte
    return _hdr_len * 4

PUB IP_L4Proto{}: proto
' Get layer 4/transport protocol carried in datagram
'   Returns: byte
    return _proto

PUB IP_MsgIdent{}: id
' Get identification common to all fragments in a message
'   Returns: word
    return _ident

PUB IP_SrcAddr{}: addr
' Get source/originator of IP datagram
'   Returns: 4 IPv4 address bytes packed into long
    return _ip_src_addr

PUB IP_TTL{}: ttl
' Get number of router hops datagram is allowed to traverse
'   Returns: byte
    return _ttl

PUB IP_Version{}: ver
' Get IP version
'   Returns: byte
    return _ver

PUB IP_SetDestAddr(addr)
' Set destination address of IP datagram
    _ip_dest_addr := addr

PUB IP_SetDgramLen(len)
' Set total length of IP datagram, in bytes
'   IP header length + L4 header length + data length
    _tot_len := len

PUB IP_SetDSCP(cp)
' Set Differentiated services code point
    _dsvc := cp

PUB IP_SetECN(state)
' Set Explicit Congestion Notification state
    _ecn := state

PUB IP_SetFlags(f)  'XXX methods to set DF and MF
' Set fragmentation control flags
    _ip_flags := f

PUB IP_SetFragOffset(o)
' Set offset in overall message of this fragment
    _frag_offs := o

PUB IP_SetHdrChk(cksum)
' Set header checksum
    _hdr_chk := cksum

PUB IP_SetHdrLen(len)
' Set header length, in bytes
'   NOTE: len must be a multiple of 4
    _hdr_len := len / 4                         ' convert to longs

PUB IP_SetL4Proto(proto)
' Set layer 4 protocol carried in datagram
    _proto := proto

PUB IP_SetMsgIdent(id)
' Set identification common to all fragments in a message
    _ident := id

PUB IP_SetSrcAddr(addr)
' Set source/originator of IP datagram
    _ip_src_addr := addr

PUB IP_SetTTL(ttl)
' Set number of router hops datagram is allowed to traverse
    _ttl := ttl

PUB IP_SetVersion(ver)
' Set IP version
    _ver := ver

PUB Reset_IPV4{}
' Reset all values defaults for an IPV4 header
    longfill(@_ip_src_addr, 0, 2)
    wordfill(@_tot_len, 0, 4)
    bytefill(@_ver, 0, 7)
    _ver := 4
    _hdr_len := 5 { 20 / 4 }
    _ip_flags := %010
    _ttl := 128
    _ident := $0001

PUB Rd_IP_Header{}: ptr | tmp
' Read IP header from buffer
    tmp := rd_byte{}
        _ver := ((tmp >> 4) & $0f)
        _hdr_len := (tmp & $0f)
    tmp := rd_byte{}
        _dsvc := ((tmp >> 2) & $3f)
        _ecn := (tmp & $03)
    _tot_len := rdword_msbf{}
    _ident := rdword_lsbf{}
    tmp := rdword_lsbf{}
        _ip_flags := ((tmp.byte[0] >> 5) & $03)
        _frag_offs := (((tmp.byte[1] & $1f) << 8) | tmp.byte[2])
    _ttl := rd_byte{}
    _proto := rd_byte{}
    _hdr_chk := rdword_lsbf{}
    rdblk_lsbf(@_ip_src_addr, IPV4ADDR_LEN)
    rdblk_lsbf(@_ip_dest_addr, IPV4ADDR_LEN)
    return currptr{}

PUB Wr_IP_Header{}: ptr   ' TODO: move the shifting/masking to the Set*() methods
' Write IP header to buffer
'   Returns: length of assembled header, in bytes
    wr_byte((_ver << 4) | _hdr_len)
    wr_byte((_dsvc << 2) | _ecn)
    wrword_msbf(_tot_len)
    wrword_msbf(_ident)
    wr_byte((_ip_flags << 5) | (_frag_offs >> 8) & $1f)
    wr_byte(_frag_offs & $ff)
    wr_byte(_ttl)
    wr_byte(_proto)
    wrword_lsbf(_hdr_chk)
    wrblk_lsbf(@_ip_src_addr, IPV4ADDR_LEN)
    wrblk_lsbf(@_ip_dest_addr, IPV4ADDR_LEN)
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

