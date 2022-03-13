{
    --------------------------------------------
    Filename: protocol.net.ip.spin
    Author: Jesse Burt
    Description: Internet Protocol
    Started Feb 27, 2022
    Updated Feb 28, 2022
    Copyright 2022
    See end of file for terms of use.
    --------------------------------------------
}
#include "net-common.spinh"

CON

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

    byte _ver                                   ' version[7..4]:IHL[3..0]
    byte _hdr_len                               ' in 32-bit words; bytes = *4
    byte _dsvc                                  ' dsc[7..2]:ecn[1..0]
    byte _ecn
    word _tot_len
    word _ident
    byte _flags
    word _frag_offs                             ' flags[15..13]:frag[12..0]
    byte _ttl
    byte _proto
    word _hdr_chk
    byte _src_addr[IPV4ADDR_LEN]
    byte _dest_addr[IPV4ADDR_LEN]

PUB DestAddr{}: addr
' Get destination address of IP datagram
'   Returns: 4 IPv4 address bytes packed into long
    bytemove(@addr, @_dest_addr, IPV4ADDR_LEN)

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
    return _flags

PUB FragOffset{}: o
' Get offset in overall message of this fragment
'   Returns: 13-bit offset
    return _frag_offs

PUB HdrChksum{}: cksum
' Get header checksum
'   Returns: word
    return _hdr_chk

PUB HeaderLen{}: len
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

PUB ReadDgram(ptr_buff): ptr | i
' Read IP datagram from buffer
    ptr := 0
    _ver := ((byte[ptr_buff][ptr] >> 4) & $0f)
    _hdr_len := (byte[ptr_buff][ptr++] & $0f)
    _dsvc := ((byte[ptr_buff][ptr] >> 2) & $3f)
    _ecn := (byte[ptr_buff][ptr++] & $03)
    _tot_len := ((byte[ptr_buff][ptr++] << 8) | byte[ptr_buff][ptr++])
    _ident := ((byte[ptr_buff][ptr++] << 8) | byte[ptr_buff][ptr++])
    _flags := (byte[ptr_buff][ptr] >> 5) & $03
    _frag_offs := (((byte[ptr_buff][ptr++] & $1f) << 8) | byte[ptr_buff][ptr++])
    _ttl := byte[ptr_buff][ptr++]
    _proto := byte[ptr_buff][ptr++]
    _hdr_chk := ((byte[ptr_buff][ptr++] << 8) | byte[ptr_buff][ptr++])
    repeat i from 3 to 0
        _src_addr[i] := byte[ptr_buff][ptr++]
    repeat i from 3 to 0
        _dest_addr[i] := byte[ptr_buff][ptr++]

CON

    CS6     = $30

PUB WriteDgram(ptr_buff): ptr | i   ' TODO: move the shifting/masking to the Set*() methods
' Read IP datagram from buffer
'   Returns: length of assembled datagram, in bytes
    ptr := 0
    byte[ptr_buff][ptr++] := (_ver << 4) | _hdr_len
    byte[ptr_buff][ptr++] := (_dsvc << 2) | _ecn
    byte[ptr_buff][ptr++] := _tot_len.byte[1]
    byte[ptr_buff][ptr++] := _tot_len.byte[0]
    byte[ptr_buff][ptr++] := _ident.byte[1]
    byte[ptr_buff][ptr++] := _ident.byte[0]
    byte[ptr_buff][ptr++] := (_flags << 5) | (_frag_offs >> 8) & $1f ' _flags | upper 5 bits of _frag_offs
    byte[ptr_buff][ptr++] := _frag_offs & $ff   ' lower 8 bits
    byte[ptr_buff][ptr++] := _ttl
    byte[ptr_buff][ptr++] := _proto
    byte[ptr_buff][ptr++] := _hdr_chk.byte[1]
    byte[ptr_buff][ptr++] := _hdr_chk.byte[0]
    repeat i from 3 to 0
        byte[ptr_buff][ptr++] := _src_addr[i]
    repeat i from 3 to 0
        byte[ptr_buff][ptr++] := _dest_addr[i]

PUB SetDestAddr(addr)
' Get destination address of IP datagram
'   Returns: 4 IPv4 address bytes packed into long
    bytemove(@_dest_addr, @addr, IPV4ADDR_LEN)

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
    _flags := f

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

PUB SetSourceAddr(addr)
' Get source/originator of IP datagram
'   Returns: 4 IPv4 address bytes packed into long
    bytemove(@_src_addr, @addr, IPV4ADDR_LEN)

PUB SetTimeToLive(ttl)
' Get number of router hops datagram is allowed to traverse
'   Returns: byte
    _ttl := ttl

PUB SetTotalLen(len)
' Return total length of IP datagram, in bytes
'   Returns: word
    _tot_len := len

PUB SetVersion(ver)
' Get IP version
'   Returns: byte
    _ver := ver

'--
PUB SourceAddr{}: addr
' Get source/originator of IP datagram
'   Returns: 4 IPv4 address bytes packed into long
    bytemove(@addr, @_src_addr, IPV4ADDR_LEN)

PUB TimeToLive{}: ttl
' Get number of router hops datagram is allowed to traverse
'   Returns: byte

PUB TotalLen{}: len
' Return total length of IP datagram, in bytes
'   Returns: word
    return _tot_len

PUB Version{}: ver
' Get IP version
'   Returns: byte
    return _ver


