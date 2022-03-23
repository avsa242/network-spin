{
    --------------------------------------------
    Filename: protocol.net.arp.spin
    Author: Jesse Burt
    Description: Address Resolution Protocol
    Started Feb 27, 2022
    Updated Mar 23, 2022
    Copyright 2022
    See end of file for terms of use.
    --------------------------------------------
}
#ifndef NET_COMMON
#include "net-common.spinh"
#endif

CON

{ ARP message indices }
    ARP_LEN         = 28                        ' message length

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

    long _arp_spa
    long _arp_tpa

    word _arp_hrd
    word _arp_pro
    word _arp_op
    byte _arp_hln
    byte _arp_pln
    byte _arp_sha[MACADDR_LEN]
    byte _arp_tha[MACADDR_LEN]

PUB ARP_HWAddrLen{}: len
' Get hardware address length
'   Returns: byte
    return _arp_hln

PUB ARP_HWType{}: hrd
' Get hardware/hardware address type
'   Returns: word
    return _arp_hrd

PUB ARP_Opcode{}: op
' Get ARP operation code
'   Returns: byte
    return _arp_op

PUB ARP_ProtoAddrLen{}: len
' Get protocol address length
'   Returns: byte
    return _arp_pln

PUB ARP_ProtoType{}: pro
' Get protocol/protocol address type
'   Returns: word
    return _arp_pro

PUB ARP_SenderHWAddr{}: ptr_addr
' Get sender hardware address
'   Returns: pointer to 6-byte MAC address
    return @_arp_sha

PUB ARP_SenderProtoAddr{}: addr
' Get sender protocol address
'   Returns: 4-byte IPv4 address, packed into long
    return _arp_spa

PUB ARP_TargetHWAddr{}: ptr_addr
' Get target hardware address
'   Returns: pointer to 6-byte MAC address
    return @_arp_tha

PUB ARP_TargetProtoAddr{}: addr
' Get target protocol address
'   Returns: 4-byte IPv4 address, packed into long
    return _arp_tpa

PUB SetARP_HWAddrLen(len)
' Set hardware address length
    _arp_hln := len

PUB SetARP_HWType(hrd)
' Set hardware type
    _arp_hrd := hrd

PUB SetARP_Opcode(op)
' Set ARP operation code
    _arp_op := op

PUB SetARP_ProtoAddrLen(len)
' Set protocol address length
    _arp_pln := len

PUB SetARP_ProtoType(pro)
' Set protocol type
    _arp_pro := pro

PUB SetARP_SenderHWAddr(ptr_addr)
' Set sender hardware address
    bytemove(@_arp_sha, ptr_addr, MACADDR_LEN)

PUB SetARP_SenderProtoAddr(addr)
' Set sender protocol address
    _arp_spa := addr

PUB SetARP_TargetHWAddr(ptr_addr)
' Set target hardware address
    bytemove(@_arp_tha, ptr_addr, MACADDR_LEN)

PUB SetARP_TargetProtoAddr(addr)
' Set target protocol address
    _arp_tpa := addr

PUB Rd_ARP_Msg{}: ptr
' Read ARP message
    _arp_hrd := rdword_msbf{}
    _arp_pro := rdword_msbf{}
    _arp_hln := rd_byte{}
    _arp_pln := rd_byte{}
    _arp_op := rdword_msbf{}
    rdblk_lsbf(@_arp_sha, MACADDR_LEN)
    rdblk_lsbf(@_arp_spa, IPV4ADDR_LEN)
    rdblk_lsbf(@_arp_tha, MACADDR_LEN)
    rdblk_lsbf(@_arp_tpa, IPV4ADDR_LEN)
    return currptr{}

PUB Wr_ARP_Msg{}: ptr
' Write ARP message
    wrword_msbf(_arp_hrd)
    wrword_msbf(_arp_pro)
    wr_byte(_arp_hln)
    wr_byte(_arp_pln)
    wrword_msbf(_arp_op)
    wrblk_lsbf(@_arp_sha, MACADDR_LEN)
    wrblk_lsbf(@_arp_spa, IPV4ADDR_LEN)
    wrblk_lsbf(@_arp_tha, MACADDR_LEN)
    wrblk_lsbf(@_arp_tpa, IPV4ADDR_LEN)
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

