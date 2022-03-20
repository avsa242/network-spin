{
    --------------------------------------------
    Filename: protocol.net.eth-ii.spin
    Author: Jesse Burt
    Description: Ethernet II protocol
    Started Mar 1, 2022
    Updated Mar 17, 2022
    Copyright 2022
    See end of file for terms of use.
    --------------------------------------------
}
#include "net-common.spinh"

VAR

    byte _dest_addr[MACADDR_LEN]
    byte _src_addr[MACADDR_LEN]
    word _eth_t

PUB GetEthertype{}: eth_t
' Get ethertype of ethernet frame
'   Returns: word
    return _eth_t

PUB GetDestAddr{}: addr
' Get destination address of ethernet frame
'   Returns: pointer to 6-byte MAC address
    return @_dest_addr

PUB GetSrcAddr{}: addr
' Get source address of ethernet frame
'   Returns: pointer to 6-byte MAC address
    return @_src_addr

PUB Ethertype(eth_t)
' Set ethertype of ethernet frame
    _eth_t := eth_t

PUB DestAddr(ptr_addr)
' Set destination address of ethernet frame
    bytemove(@_dest_addr, ptr_addr, MACADDR_LEN)

PUB SrcAddr(ptr_addr)
' Set source address of ethernet frame
    bytemove(@_src_addr, ptr_addr, MACADDR_LEN)

PUB ReadFrame(ptr_buff): ptr | i
' Read ethernet-II frame
'   Returns: number of bytes read
    ptr := 0
    bytemove(@_dest_addr, ptr_buff+ptr, MACADDR_LEN)
    ptr += MACADDR_LEN
    bytemove(@_src_addr, ptr_buff+ptr, MACADDR_LEN)
    ptr += MACADDR_LEN
    _eth_t.byte[1] := byte[ptr_buff][ptr++]
    _eth_t.byte[0] := byte[ptr_buff][ptr++]

PUB WriteFrame(ptr_buff): ptr | i
' Write ethernet-II frame
    ptr := 0
    bytemove(ptr_buff+ptr, @_dest_addr, MACADDR_LEN)
    ptr += MACADDR_LEN
    bytemove(ptr_buff+ptr, @_src_addr, MACADDR_LEN)
    ptr += MACADDR_LEN
    byte[ptr_buff][ptr++] := _eth_t.byte[1]
    byte[ptr_buff][ptr++] := _eth_t.byte[0]

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

