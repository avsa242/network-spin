{
    --------------------------------------------
    Filename: protocol.net.arp.spin
    Author: Jesse Burt
    Description: Address Resolution Protocol
    Started Feb 27, 2022
    Updated Nov 8, 2023
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
    ENTRIES         = 10                        ' ARP cache entries (RAM usage: n * 11 bytes)
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

    { virtual objects }
    net=    NETIF_DRIVER                          ' network device driver


VAR

    { network device obj pointer }
    long dev

    { ARP message }
    byte _arp_data[ARP_MSG_SZ]

    { ARP table/cache }
    byte _entry_used[ENTRIES]
    byte _hw_addr[ENTRIES * MACADDR_LEN]
    long _proto_addr[ENTRIES]


PUB init(netdev_ptr)
' Set pointer to network device object
    dev := netdev_ptr

PUB cache_entry(hw_addr, proto_addr): ent_nr
' Cache an entry in the ARP table
    { check for an existing entry with this protocol address first }
    ent_nr := read_entry_by_proto_addr(proto_addr)
    if ( ent_nr => 0 )                          ' 0 is _always_ the entry for our own node
        { found an existing entry: update it with the new hardware address }
        bytemove(hw_ent(ent_nr), hw_addr, MACADDR_LEN)
    else
        { not found: create a new entry }
        repeat ent_nr from 0 to (ENTRIES-1)
            ifnot ( _entry_used[ent_nr] )
                bytemove(hw_ent(ent_nr), hw_addr, MACADDR_LEN)
                _proto_addr[ent_nr] := proto_addr
                _entry_used[ent_nr] := 1
                return
        return -10                              ' cache full; no entries available

PUB drop_entry(ent_nr)
' Drop a cached entry from the ARP table
    bytefill(hw_ent(ent_nr), 0, 6)
    _proto_addr[ent_nr] := 0
    _entry_used[ent_nr] := false

PUB entry_is_used(ent_nr): f
' Flag indicating entry in the ARP table is used
    return ( _entry_used[ent_nr] <> 0 )

pub find_mac_by_ip(ip): hw | tmp
' Read an entry from the cache by IP address
    tmp := read_entry_by_proto_addr(ip)
    if ( tmp => 0 )
        return hw_ent( tmp )

PUB hw_addrLen{}: len
' Get hardware address length
'   Returns: byte
    return _arp_hln

PUB hw_ent(ent_nr): p
' Calculate the pointer to a hardware address in the ARP table, given an entry number
'   ent_nr: entry number (1..(ENTRIES-1) )
'   Returns: pointer to hardware address (OUI first)
    return @_hw_addr+(ent_nr*6)

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

PUB read_entry(ent_nr): hw, proto
' Read an entry from the cache
'   Returns (2 return values):
'       1) pointer to HW address
'       2) protocol address
    return hw_ent(ent_nr), _proto_addr[ent_nr]

PUB read_entry_by_proto_addr(proto_addr): ent_nr
' Find an entry in the ARP table by its protocol address
'   proto_addr: protocol address (4 bytes)
'   Returns: entry number in ARP table, or -1 if not found
    repeat ent_nr from 0 to (ENTRIES-1)
        if ( entry_is_used(ent_nr) and (_proto_addr[ent_nr] == proto_addr) )
            return ent_nr

    return -1

pub read_entry_mac(ent_nr): hw
' Read an entry from the cache
'   Returns:
'       pointer to HW address
    return hw_ent(ent_nr)

PUB reply() | ip_tmp, mac_tmp[2]
' Set up next ARP message to "reply" to the previous
    set_opcode(ARP_REPL)

    { temporarily store the current sender addresses }
    bytemove(@ip_tmp, @_arp_data[ARP_SNDR_PRADDR], IPV4ADDR_LEN)
    bytemove(@mac_tmp, @_arp_data[ARP_SNDR_HWADDR], MACADDR_LEN)

    { update the sender addresses to the last received target IP, and the locally set MAC }
    bytemove(@_arp_data[ARP_SNDR_PRADDR], @_arp_data[ARP_TGT_PRADDR], IPV4ADDR_LEN)
    bytemove(@_arp_data[ARP_SNDR_HWADDR], @net[dev]._mac_local, MACADDR_LEN)

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
    net[dev].rdblk_lsbf(@_arp_data, ARP_MSG_SZ)
    return net[dev].fifo_wr_ptr{}

PUB who_has(my_proto_addr, proto_addr)
' Send a query for a protocol address
    set_hw_addr_len(MACADDR_LEN)
    set_hwtype(HRD_ETH)
    set_opcode(ARP_REQ)
    set_proto_addr_len(IPV4ADDR_LEN)
    set_proto_type(ETYP_IPV4)

    { who has d.d.d.d? }
    set_target_hw_addr(@_mac_zero)
    set_target_proto_addr(proto_addr)

    { tell d.d.d.d (xx:xx:xx:xx:xx:xx) }
    set_sender_hw_addr(hw_ent(0))
    set_sender_proto_addr(my_proto_addr)

    wr_arp_msg()

PUB wr_arp_msg{}: ptr
' Write ARP message
    net[dev].wrblk_lsbf(@_arp_data, ARP_MSG_SZ)
    return net[dev].fifo_wr_ptr{}

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

