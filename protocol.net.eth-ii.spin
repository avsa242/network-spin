{
    --------------------------------------------
    Filename: protocol.net.eth-ii.spin
    Author: Jesse Burt
    Description: Ethernet II protocol
    Started Mar 1, 2022
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
    ETH_FRM_SZ      = 14

    { offsets within frame }
    ETH_DEST        = 0
    ETH_SRC         = ETH_DEST+MACADDR_LEN
    ETH_TYPE        = ETH_SRC+MACADDR_LEN

VAR

    byte _ethii_data[ETH_FRM_SZ]

PUB ETHII_DestAddr{}: addr
' Get destination address of ethernet frame
'   Returns: pointer to 6-byte MAC address
    return @_ethii_data[ETH_DEST]

PUB ETHII_Ethertype{}: eth_t
' Get ethertype of ethernet frame
'   Returns: word
    eth_t.byte[0] := _ethii_data[ETH_TYPE+1]
    eth_t.byte[1] := _ethii_data[ETH_TYPE]

PUB ETHII_SrcAddr{}: addr
' Get source address of ethernet frame
'   Returns: pointer to 6-byte MAC address
    return @_ethii_data[ETH_SRC]

PUB ETHII_SetDestAddr(ptr_addr)
' Set destination address of ethernet frame
    bytemove(@_ethii_data, ptr_addr, MACADDR_LEN)

PUB ETHII_SetEthertype(eth_t)
' Set ethertype of ethernet frame
    _ethii_data[ETH_TYPE] := eth_t.byte[1]
    _ethii_data[ETH_TYPE+1] := eth_t.byte[0]

PUB ETHII_SetSrcAddr(ptr_addr)
' Set source address of ethernet frame
    bytemove(@_ethii_data + ETH_SRC, ptr_addr, MACADDR_LEN)

PUB Rd_ETHII_Frame{}: ptr
' Read ethernet-II frame
'   Returns: number of bytes read
    rdblk_lsbf(@_ethii_data, ETH_FRM_SZ)
    return currptr{}

PUB Wr_ETHII_Frame{}: ptr
' Write ethernet-II frame
    wrblk_lsbf(@_ethii_data, ETH_FRM_SZ)
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

