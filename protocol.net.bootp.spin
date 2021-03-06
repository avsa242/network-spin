{
    --------------------------------------------
    Filename: protocol.net.bootp.spin
    Author: Jesse Burt
    Description: Boot Protocol/Dynamic Host Configuration Protocol
    Started Feb 28, 2022
    Updated Apr 23, 2022
    Copyright 2022
    See end of file for terms of use.
    --------------------------------------------
}
#ifndef NET_COMMON
#include "net-common.spinh"
#endif

CON

    { limits }
    BOOTP_MSG_SZ        = 236
    SRV_HOSTN_LEN       = 64
    BOOT_FN_LEN         = 128
    HDWADDRLEN_MAX      = 16

    { offsets within message }
    BOOTP_ABS_ST        = UDP_CKSUM + 2         ' add to the below for abs. position within frame

    BOOTPM_OP           = 0
    BOOTPM_CLI_HW_T     = 1
    BOOTPM_HW_ADDR_LEN  = 2
    BOOTPM_HOP          = 3
    BOOTPM_XID          = 4
    BOOTPM_LSTM_EL      = 8
     BOOTPM_LSTM_EL_L   = 9
    BOOTPM_FLAGS        = 10
     BOOTPM_FLAGS_L     = 11
    BOOTPM_CIP          = 12
    BOOTPM_YIP          = BOOTPM_CIP+IPV4ADDR_LEN
    BOOTPM_SIP          = BOOTPM_YIP+IPV4ADDR_LEN
    BOOTPM_GIP          = BOOTPM_SIP+IPV4ADDR_LEN
    BOOTPM_CLI_MAC      = BOOTPM_GIP+IPV4ADDR_LEN
    BOOTPM_HOSTNM       = BOOTPM_CLI_MAC + (HDWADDRLEN_MAX-MACADDR_LEN)
    BOOTPM_FILENM       = BOOTPM_HOSTNM + SRV_HOSTN_LEN

    DHCP_MAGIC_COOKIE   = $63_82_53_63
    DHCP_MAGIC_COOKIE3  = ((DHCP_MAGIC_COOKIE >> 24) & $FF)
    DHCP_MAGIC_COOKIE2  = ((DHCP_MAGIC_COOKIE >> 16) & $FF)
    DHCP_MAGIC_COOKIE1  = ((DHCP_MAGIC_COOKIE >> 8) & $FF)
    DHCP_MAGIC_COOKIE0  = (DHCP_MAGIC_COOKIE & $FF)

    BCAST_BIT           = 15-8                  ' bit 15 of flags, but bit 7 of MSByte

    SECOND              = 1
    MINUTE              = 60 * SECOND
    HR                  = 60 * MINUTE
    DAY                 = 24 * HR
    LSE_90DAYS          = 90 * DAY

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

    long _dhcp_lease_tm
    long _dhcp_renewal_tm
    long _dhcp_rebind_tm

    long _dhcp_srv_ip
    long _subnet_mask
    long _bcast_ip
    long _router_ip
    long _dns_ip

    word _dhcp_max_msg_len
    word _dhcp_msg_len

    byte _client_hw_t

    byte _dhcp_opts_len
    byte _dhcp_param_req[5]
    byte _dhcp_msg_t

    byte _bootp_data[BOOTP_MSG_SZ]

PUB BOOTP_BcastFlag{}: f
' Get BOOTP broadcast flag
    f := (((_bootp_data[BOOTPM_FLAGS] >> BCAST_BIT) & 1) == 1)

PUB BOOTP_BootFN{}: ptr_str
' Get boot filename
    ptr_str := @_bootp_data[BOOTPM_FILENM]

PUB BOOTP_ClientIP{}: addr | i
' Get client IP address
    repeat i from 0 to 3
        addr.byte[i] := _bootp_data[BOOTPM_CIP+i]

PUB BOOTP_ClientMAC{}: ptr_addr
' Get client MAC address
    ptr_addr := @_bootp_data[BOOTPM_CLI_MAC]

