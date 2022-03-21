{
    --------------------------------------------
    Filename: protocol.net.bootp.spin
    Author: Jesse Burt
    Description: Boot Protocol/Dynamic Host Configuration Protocol
    Started Feb 28, 2022
    Updated Mar 21, 2022
    Copyright 2022
    See end of file for terms of use.
    --------------------------------------------
}
#ifndef NET_COMMON
#include "net-common.spinh"
#endif

CON

    DHCP_MAGIC_COOKIE   = $63_82_53_63
    DHCP_MAGIC_COOKIE3  = ((DHCP_MAGIC_COOKIE >> 24) & $FF)
    DHCP_MAGIC_COOKIE2  = ((DHCP_MAGIC_COOKIE >> 16) & $FF)
    DHCP_MAGIC_COOKIE1  = ((DHCP_MAGIC_COOKIE >> 8) & $FF)
    DHCP_MAGIC_COOKIE0  = (DHCP_MAGIC_COOKIE & $FF)

    FLAG_B              = 15

    HDWADDRLEN_MAX      = 16
    LSE_90DAYS          = (90 * time#DAY)

    SRV_HOSTN_LEN       = 64
    BOOT_FN_LEN         = 128

{ BOOTP Opcodes }
    BOOT_REQ            = $01
    BOOT_REPL           = $02

{ Hardware types }
    ETHERNET            = $01
    IEEE802             = $06

{ DHCP options }
    HOSTNAME            = $0C
    SUBNET_MASK         = $01   ' resp
    ROUTER              = $03   ' resp
    DNS                 = $06   ' resp
    DEF_IP_TTL          = $17
    BCAST_ADDR          = $1C   ' resp
    REQD_IPADDR         = $32
    IP_LEASE_TM         = $33   ' resp
    MSG_TYPE            = $35
    DHCP_SRV_ID         = $36   ' resp
    PARAM_REQLST        = $37
    MAX_DHCP_MSGSZ      = $39
    RENEWAL_TM          = $3A   ' resp
    REBIND_TM           = $3B   ' resp
    CLIENT_ID           = $3D
    OPT_END             = $FF

{ DHCP Message types }
    DHCPDISCOVER        = $01
    DHCPOFFER           = $02
    DHCPREQUEST         = $03
    DHCPDECLINE         = $04
    DHCPACK             = $05
    DHCPNAK             = $06
    DHCPRELEASE         = $07
    DHCPINFORM          = $08

VAR

    long _trans_id
    long _dhcp_lease_tm
    long _dhcp_renewal_tm
    long _dhcp_rebind_tm

    long _dhcp_srv_ip
    long _subnet_mask
    long _bcast_ip
    long _router_ip
    long _dns_ip

    long _client_ip
    long _your_ip
    long _srv_ip
    long _gwy_ip

    word _lstime_elapsed
    word _flags
    word _dhcp_max_msg_len
    word _dhcp_msg_len

    byte _bootp_opcode
    byte _hdw_addr_len
    byte _hops
    byte _client_hw_t
    byte _client_mac[MACADDR_LEN]
    byte _client_hdw_addr_pad
    byte _srv_hostname[SRV_HOSTN_LEN+1]         ' str + 0
    byte _boot_fname[BOOT_FN_LEN+1]             ' str + 0

    byte _dhcp_opts_len
    byte _dhcp_param_req[5]
    byte _dhcp_msg_t

OBJ

    time    : "time"

PUB BroadcastIP{}: addr
' Get broadcast IP address
    return _bcast_ip

PUB BootFName{}: ptr_str
' Get boot filename
    bytemove(ptr_str, @_boot_fname, strsize(@_boot_fname))

PUB BroadcastFlag{}: f
' Get BOOTP broadcast flag
    return (((_flags >> FLAG_B) & 1) == 1)

PUB CliHdwAddrPadLen{}: len
' Get length of client hardware address padding
    return _client_hdw_addr_pad

PUB ClientIP{}: addr
' Get client IP address
    bytemove(@addr, @_client_ip, IPV4ADDR_LEN)

PUB ClientMAC{}: ptr_addr
' Get client MAC address
    bytemove(ptr_addr, @_client_mac, MACADDR_LEN)

PUB DHCPMsgType{}: t
' Get type of DHCP message
    return _dhcp_msg_t

PUB DHCPSrvIP{}: addr
' Get DHCP server IP address
    bytemove(@addr, @_dhcp_srv_ip, IPV4ADDR_LEN)

PUB DNSIP{}: addr
' Get domain name server IP address
    return _dns_ip

PUB GatewayIP{}: addr
' Get relay agent IP address
    return _gwy_ip

PUB HdwAddrLen{}: len
' Set hardware address length
    return _hdw_addr_len

PUB HdwType{}: t
' Get hardware type
    return _client_hw_t

PUB Hops{}: h
' Get number of hops
    return _hops

PUB IPLeaseTime{}: s
' Get lease time of IP address, in seconds
    return _dhcp_lease_tm

PUB IPRebindTime{}: s
' Get rebinding time of IP address, in seconds
    return _dhcp_rebind_tm

PUB IPRenewalTime{}: s
' Get renewal time of IP address, in seconds
    return _dhcp_renewal_tm

PUB LeaseElapsed{}: s
' Get time elapsed since start of attempt to acquire or renew lease
    return _lstime_elapsed

PUB OpCode{}: c
' Get BOOTP message opcode
    return _bootp_opcode

PUB RouterIP{}: addr
' Get router IP address
    return _router_ip

PUB RsvdFlags{}: flags
' Get BOOTP reserved flags
    return _flags & $7fff

PUB ServerHostname{}: ptr_str
' Set server hostname
    bytemove(ptr_str, @_srv_hostname, strsize(@_srv_hostname))

PUB ServerIP{}: addr
' Get next server IP address
    return _srv_ip

PUB SubnetMask{}: mask
' Get subnet mask
    return _subnet_mask

PUB TransID{}: id
' Get transaction ID
    return _trans_id

PUB YourIP{}: addr | i
' Get your IP address
    return _your_ip

PUB SetBootFName(ptr_str)
' Set boot filename
    bytemove(@_boot_fname, ptr_str, strsize(ptr_str))

PUB SetBroadcastFlag(flag)
' Set BOOTP broadcast flag
'   Valid values:
'       FALSE (0), TRUE (any non-zero value)
    _flags := (||(flag <> 0)) << FLAG_B

PUB SetClientIP(addr)
' Set client IP address
    bytemove(@_client_ip, @addr, IPV4ADDR_LEN)

PUB SetClientMAC(ptr_addr)
' Set client MAC address
    bytemove(@_client_mac, ptr_addr, MACADDR_LEN)

PUB SetDHCPMaxMsgLen(len)
' Set maximum accepted DHCP message length
    _dhcp_max_msg_len := len

PUB DHCPMsgLen{}: ptr
' Get length of assembled DHCP message
    return _dhcp_msg_len

PUB SetDHCPMsgType(type)
' Set DHCP message type
    _dhcp_msg_t := type

PUB SetGatewayIP(addr)
' Set relay agent IP address
    _gwy_ip := addr

PUB SetHdwAddrLen(len)
' Set hardware address length
    _hdw_addr_len := len

PUB SetHdwType(t)
' Set hardware type
    _client_hw_t := t

PUB SetHops(h)
' Set number of hops
    _hops := h

PUB SetIPLeaseTime(s)
' Set lease time for IP address, in seconds
    _dhcp_lease_tm := s

PUB SetIPRebindTime(s)
' Set rebinding time for IP address, in seconds
    _dhcp_rebind_tm := s

PUB SetIPRenewalTime(s)
' Set renewal time for IP address, in seconds
    _dhcp_renewal_tm := s

PUB SetLeaseStartElapsed(s)
' Set time elapsed since start of attempt to acquire or renew lease
    _lstime_elapsed := s

PUB SetOpCode(c)
' Set BOOTP message opcode
    _bootp_opcode := c

PUB SetParamsReqd(ptr_buff, len)
' Set list of parameters to retrieve from DHCP server
    bytemove(@_dhcp_param_req, ptr_buff, (len <# 5))

PUB Rd_BOOTP_Msg{}: ptr | i, tmp
' Read BOOTP message, as well as DHCP message, if it exists
    _bootp_opcode := rd_byte{}
    _client_hw_t := rd_byte{}
    _hdw_addr_len := rd_byte{}
    _hops := rd_byte
    _trans_id := rdlong_lsbf{}
    _lstime_elapsed := rdword_lsbf{}
    _flags := rdword_lsbf{}
    rdblk_lsbf(@_client_ip, IPV4ADDR_LEN)
    rdblk_lsbf(@_your_ip, IPV4ADDR_LEN)
    rdblk_lsbf(@_srv_ip, IPV4ADDR_LEN)
    rdblk_lsbf(@_gwy_ip, IPV4ADDR_LEN)
    rdblk_lsbf(@_client_mac, MACADDR_LEN)

    { skip over the hardware address padding }
    incptr(HDWADDRLEN_MAX-MACADDR_LEN)

    { and record its length }
    _client_hdw_addr_pad := (HDWADDRLEN_MAX-MACADDR_LEN)

    rdblk_lsbf(@_srv_hostname, SRV_HOSTN_LEN)
    rdblk_lsbf(@_boot_fname, BOOT_FN_LEN)

    { does the message contain a DHCP message? }
    if (rdlong_msbf{} == DHCP_MAGIC_COOKIE)
        rd_dhcp_msg{}
    else
        setptr(currptr{}-4)                     ' rewind if it's not DHCP
    return currptr{}

PUB Rd_DHCP_Msg{}: ptr | t
' Read DHCP message
    { read through all TLVs }
    repeat
        t := rd_byte{}
        case t
            MSG_TYPE:
                rd_byte{}                       ' skip over the length byte
                _dhcp_msg_t := rd_byte{}
            DHCP_SRV_ID:
                rd_byte{}
                rdblk_lsbf(@_dhcp_srv_ip, IPV4ADDR_LEN)
            IP_LEASE_TM:
                rd_byte{}
                rdblk_msbf(@_dhcp_lease_tm, 4)
            RENEWAL_TM:
                rd_byte{}
                rdblk_msbf(@_dhcp_renewal_tm, 4)
            REBIND_TM:
                rd_byte{}
                rdblk_msbf(@_dhcp_rebind_tm, 4)
            SUBNET_MASK:
                rd_byte{}
                rdblk_lsbf(@_subnet_mask, IPV4ADDR_LEN)
            BCAST_ADDR:
                rd_byte{}
                rdblk_lsbf(@_bcast_ip, IPV4ADDR_LEN)
            ROUTER:
                rd_byte{}
                rdblk_lsbf(@_router_ip, IPV4ADDR_LEN)
            DNS:
                rd_byte{}
                rdblk_lsbf(@_dns_ip, IPV4ADDR_LEN)
            OPT_END:
                rd_byte{}
    until (t == OPT_END)    'XXX not safeguarded against bad messages missing the OPT_END ($FF) byte
    return curr_pos{}

PUB SetServerIP(addr)
' Set server IP address
    bytemove(@_srv_ip, @addr, IPV4ADDR_LEN)

PUB Wr_BOOTP_Msg{}: ptr | st
' Write BOOTP message
'   Returns: number of bytes written to buffer
    st := currptr{}
    wr_byte(_bootp_opcode)
    wr_byte(_client_hw_t)
    wr_byte(_hdw_addr_len)
    wr_byte(_hops)
    wrlong_msbf(_trans_id)
    wrword_msbf(_lstime_elapsed)
    wrword_msbf(_flags)
    wrblk_msbf(@_client_ip, IPV4ADDR_LEN)
    wrblk_msbf(@_your_ip, IPV4ADDR_LEN)
    wrblk_msbf(@_srv_ip, IPV4ADDR_LEN)
    wrblk_msbf(@_gwy_ip, IPV4ADDR_LEN)
    wrblk_lsbf(@_client_mac, MACADDR_LEN)
    wr_bytex($00, HDWADDRLEN_MAX-MACADDR_LEN)
    wrblk_lsbf(@_srv_hostname, SRV_HOSTN_LEN)
    wrblk_lsbf(@_boot_fname, BOOT_FN_LEN)
    return currptr{}-st

PUB Wr_DHCP_Msg{}: ptr | st
' Write DHCP message, preceded by BOOTP message
'   NOTE: Ensure DHCPMsgType() is set, prior to calling this method
    st := currptr{}

    { start with BOOTP message }
    wr_bootp_msg{}

    { then the DHCP 'magic cookie' value to identify it as a DHCP message }
    wrlong_msbf(DHCP_MAGIC_COOKIE)

    { finally, the DHCP 'options' }
    _dhcp_opts_len := 0
    writetlv(MSG_TYPE, 1, _dhcp_msg_t)
    writetlv(PARAM_REQLST, 5, @_dhcp_param_req)
    writetlv(CLIENT_ID, 7, @_client_hw_t)    ' HW type, then HW addr
    if (_dhcp_msg_t == DHCPDISCOVER)
        writetlv(MAX_DHCP_MSGSZ, 2, _dhcp_max_msg_len)
    elseif (_dhcp_msg_t == DHCPREQUEST)
        writetlv(REQD_IPADDR, 4, @_your_ip)
        writetlv(DHCP_SRV_ID, 4, @_dhcp_srv_ip)
    writetlv(IP_LEASE_TM, 4, @_dhcp_lease_tm)
    writetlv(OPT_END, 0, 0)

    { pad the end of the message equal to the number of bytes in the options }
    wr_bytex($00, _dhcp_opts_len)
    _dhcp_msg_len := (currptr{} - st)
    return currptr{}-st

PUB SetServerHostname(ptr_str)
' Set server hostname, up to 64 bytes
    bytemove(@_srv_hostname, ptr_str, strsize(ptr_str) <# SRV_HOSTN_LEN)

PUB SetTransID(id)
' Set transaction ID
    _trans_id := id

PUB WriteTLV(type, len, val): ptr
' Write TLV to ptr_buff
'   len:
'       1..2: values will be read (MSByte-first) directly from parameter
'       3..255: values will be read by pointer passed in ptr_val
'       other values: only the type will be written
'   Returns: total length of TLV (includes: type, length, and all values)
    { track length of DHCP options; it'll be needed later for padding
        the end of the DHCP message }
    _dhcp_opts_len += wr_byte(type)
    case len
        1..2:                                   ' immediate value
            _dhcp_opts_len += wr_byte(len)
            _dhcp_opts_len += wrblk_msbf(@val, len)
        3..255:                                 ' value pointed to
            _dhcp_opts_len += wr_byte(len)
            if (type == REQD_IPADDR or type == DHCP_SRV_ID or type == CLIENT_ID) 'XXX temp hack - add byte order param?
                _dhcp_opts_len += wrblk_lsbf(val, len)
            else
                _dhcp_opts_len += wrblk_msbf(val, len)
        other:                                  ' type only
    return _dhcp_opts_len

PUB SetYourIP(addr)
' Set 'your' IP address
    bytemove(@_your_ip, @addr, IPV4ADDR_LEN)

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

