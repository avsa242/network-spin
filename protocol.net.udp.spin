{
    --------------------------------------------
    Filename: protocol.net.udp.spin
    Author: Jesse Burt
    Description: Universal Datagram Protocol
    Started Feb 28, 2022
    Updated Mar 13, 2022
    Copyright 2022
    See end of file for terms of use.
    --------------------------------------------
}
#include "net-common.spinh"
#include "services.spinh"

CON

{ Limits }
    UDP_MSG_LEN = 8

VAR

    word _src_port, _dest_port
    word _length
    word _cksum
    byte _ptr

PUB Checksum{}: ck
' Get checksum
    return _cksum

PUB DestPort{}: p
' Get destination port field
    return _dest_port

PUB Length{}: len
' Get length of UDP datagram
    return _length

PUB SetChecksum(ck)
' Set checksum
    _cksum := ck

PUB SetDestPort(p)
' Set destination port field
    _dest_port := p

PUB SetLength(len)
' Set length of UDP datagram
    _length := len

PUB SetSourcePort(p)
' Set source port field
    _src_port := p

PUB SourcePort{}: p
' Get source port field
    return _src_port

PUB HeaderLen{}: len
' Get current header length
    return _ptr

PUB ReadDgram(ptr_buff)
' Read UDP datagram from ptr_buff
    _ptr := 0
    _src_port := (byte[ptr_buff][_ptr++] << 8) | byte[ptr_buff][_ptr++]
    _dest_port := (byte[ptr_buff][_ptr++] << 8) | byte[ptr_buff][_ptr++]
    _length := (byte[ptr_buff][_ptr++] << 8) | byte[ptr_buff][_ptr++]
    _cksum := (byte[ptr_buff][_ptr++] << 8) | byte[ptr_buff][_ptr++]
    return _ptr

PUB ResetPtr{}  'XXX tentative
' Reset buffer pointer
    _ptr := 0

PUB WriteDgram(ptr_buff): ptr | chksum, chkbuff[5], i
' Write assembled UDP datagram to ptr_buff
'   Returns: length of assembled datagram, in bytes
    _ptr := 0
    byte[ptr_buff][_ptr++] := _src_port.byte[1]
    byte[ptr_buff][_ptr++] := _src_port.byte[0]
    byte[ptr_buff][_ptr++] := _dest_port.byte[1]
    byte[ptr_buff][_ptr++] := _dest_port.byte[0]
    byte[ptr_buff][_ptr++] := _length.byte[1]
    byte[ptr_buff][_ptr++] := _length.byte[0]
    byte[ptr_buff][_ptr++] := $00                ' checksum - ignore for now
    byte[ptr_buff][_ptr++] := $00                ' since it's optional in UDP

    wordfill(@_src_port, 0, 4)                  ' clear vars after writing

    return _ptr

