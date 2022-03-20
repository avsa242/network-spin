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

{ offsets within header }
    SRC_PORT    = 0
    DEST_PORT   = 2
    DGRAMLEN    = 4
    CKSUM       = 6

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

PUB Rd_UDP_Header(ptr_buff)
' Read UDP header from ptr_buff
'   Returns: length of read header, in bytes
    _ptr := 0
    _src_port := (byte[ptr_buff][_ptr++] << 8) | byte[ptr_buff][_ptr++]
    _dest_port := (byte[ptr_buff][_ptr++] << 8) | byte[ptr_buff][_ptr++]
    _length := (byte[ptr_buff][_ptr++] << 8) | byte[ptr_buff][_ptr++]
    _cksum := (byte[ptr_buff][_ptr++] << 8) | byte[ptr_buff][_ptr++]
    return _ptr

PUB ResetPtr{}  'XXX tentative
' Reset buffer pointer
    _ptr := 0

PUB Wr_UDP_Header(ptr_buff): ptr
' Write assembled UDP header to ptr_buff
'   Returns: length of assembled header, in bytes
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