PUB BOOTP_CliHdwAddrPadLen{}: len
' Get length of client hardware address padding
    return HDWADDRLEN_MAX-MACADDR_LEN   ' XXX make constant

PUB BOOTP_GwyIP{}: addr | i
' Get relay agent IP address
    repeat i from 0 to 3
        addr.byte[i] := _bootp_data[BOOTPM_GIP+i]

PUB BOOTP_HdwAddrLen{}: len
' Get hardware address length
    len := _bootp_data[BOOTPM_HW_ADDR_LEN]

PUB BOOTP_HdwType{}: t
' Get hardware type
    t := _bootp_data[BOOTPM_CLI_HW_T]

PUB BOOTP_Hops{}: h
' Get number of hops
    h := _bootp_data[BOOTPM_HOP]

PUB BOOTP_Inc_XID{}
' Increment xid/transaction ID by 1
    _bootp_data[BOOTPM_XID]++

PUB BOOTP_LeaseElapsed{}: s
' Get time elapsed since start of attempt to acquire or renew lease
    s.byte[0] := _bootp_data[BOOTPM_LSTM_EL]
    s.byte[1] := _bootp_data[BOOTPM_LSTM_EL_L]

PUB BOOTP_Opcode{}: c
' Get BOOTP message opcode
    c := _bootp_data[BOOTPM_OP]

PUB BOOTP_RsvdFlags{}: flags
' Get BOOTP reserved flags
    flags.byte[0] := _bootp_data[BOOTPM_FLAGS_L]
    flags.byte[1] := _bootp_data[BOOTPM_FLAGS]

PUB BOOTP_SrvHostname{}: ptr_str
' Get server hostname
    ptr_str := @_bootp_data[BOOTPM_HOSTNM]

PUB BOOTP_SrvIP{}: addr | i
' Get next server IP address
    repeat i from 0 to 3
        addr.byte[i] := _bootp_data[BOOTPM_SIP+i]

PUB BOOTP_XID{}: id
' Get transaction ID
    return _bootp_xid

PUB BOOTP_YourIP{}: addr | i
' Get your IP address
    repeat i from 0 to 3
        addr.byte[i] := _bootp_data[BOOTPM_YIP+i]

PUB DHCP_BcastIP{}: addr
' Get broadcast IP address
    return _bcast_ip

PUB DHCP_DNSIP{}: addr
' Get domain name server IP address
    return _dns_ip

PUB DHCP_IPLeaseTime{}: s
' Get lease time of IP address, in seconds
    return _dhcp_lease_tm

PUB DHCP_IPRebindTime{}: s
' Get rebinding time of IP address, in seconds
    return _dhcp_rebind_tm

PUB DHCP_IPRenewTime{}: s
' Get renewal time of IP address, in seconds
    return _dhcp_renewal_tm

PUB DHCP_MaxMsgLen{}: len
' Get maximum accepted DHCP message length
    return _dhcp_max_msg_len

PUB DHCP_MsgLen{}: ptr
' Get length of assembled DHCP message
    return _dhcp_msg_len

PUB DHCP_MsgType{}: t
' Get type of DHCP message
    return _dhcp_msg_t

PUB DHCP_RouterIP{}: addr
' Get router IP address
    return _router_ip

PUB DHCP_SrvIP{}: addr
' Get DHCP server IP address
    bytemove(@addr, @_dhcp_srv_ip, IPV4ADDR_LEN)

PUB DHCP_SubnetMask{}: mask
' Get subnet mask
    return _subnet_mask

PUB BOOTP_SetBcastFlag(flag)
' Set BOOTP broadcast flag
'   Valid values:
'       TRUE (any non-zero value), FALSE (0)
    _bootp_data[BOOTPM_FLAGS] := (||(flag <> 0)) << BCAST_BIT

