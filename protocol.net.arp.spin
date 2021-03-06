{
    --------------------------------------------
    Filename: protocol.net.arp.spin
    Author: Jesse Burt
    Description: Address Resolution Protocol
    Started Feb 27, 2022
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
    ARP_MSG_SZ      = 28                        ' message length

    { offsets within message }
    ARP_ABS_ST      = ETH_TYPE+2                ' add to the below for abs. position within frame

    ARP_HW_T        = 0'..1                     ' 16b/2B
    ARP_PROTO_T     = 2'..3                     ' 16b/2B
    ARP_HWADDR_LEN  = 4                         ' 8b/1B
    ARP_PRADDR_LEN  = 5                         ' 8b/1B
    ARP_OP_CODE     = 6'..7                     ' 16b/2B
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

    byte _arp_data[ARP_MSG_SZ]

PUB ARP_HWAddrLen{}: len
' Get hardware address length
'   Returns: byte
    return _arp_hln

PUB ARP_HWType{}: hrd
' Get hardware/hardware address type
'   Returns: word
    hrd.byte[0] := _arp_data[ARP_HW_T+1]
    hrd.byte[1] := _arp_data[ARP_HW_T]

PUB ARP_Opcode{}: op
' Get ARP operation code
'   Returns: byte
    op.byte[0] := _arp_data[ARP_OP_CODE+1]
    op.byte[1] := _arp_data[ARP_OP_CODE]

PUB ARP_ProtoAddrLen{}: len
' Get protocol address length
'   Returns: byte
    return _arp_data[ARP_PRADDR_LEN]

PUB ARP_ProtoType{}: pro
' Get protocol/protocol address type
'   Returns: word
    pro.byte[0] := _arp_data[ARP_PROTO_T+1]
    pro.byte[1] := _arp_data[ARP_PROTO_T]

PUB ARP_SenderHWAddr{}: ptr_addr
' Get sender hardware address
'   Returns: pointer to 6-byte MAC address
    return @_arp_data[ARP_SNDR_HWADDR]

PUB ARP_SenderProtoAddr{}: addr | i
' Get sender protocol address
'   Returns: 4-byte IPv4 address, packed into long
    repeat i from 0 to 3
        addr.byte[i] := _arp_data[ARP_SNDR_PRADDR+i]

PUB ARP_TargetHWAddr{}: ptr_addr
' Get target hardware address
'   Returns: pointer to 6-byte MAC address
    return @_arp_data[ARP_TGT_HWADDR]

PUB ARP_TargetProtoAddr{}: addr | i
' Get target protocol address
'   Returns: 4-byte IPv4 address, packed into long
    repeat i from 0 to 3
        addr.byte[i] := _arp_data[ARP_TGT_PRADDR+i]

PUB ARP_SetHWAddrLen(len)
' Set hardware address length
    _arp_data[ARP_HWADDR_LEN] := len

PUB ARP_SetHWType(hrd)
' Set hardware type
    _arp_data[ARP_HW_T] := hrd.byte[1]
    _arp_data[ARP_HW_T+1] := hrd.byte[0]

PUB ARP_SetOpcode(op)
' Set ARP operation code
    _arp_data[ARP_OP_CODE] := op.byte[1]
    _arp_data[ARP_OP_CODE+1] := op.byte[0]

PUB ARP_SetProtoAddrLen(len)
' Set protocol address length
    _arp_data[ARP_PRADDR_LEN] := len

PUB ARP_SetProtoType(pro)
' Set protocol type
    _arp_data[ARP_PROTO_T] := pro.byte[1]
    _arp_data[ARP_PROTO_T+1] := pro.byte[0]

PUB ARP_SetSenderHWAddr(ptr_addr)
' Set sender hardware address
    bytemove(@_arp_data[ARP_SNDR_HWADDR], ptr_addr, MACADDR_LEN)

PUB ARP_SetSenderProtoAddr(addr) | i
' Set sender protocol address
    repeat i from 0 to 3
        _arp_data[ARP_SNDR_PRADDR+i] := addr.byte[i]

PUB ARP_SetTargetHWAddr(ptr_addr)
' Set target hardware address
    bytemove(@_arp_data[ARP_TGT_HWADDR], ptr_addr, MACADDR_LEN)

PUB ARP_SetTargetProtoAddr(addr) | i
' Set target protocol address
    repeat i from 0 to 3
        _arp_data[ARP_TGT_PRADDR+i] := addr.byte[i]

PUB Rd_ARP_Msg{}: ptr
' Read ARP message
    rdblk_lsbf(@_arp_data, ARP_MSG_SZ)
    return currptr{}

PUB Wr_ARP_Msg{}: ptr
' Write ARP message
    wrblk_lsbf(@_arp_data, ARP_MSG_SZ)
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

