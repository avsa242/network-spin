{
    --------------------------------------------
    Filename: protocol.net.arp.spin
    Author: Jesse Burt
    Description: Address Resolution Protocol
    Started Feb 27, 2022
    Updated Aug 2, 2023
    Copyright 2023
    See end of file for terms of use.
    --------------------------------------------
}
#ifndef NET_COMMON
#include "net-common.spinh"
#endif

CON

    { limits }
    ARP_MSG_SZ      = 28                        ' message length

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

OBJ

    { virtual instance of network device object }
    net=    NETDEV_OBJ

VAR

    { obj pointer }
    long _dev

    byte _arp_data[ARP_MSG_SZ]
    byte _mac_local[MACADDR_LEN]

pub init(optr)
' Set pointer to network device object
    _dev := optr

PUB hw_addrLen{}: len
' Get hardware address length
'   Returns: byte
    return _arp_hln

PUB hw_type{}: hrd
' Get hardware/hardware address type
'   Returns: word
    hrd.byte[0] := _arp_data[ARP_HW_T_L]
    hrd.byte[1] := _arp_data[ARP_HW_T_M]

PUB opcode{}: op
' Get ARP operation code
'   Returns: byte
    op.byte[0] := _arp_data[ARP_OP_CODE_L]
    op.byte[1] := _arp_data[ARP_OP_CODE_M]

PUB proto_addr_len{}: len
' Get protocol address length
'   Returns: byte
    return _arp_data[ARP_PRADDR_LEN]

PUB proto_type{}: pro
' Get protocol/protocol address type
'   Returns: word
    pro.byte[0] := _arp_data[ARP_PROTO_T_L]
    pro.byte[1] := _arp_data[ARP_PROTO_T_M]

PUB reply() | ip_tmp, mac_tmp[2]
' Set up next ARP message to "reply" to the previous
    set_opcode(ARP_REPL)

    { temporarily store the current sender addresses }
    bytemove(@ip_tmp, @_arp_data[ARP_SNDR_PRADDR], IPV4ADDR_LEN)
    bytemove(@mac_tmp, @_arp_data[ARP_SNDR_HWADDR], MACADDR_LEN)

    { update the sender addresses to the last received target IP, and the locally set MAC }
    bytemove(@_arp_data[ARP_SNDR_PRADDR], @_arp_data[ARP_TGT_PRADDR], IPV4ADDR_LEN)
    bytemove(@_arp_data[ARP_SNDR_HWADDR], @_mac_local, MACADDR_LEN)

    { update the target addresses to the temporarily stored sender addresses }
    bytemove(@_arp_data[ARP_TGT_PRADDR], @ip_tmp, IPV4ADDR_LEN)
    bytemove(@_arp_data[ARP_TGT_HWADDR], @mac_tmp, MACADDR_LEN)

    wr_arp_msg()

PUB sender_hw_addr{}: ptr_addr
' Get sender hardware address
'   Returns: pointer to 6-byte MAC address
    return @_arp_data[ARP_SNDR_HWADDR]

PUB sender_proto_addr{}: addr | i
' Get sender protocol address
'   Returns: 4-byte IPv4 address, packed into long
    repeat i from 0 to 3
        addr.byte[i] := _arp_data[ARP_SNDR_PRADDR+i]

PUB target_hw_addr{}: ptr_addr
' Get target hardware address
'   Returns: pointer to 6-byte MAC address
    return @_arp_data[ARP_TGT_HWADDR]

PUB target_proto_addr{}: addr | i
' Get target protocol address
'   Returns: 4-byte IPv4 address, packed into long
    repeat i from 0 to 3
        addr.byte[i] := _arp_data[ARP_TGT_PRADDR+i]

PUB set_hw_addr_len(len)
' Set hardware address length
    _arp_data[ARP_HWADDR_LEN] := len

PUB set_hwtype(hrd)
' Set hardware type
    _arp_data[ARP_HW_T_M] := hrd.byte[1]
    _arp_data[ARP_HW_T_L] := hrd.byte[0]

PUB set_opcode(op)
' Set ARP operation code
    _arp_data[ARP_OP_CODE_M] := op.byte[1]
    _arp_data[ARP_OP_CODE_L] := op.byte[0]

PUB set_proto_addr_len(len)
' Set protocol address length
    _arp_data[ARP_PRADDR_LEN] := len

PUB set_proto_type(pro)
' Set protocol type
    _arp_data[ARP_PROTO_T_M] := pro.byte[1]
    _arp_data[ARP_PROTO_T_L] := pro.byte[0]

PUB set_sender_hw_addr(ptr_addr)
' Set sender hardware address
    bytemove(@_arp_data[ARP_SNDR_HWADDR], ptr_addr, MACADDR_LEN)

PUB set_sender_proto_addr(addr) | i
' Set sender protocol address
    repeat i from 0 to 3
        _arp_data[ARP_SNDR_PRADDR+i] := addr.byte[i]

PUB set_target_hw_addr(ptr_addr)
' Set target hardware address
    bytemove(@_arp_data[ARP_TGT_HWADDR], ptr_addr, MACADDR_LEN)

PUB set_target_proto_addr(addr) | i
' Set target protocol address
    repeat i from 0 to 3
        _arp_data[ARP_TGT_PRADDR+i] := addr.byte[i]

PUB rd_arp_msg{}: ptr
' Read ARP message
    net[_dev].rdblk_lsbf(@_arp_data, ARP_MSG_SZ)
    return net[_dev].fifo_wr_ptr{}

PUB wr_arp_msg{}: ptr
' Write ARP message
    net[_dev].wrblk_lsbf(@_arp_data, ARP_MSG_SZ)
    return net[_dev].fifo_wr_ptr{}

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

