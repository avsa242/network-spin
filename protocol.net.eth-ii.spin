{
    --------------------------------------------
    Filename: protocol.net.eth-ii.spin
    Author: Jesse Burt
    Description: Ethernet II protocol
    Started Mar 1, 2022
    Updated Mar 1, 2022
    Copyright 2022
    See end of file for terms of use.
    --------------------------------------------
}
#include "net-common.spinh"

CON

{ Ethertypes }
    IPV4    = $0800
    ARP     = $0806
    IPV6    = $86DD
    LLDP    = $88CC

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

PUB DestAddr(ptr_addr) | i, ptr
' Set destination address of ethernet frame
    ptr := 0
    repeat i from 0 to 5
        _dest_addr.byte[i] := byte[ptr_addr][ptr++]

PUB SrcAddr(ptr_addr) | i, ptr
' Set source address of ethernet frame
'    bytemove(@_src_addr, ptr_addr, MACADDR_LEN)
    ptr := 0
    repeat i from 0 to 5
        _src_addr.byte[i] := byte[ptr_addr][ptr++]

PUB ReadFrame(ptr_buff): ptr | i
' Read ethernet-II frame
'   Returns: number of bytes read
    ptr := 0
    repeat i from 5 to 0
        _dest_addr.byte[i] := byte[ptr_buff][ptr++]
    repeat i from 5 to 0
        _src_addr.byte[i] := byte[ptr_buff][ptr++]
    _eth_t.byte[1] := byte[ptr_buff][ptr++]
    _eth_t.byte[0] := byte[ptr_buff][ptr++]

PUB WriteFrame(ptr_buff): ptr | i
' Write ethernet-II frame
    ptr := 0
    repeat i from 5 to 0
        byte[ptr_buff][ptr++] := _dest_addr.byte[i]
    repeat i from 5 to 0
        byte[ptr_buff][ptr++] := _src_addr.byte[i]
    byte[ptr_buff][ptr++] := _eth_t.byte[1]
    byte[ptr_buff][ptr++] := _eth_t.byte[0]

