{
    --------------------------------------------
    Filename: protocol.net.udp.spin
    Author: Jesse Burt
    Description: Universal Datagram Protocol
    Started Feb 28, 2022
    Updated Mar 22, 2022
    Copyright 2022
    See end of file for terms of use.
    --------------------------------------------
}
#ifndef NET_COMMON
#include "net-common.spinh"
#endif

'#include "services.spinh"

CON

{ Limits }
    UDP_MSG_LEN     = 8

{ offsets within header }
    UDP_SRC_PORT    = 0
    UDP_DEST_PORT   = 2
    UDP_DGRAMLEN    = 4
    UDP_CKSUM       = 6

VAR

    word _src_port, _dest_port
    word _length
    word _cksum

PUB DestPort{}: p
' Get destination port field
    return _dest_port

PUB Length{}: len
' Get length of UDP datagram
    return _length

PUB SetDestPort(p)
' Set destination port field
    _dest_port := p

PUB SetLength(len)
' Set length of UDP datagram
    _length := len

PUB SetSourcePort(p)
' Set source port field
    _src_port := p

PUB SetUDPChecksum(ck)
' Set checksum
    _cksum := ck

PUB SourcePort{}: p
' Get source port field
    return _src_port

PUB UDPChecksum{}: ck
' Get checksum
    return _cksum

PUB UDPHeaderLen{}: len
' Get current header length
    return UDP_MSG_LEN

PUB Rd_UDP_Header{}
' Read UDP header from ptr_buff
'   Returns: length of read header, in bytes
    _src_port := rdword_msbf{}
    _dest_port := rdword_msbf{}
    _length := rdword_msbf{}
    _cksum := rdword_msbf{}
    return currptr{}

PUB Wr_UDP_Header{}: ptr
' Write assembled UDP header to ptr_buff
'   Returns: length of assembled header, in bytes
'    wrblk_msbf(@_src_port, 2)
    wrword_msbf(_src_port)
    wrword_msbf(_dest_port)
    wrword_msbf(_length)
    wrword_msbf(_cksum)
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