PUB BOOTP_SetBootFN(ptr_str)
' Set boot filename
    bytemove(@_bootp_data[BOOTPM_FILENM], ptr_str, strsize(ptr_str) <# BOOT_FN_LEN)

PUB BOOTP_SetClientIP(addr) | i
' Set client IP address
    repeat i from 0 to 3
        _bootp_data[BOOTPM_CIP+i] := addr.byte[i]

PUB BOOTP_SetClientMAC(ptr_addr)
' Set client MAC address
    bytemove(@_bootp_data[BOOTPM_CLI_MAC], ptr_addr, MACADDR_LEN)

PUB BOOTP_SetCliHdwAddrPadLen(len) 'XXX pseudo-metadata that's calculated
' Set length of client hardware address padding
'    _client_hdw_addr_pad := len

PUB BOOTP_SetGwyIP(addr) | i
' Set relay agent IP address
    repeat i from 0 to 3
        _bootp_data[BOOTPM_GIP+i] := addr.byte[i]

PUB BOOTP_SetHdwAddrLen(len)
' Set hardware address length
    _bootp_data[BOOTPM_HW_ADDR_LEN] := len

PUB BOOTP_SetHdwType(t)
' Set hardware type
    _bootp_data[BOOTPM_CLI_HW_T] := t

PUB BOOTP_SetHops(h)
' Set number of hops
    _bootp_data[BOOTPM_HOP] := h

PUB BOOTP_SetLeaseElapsed(s)
' Set time elapsed since start of attempt to acquire or renew lease
    _bootp_data[BOOTPM_LSTM_EL] := s.byte[0]
    _bootp_data[BOOTPM_LSTM_EL_L] := s.byte[1]

PUB BOOTP_SetOpcode(c)
' Set BOOTP message opcode
    _bootp_data[BOOTPM_OP] := c

PUB BOOTP_SetRsvdFlags(flags)
' Set BOOTP reserved flags
    _bootp_data[BOOTPM_FLAGS] |= flags.byte[1] & $7f
    _bootp_data[BOOTPM_FLAGS_L] := flags.byte[0]

PUB BOOTP_SetSrvHostname(ptr_str)
' Set server hostname, up to 64 bytes
    bytemove(@_bootp_data[BOOTPM_HOSTNM], ptr_str, strsize(ptr_str) <# SRV_HOSTN_LEN)

PUB BOOTP_SetSrvIP(addr) | i
' Set server IP address
    repeat i from 0 to 3
        _bootp_data[BOOTPM_GIP+i] := addr.byte[i]

PUB BOOTP_SetXID(id) | i
' Set transaction ID
    repeat i from 0 to 3
        _bootp_data[BOOTPM_XID+i] := id.byte[i]

PUB BOOTP_SetYourIP(addr)
' Set 'your' IP address
    bytemove(@_bootp_data[BOOTPM_YIP], @addr, IPV4ADDR_LEN)

PUB DHCP_SetBcastIP(addr)
' Set broadcast IP address
    bytemove(@_bcast_ip, @addr, IPV4ADDR_LEN)

PUB DHCP_SetDNSIP(addr)
' Set domain name server IP address
    bytemove(@_dns_ip, @addr, IPV4ADDR_LEN)

PUB DHCP_SetIPLeaseTime(s)
' Set lease time for IP address, in seconds
    _dhcp_lease_tm := s

PUB DHCP_SetIPRebindTime(s)
' Set rebinding time for IP address, in seconds
    _dhcp_rebind_tm := s

PUB DHCP_SetIPRenewTime(s)
' Set renewal time for IP address, in seconds
    _dhcp_renewal_tm := s

PUB DHCP_SetMaxMsgLen(len)
' Set maximum accepted DHCP message length
    _dhcp_max_msg_len := len

PUB DHCP_SetMsgType(msgtype)
' Set DHCP message type
    _dhcp_msg_t := msgtype

PUB DHCP_SetParamsReqd(ptr_buff, len)
' Set list of parameters to retrieve from DHCP server
    bytemove(@_dhcp_param_req, ptr_buff, (len <# 5))

PUB DHCP_SetRouterIP(addr)
' Set router IP address
    bytemove(@_router_ip, @addr, IPV4ADDR_LEN)

PUB DHCP_SetSrvIP(addr)
' Set DHCP server IP address
    bytemove(@_dhcp_srv_ip, @addr, IPV4ADDR_LEN)

PUB DHCP_SetSubnetMask(mask)
' Set subnet mask
    bytemove(@_subnet_mask, @mask, IPV4ADDR_LEN)

PUB Reset_BOOTP{}
' Reset all values to defaults
    bytefill(@_bootp_data, 0, BOOTP_MSG_SZ)
    _bootp_data[BOOTPM_CLI_HW_T] := ETHERNET
    _bootp_data[BOOTPM_HW_ADDR_LEN] := MACADDR_LEN
    _bootp_data[BOOTPM_LSTM_EL] := $00
    _bootp_data[BOOTPM_LSTM_EL_L] := $01

PUB Rd_BOOTP_Msg{}: ptr
' Read BOOTP message, as well as DHCP message, if it exists
    rdblk_lsbf(@_bootp_data, BOOTP_MSG_SZ)

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
    return currptr{}

PUB Wr_BOOTP_Msg{}: ptr | st
' Write BOOTP message
'   Returns: number of bytes written to buffer
    st := currptr{}
    wrblk_lsbf(@_bootp_data, BOOTP_MSG_SZ)
    return currptr{}-st

CON

    LSBF    = 0
    MSBF    = 1

PUB Wr_DHCP_Msg{}: ptr | st
' Write DHCP message, preceded by BOOTP message
'   NOTE: Ensure DHCP_SetMsgType() is set, prior to calling this method
    st := currptr{}

    { start with BOOTP message }
    wr_bootp_msg{}

    { then the DHCP 'magic cookie' value to identify it as a DHCP message }
    wrlong_msbf(DHCP_MAGIC_COOKIE)

    { finally, the DHCP 'options' }
    _dhcp_opts_len := 0
    writetlv(MSG_TYPE, 1, _dhcp_msg_t, LSBF)
    writetlv(PARAM_REQLST, 5, @_dhcp_param_req, LSBF)
'    writetlv(CLIENT_ID, 7, @_client_hw_t, LSBF)       ' HW type, then HW addr
    wr_byte(CLIENT_ID)
    wr_byte(7)
    wr_byte(_bootp_data[BOOTPM_CLI_HW_T])
    wrblk_lsbf(@_bootp_data[BOOTPM_CLI_MAC], MACADDR_LEN)
    if (_dhcp_msg_t == DHCPDISCOVER)
        writetlv(MAX_DHCP_MSGSZ, 2, _dhcp_max_msg_len, MSBF)
    elseif (_dhcp_msg_t == DHCPREQUEST)
        writetlv(REQD_IPADDR, 4, @_bootp_data[BOOTPM_YIP], LSBF)
        writetlv(DHCP_SRV_ID, 4, @_dhcp_srv_ip, LSBF)
    writetlv(IP_LEASE_TM, 4, @_dhcp_lease_tm, MSBF)
    writetlv(OPT_END, 0, 0, LSBF)

    { pad the end of the message equal to the number of bytes in the options }
    wr_bytex($00, _dhcp_opts_len)
    _dhcp_msg_len := (currptr{} - st)
    return _dhcp_msg_len

PUB WriteTLV(typ, len, val, byte_ord): ptr
' Write TLV to ptr_buff
'   typ: type
'   len:
'       1..2: values will be read (MSByte-first) directly from parameter
'       3..255: values will be read by pointer passed in ptr_val
'       other values: only the type will be written
'   val:
'       value(s) to write
'   byte_ord:
'       byte order to write multi-byte values in
'   Returns: total length of TLV (includes: type, length, and all values)
    { track length of DHCP options; it'll be needed later for padding
        the end of the DHCP message }
    _dhcp_opts_len += wr_byte(typ)
    case len
        1..2:                                   ' immediate value
            _dhcp_opts_len += wr_byte(len)
            _dhcp_opts_len += wrblk_msbf(@val, len)
        3..255:                                 ' value pointed to
            _dhcp_opts_len += wr_byte(len)
            if (byte_ord == LSBF)
                _dhcp_opts_len += wrblk_lsbf(val, len)
            else
                _dhcp_opts_len += wrblk_msbf(val, len)
        other:                                  ' type only
    return _dhcp_opts_len

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

