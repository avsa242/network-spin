{
    --------------------------------------------
    Filename: protocol.net.arp.spin
    Author: Jesse Burt
    Description: Address Resolution Protocol
    Started Feb 27, 2022
    Updated Feb 27, 2022
    Copyright 2022
    See end of file for terms of use.
    --------------------------------------------
}
#include "net-common.spinh"

CON

{ ARP message indices }
    ARP_LEN         = 28                        ' message length

    ARP_HW_T        = 0'..1                     ' 16b/2B
    ARP_PROTO_T     = 2'..3                     ' 16b/2B
    ARP_HWADDR_LEN  = 4                         ' 8b/1B
    ARP_PRADDR_LEN  = 5                         ' 8b/1B
    ARP_OPCODE      = 6'..7                     ' 16b/2B
    ARP_SNDR_HWADDR = 8'..13                    ' 48b/6B
    ARP_SNDR_PRADDR = 14'..17                   ' 32b/4B
    ARP_TGT_HWADDR  = 18'..23                   ' 48b/6B
    ARP_TGT_PRADDR  = 24'..27                   ' 32b/4B

{ hardware types }
    HRD_ETH         = 1                         ' only these first two are
    HRD_IEEE802     = 6                         '   officially supported

    HRD_ARCNET      = 7
    HRD_FRMRLY      = 15
    HRD_ATM         = 16
    HRD_HDLC        = 17
    HRD_FIBRECH     = 18
    HRD_ATM2        = 19
    HRD_SERIAL      = 20

{ opcodes }
    ARP_REQ         = 1
    ARP_REPL        = 2
    RARP_REQ        = 3
    RARP_REPL       = 4
    DRARP_REQ       = 5
    DRARP_REPL      = 6
    DRARP_ERR       = 7
    INARP_REQ       = 8
    INARP_REPL      = 9

VAR

    word _arp_hrd
    word _arp_pro
    byte _arp_hln
    byte _arp_pln
    byte _arp_op
    byte _arp_sha[MACADDR_LEN]
    byte _arp_spa[IPV4ADDR_LEN]
    byte _arp_tha[MACADDR_LEN]
    byte _arp_tpa[IPV4ADDR_LEN]

PUB HWAddrLen{}: len
' Get hardware address length
'   Returns: byte
    return _arp_hln

PUB HWType{}: hrd
' Get hardware/hardware address type
'   Returns: word
    return _arp_hrd

PUB OpCode{}: op
' Get ARP operation code
'   Returns: byte
    return _arp_op

PUB ProtoAddrLen{}: len
' Get protocol address length
'   Returns: byte
    return _arp_pln

PUB ProtoType{}: pro
' Get protocol/protocol address type
'   Returns: word
    return _arp_pro

PUB ReadARP(ptr_buff) | i, ptr
' Read ARP message
    ptr := 0
    sethwtype((byte[ptr_buff][ptr++] << 8) | byte[ptr_buff][ptr++])
    setprototype((byte[ptr_buff][ptr++] << 8) | byte[ptr_buff][ptr++])
    sethwaddrlen(byte[ptr_buff][ptr++])
    setprotoaddrlen(byte[ptr_buff][ptr++])
    setopcode((byte[ptr_buff][ptr++] << 8) | byte[ptr_buff][ptr++])

    repeat i from _arp_hln-1 to 0
        _arp_sha[i] := byte[ptr_buff][ptr++]
    repeat i from _arp_pln-1 to 0
        _arp_spa[i] := byte[ptr_buff][ptr++]
    repeat i from _arp_hln-1 to 0
        _arp_tha[i] := byte[ptr_buff][ptr++]
    repeat i from _arp_pln-1 to 0
        _arp_tpa[i] := byte[ptr_buff][ptr++]

PUB SenderHWAddr{}: ptr_addr
' Get sender hardware address
'   Returns: pointer to 6-byte MAC address
    return @_arp_sha

PUB SenderProtoAddr{}: addr
' Get sender protocol address
'   Returns: 4-byte IPv4 address, packed into long
    bytemove(@addr, @_arp_spa, IPV4ADDR_LEN)

PUB SetHWAddrLen(len)
' Set hardware address length
    _arp_hln := len

PUB SetHWType(hrd)
' Set hardware type
    _arp_hrd := hrd

PUB SetOpCode(op)
' Set ARP operation code
    _arp_op := op

PUB SetProtoAddrLen(len)
' Set protocol address length
    _arp_pln := len

PUB SetProtoType(pro)
' Set protocol type
    _arp_pro := pro

PUB SetSenderHWAddr(ptr_addr)
' Set sender hardware address
    bytemove(@_arp_sha, ptr_addr, 6)

PUB SetSenderProtoAddr(addr)
' Set sender protocol address
    _arp_spa := addr

PUB SetTargetHWAddr(ptr_addr)
' Set target hardware address
    bytemove(@_arp_tha, ptr_addr, 6)

PUB SetTargetProtoAddr(addr)
' Set target protocol address
    _arp_tpa := addr

PUB TargetHWAddr{}: ptr_addr
' Get target hardware address
'   Returns: pointer to 6-byte MAC address
    return @_arp_tha

PUB TargetProtoAddr{}: addr
' Get target protocol address
'   Returns: 4-byte IPv4 address, packed into long
    bytemove(@addr, @_arp_tpa, IPV4ADDR_LEN)

PUB WriteARP(ptr_buff): ptr | i
' Write ARP message
    ptr := 0
    byte[ptr_buff][ptr++] := _arp_hrd.byte[1]
    byte[ptr_buff][ptr++] := _arp_hrd.byte[0]
    byte[ptr_buff][ptr++] := _arp_pro.byte[1]
    byte[ptr_buff][ptr++] := _arp_pro.byte[0]
    byte[ptr_buff][ptr++] := _arp_hln
    byte[ptr_buff][ptr++] := _arp_pln
    byte[ptr_buff][ptr++] := _arp_op.byte[1]
    byte[ptr_buff][ptr++] := _arp_op.byte[0]

    repeat i from _arp_hln-1 to 0
        byte[ptr_buff][ptr++] := _arp_sha[i]
    repeat i from _arp_pln-1 to 0
        byte[ptr_buff][ptr++] := _arp_spa[i]
    repeat i from _arp_hln-1 to 0
        byte[ptr_buff][ptr++] := _arp_tha[i]
    repeat i from _arp_pln-1 to 0
        byte[ptr_buff][ptr++] := _arp_tpa[i]

