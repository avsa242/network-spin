{
    --------------------------------------------
    Filename: protocol.net.ip.spin
    Author: Jesse Burt
    Description: Internet Protocol
    Started Feb 27, 2022
    Updated Mar 22, 2022
    Copyright 2022
    See end of file for terms of use.
    --------------------------------------------
}
#ifndef NET_COMMON
#include "net-common.spinh"
#endif

CON

{ offsets within header}
    VERS            = 0
    HDRLEN          = 0
    DSCP_ECN        = 1
    TLEN            = 2
    IDENT           = 4'..5
    FLAGS_FRGH      = 6
    FRGL            = 7
    T2L             = 8
    PRTCL           = 9
    IPCKSUM         = 10'..11
    SRCIP           = 12'..15
    DSTIP           = 16'..19

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

PUB DestIP{}: addr
' Get destination address of IP datagram
'   Returns: 4 IPv4 address bytes packed into long
    return _ip_dest_addr

PUB DSCP{}: cp
' Differentiated services code point
'   Returns: 6-bit code point
    return _dsvc

PUB ECN{}: state
' Explicit Congestion Notification
'   Returns: 2-bit ECN state
    return _ecn

PUB Flags{}: f  'XXX methods to set DF and MF
' Get fragmentation control flags
'   Returns: 3-bit field
    return _ip_flags

PUB FragOffset{}: o
' Get offset in overall message of this fragment
'   Returns: 13-bit offset
    return _frag_offs

PUB HdrChksum{}: cksum
' Get header checksum
'   Returns: word
    return _hdr_chk

PUB IPHeaderLen{}: len
' Get header length, in longwords
'   Returns: byte
    return _hdr_len

PUB MsgIdent{}: id
' Get identification common to all fragments in a message
'   Returns: word
    return _ident

PUB Layer4Proto{}: proto
' Get protocol carried in datagram
'   Returns: byte
    return _proto

PUB Rd_IP_Header{}: ptr | tmp
' Read IP datagram from buffer
    tmp := rd_byte{}
        _ver := ((tmp >> 4) & $0f)
        _hdr_len := (tmp & $0f)
    tmp := rd_byte{}
        _dsvc := ((tmp >> 2) & $3f)
        _ecn := (tmp & $03)
    _tot_len := rdword_lsbf{}
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

PUB SetDestIP(addr)
' Get destination address of IP datagram
'   Returns: 4 IPv4 address bytes packed into long
    _ip_dest_addr := addr

PUB SetDSCP(cp)
' Differentiated services code point
'   Returns: 6-bit code point
    _dsvc := cp

PUB SetECN(state)
' Explicit Congestion Notification
'   Returns: 2-bit ECN state
    _ecn := state

PUB SetFlags(f)  'XXX methods to set DF and MF
' Get fragmentation control flags
'   Returns: 3-bit field
    _ip_flags := f

PUB SetFragOffset(o)
' Get offset in overall message of this fragment
'   Returns: 13-bit offset
    _frag_offs := o

PUB SetHdrChksum(cksum)
' Get header checksum
'   Returns: word
    _hdr_chk := cksum

PUB SetHeaderLen(len)
' Get header length, in longwords
'   Returns: byte
    _hdr_len := len

PUB SetMsgIdent(id)
' Get identification common to all fragments in a message
'   Returns: word
    _ident := id

PUB SetLayer4Proto(proto)
' Get protocol carried in datagram
'   Returns: byte
    _proto := proto

PUB SetSourceIP(addr)
' Get source/originator of IP datagram
'   Returns: 4 IPv4 address bytes packed into long
    _ip_src_addr := addr

PUB SetTimeToLive(ttl)
' Get number of router hops datagram is allowed to traverse
'   Returns: byte
    _ttl := ttl

PUB SetTotalLen(len)
' Return total length of IP datagram, in bytes
'   Returns: word
    _tot_len := len

PUB SetIPVersion(ver)
' Get IP version
'   Returns: byte
    _ver := ver

PUB SourceIP{}: addr
' Get source/originator of IP datagram
'   Returns: 4 IPv4 address bytes packed into long
    return _ip_src_addr

PUB TimeToLive{}: ttl
' Get number of router hops datagram is allowed to traverse
'   Returns: byte

PUB TotalLen{}: len
' Return total length of IP datagram, in bytes
'   Returns: word
    return _tot_len

PUB IPVersion{}: ver
' Get IP version
'   Returns: byte
    return _ver

PUB Wr_IP_Header{}: ptr | i   ' TODO: move the shifting/masking to the Set*() methods
' Write IP datagram to buffer
'   Returns: length of assembled datagram, in bytes
    wr_byte((_ver << 4) | _hdr_len)
    wr_byte((_dsvc << 2) | _ecn)
    wrword_msbf(_tot_len)
    wrword_msbf(_ident)
    wr_byte((_ip_flags << 5) | (_frag_offs >> 8) & $1f)
    wr_byte(_frag_offs & $ff)
    wr_byte(_ttl)
    wr_byte(_proto)
    wrword_msbf(_hdr_chk)
    wrblk_msbf(@_ip_src_addr, IPV4ADDR_LEN)
    wrblk_msbf(@_ip_dest_addr, IPV4ADDR_LEN)
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

