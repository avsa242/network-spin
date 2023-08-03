{
    --------------------------------------------
    Filename: protocol.net.bootp.spin
    Author: Jesse Burt
    Description: Boot Protocol/Dynamic Host Configuration Protocol
    Started Feb 28, 2022
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
    BOOTP_MSG_SZ        = 236
    BOOT_FN_LEN         = 128

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

    DHCP_MAGIC_COOKIE   = $63_82_53_63
    DHCP_MAGIC_COOKIE3  = ((DHCP_MAGIC_COOKIE >> 24) & $FF)
    DHCP_MAGIC_COOKIE2  = ((DHCP_MAGIC_COOKIE >> 16) & $FF)
    DHCP_MAGIC_COOKIE1  = ((DHCP_MAGIC_COOKIE >> 8) & $FF)
    DHCP_MAGIC_COOKIE0  = (DHCP_MAGIC_COOKIE & $FF)

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

OBJ

    { virtual instance of network device object }
    net=    NETDEV_OBJ

VAR

    { obj pointer }
    long dev

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

pub init(optr)
' Set pointer to network device object
    dev := optr

PUB bootp_bcast_flag{}: f
' Get BOOTP broadcast flag
    f := (((_bootp_data[BOOTPM_FLAGS] >> BCAST_BIT) & 1) == 1)

PUB bootp_boot_fn{}: ptr_str
' Get boot filename
    ptr_str := @_bootp_data[BOOTPM_FILENM]

PUB bootp_client_ip{}: addr | i
' Get client IP address
    repeat i from 0 to 3
        addr.byte[i] := _bootp_data[BOOTPM_CIP+i]

PUB bootp_client_mac{}: ptr_addr
' Get client MAC address
    ptr_addr := @_bootp_data[BOOTPM_CLI_MAC]

PUB bootp_cli_hdw_addr_pad_len{}: len
' Get length of client hardware address padding
    return HDWADDRLEN_MAX-MACADDR_LEN   ' XXX make constant

PUB bootp_gwy_ip{}: addr | i
' Get relay agent IP address
    repeat i from 0 to 3
        addr.byte[i] := _bootp_data[BOOTPM_GIP+i]

PUB bootp_hdw_addr_len{}: len
' Get hardware address length
    len := _bootp_data[BOOTPM_HW_ADDR_LEN]

PUB bootp_hdw_type{}: t
' Get hardware type
    t := _bootp_data[BOOTPM_CLI_HW_T]

PUB bootp_hops{}: h
' Get number of hops
    h := _bootp_data[BOOTPM_HOP]

PUB bootp_inc_xid{}
' Increment xid/transaction ID by 1
    _bootp_data[BOOTPM_XID+3]++

PUB bootp_lease_elapsed{}: s
' Get time elapsed since start of attempt to acquire or renew lease
    s.byte[0] := _bootp_data[BOOTPM_LSTM_EL_M]
    s.byte[1] := _bootp_data[BOOTPM_LSTM_EL_L]

PUB bootp_opcode{}: c
' Get BOOTP message opcode
    c := _bootp_data[BOOTPM_OP]

PUB bootp_rsvd_flags{}: flags
' Get BOOTP reserved flags
    flags.byte[0] := _bootp_data[BOOTPM_FLAGS_L]
    flags.byte[1] := _bootp_data[BOOTPM_FLAGS_M]

PUB bootp_srv_hostname{}: ptr_str
' Get server hostname
    ptr_str := @_bootp_data[BOOTPM_HOSTNM]

PUB bootp_srv_ip{}: addr | i
' Get next server IP address
    repeat i from 0 to 3
        addr.byte[i] := _bootp_data[BOOTPM_SIP+i]

PUB bootp_xid{}: id
' Get transaction ID
    bytemove(@id, @_bootp_data[BOOTPM_XID], 4)

PUB bootp_your_ip{}: addr | i
' Get your IP address
    repeat i from 0 to 3
        addr.byte[i] := _bootp_data[BOOTPM_YIP+i]

PUB dhcp_bcast_ip{}: addr
' Get broadcast IP address
    return _bcast_ip

PUB dhcp_dns_ip{}: addr
' Get domain name server IP address
    return _dns_ip

PUB dhcp_new(msg_t, ptr_params, nr_params)
' Write a DHCP message to the buffer
'   msg_t: DHCP message type (DHCPDISCOVER, DHCPREQUEST)
'   ptr_params: pointer to buffer containing DHCP parameters to be requested from the server
'   nr_params: number of parameters at ptr_params
    _bootp_data[BOOTPM_OP] := BOOT_REQ
    _bootp_data[BOOTPM_FLAGS] := (1 << BCAST_BIT)
    bytemove(@_bootp_data[BOOTPM_CLI_MAC], @_mac_local, MACADDR_LEN)
    bytemove(@_dhcp_param_req, ptr_params, (nr_params <# 5))
    _dhcp_max_msg_len := MTU_MAX
    _dhcp_msg_t := msg_t
    wr_dhcp_msg{}

PUB dhcp_ip_lease_time{}: s
' Get lease time of IP address, in seconds
    return _dhcp_lease_tm

PUB dhcp_ip_rebind_time{}: s
' Get rebinding time of IP address, in seconds
    return _dhcp_rebind_tm

PUB dhcp_ip_renew_time{}: s
' Get renewal time of IP address, in seconds
    return _dhcp_renewal_tm

PUB dhcp_max_msg_len{}: len
' Get maximum accepted DHCP message length
    return _dhcp_max_msg_len

PUB dhcp_msg_len{}: ptr
' Get length of assembled DHCP message
    return _dhcp_msg_len

PUB dhcp_msg_type{}: t
' Get type of DHCP message
    return _dhcp_msg_t

PUB dhcp_router_ip{}: addr
' Get router IP address
    return _router_ip

PUB dhcp_srv_ip{}: addr
' Get DHCP server IP address
    bytemove(@addr, @_dhcp_srv_ip, IPV4ADDR_LEN)

PUB dhcp_subnet_mask{}: mask
' Get subnet mask
    return _subnet_mask

PUB bootp_set_bcast_flag(flag)
' Set BOOTP broadcast flag
'   Valid values:
'       TRUE (any non-zero value), FALSE (0)
    _bootp_data[BOOTPM_FLAGS] := (||(flag <> 0)) << BCAST_BIT

PUB bootp_set_boot_fn(ptr_str)
' Set boot filename
    bytemove(@_bootp_data[BOOTPM_FILENM], ptr_str, strsize(ptr_str) <# BOOT_FN_LEN)

PUB bootp_set_client_ip(addr) | i
' Set client IP address
    repeat i from 0 to 3
        _bootp_data[BOOTPM_CIP+i] := addr.byte[i]

PUB bootp_set_client_mac(ptr_addr)
' Set client MAC address
    bytemove(@_bootp_data[BOOTPM_CLI_MAC], ptr_addr, MACADDR_LEN)

PUB bootp_set_cli_hdw_addr_pad_len(len) 'XXX pseudo-metadata that's calculated
' Set length of client hardware address padding
'    _client_hdw_addr_pad := len

PUB bootp_set_gwy_ip(addr) | i
' Set relay agent IP address
    repeat i from 0 to 3
        _bootp_data[BOOTPM_GIP+i] := addr.byte[i]

PUB bootp_set_hdw_addr_len(len)
' Set hardware address length
    _bootp_data[BOOTPM_HW_ADDR_LEN] := len

PUB bootp_set_hdw_type(t)
' Set hardware type
    _bootp_data[BOOTPM_CLI_HW_T] := t

PUB bootp_set_hops(h)
' Set number of hops
    _bootp_data[BOOTPM_HOP] := h

PUB bootp_set_lease_elapsed(s)
' Set time elapsed since start of attempt to acquire or renew lease
    _bootp_data[BOOTPM_LSTM_EL_M] := s.byte[0]
    _bootp_data[BOOTPM_LSTM_EL_L] := s.byte[1]

PUB bootp_set_opcode(c)
' Set BOOTP message opcode
    _bootp_data[BOOTPM_OP] := c

PUB bootp_set_rsvd_flags(flags)
' Set BOOTP reserved flags
    _bootp_data[BOOTPM_FLAGS_M] |= flags.byte[1] & $7f
    _bootp_data[BOOTPM_FLAGS_L] := flags.byte[0]

PUB bootp_set_srv_hostname(ptr_str)
' Set server hostname, up to 64 bytes
    bytemove(@_bootp_data[BOOTPM_HOSTNM], ptr_str, strsize(ptr_str) <# SRV_HOSTN_LEN)

PUB bootp_set_srv_ip(addr)
' Set server IP address
    bytemove(@_bootp_data + BOOTPM_GIP, @addr, IPV4ADDR_LEN)

PUB bootp_set_xid(id)
' Set transaction ID
    bytemove(@_bootp_data + BOOTPM_XID, @id, 4)

PUB bootp_set_your_ip(addr)
' Set 'your' IP address
    bytemove(@_bootp_data[BOOTPM_YIP], @addr, IPV4ADDR_LEN)

PUB dhcp_set_bcast_ip(addr)
' Set broadcast IP address
    bytemove(@_bcast_ip, @addr, IPV4ADDR_LEN)

PUB dhcp_set_dns_ip(addr)
' Set domain name server IP address
    bytemove(@_dns_ip, @addr, IPV4ADDR_LEN)

PUB dhcp_set_ip_lease_time(s)
' Set lease time for IP address, in seconds
    _dhcp_lease_tm := s

PUB dhcp_set_ip_rebind_time(s)
' Set rebinding time for IP address, in seconds
    _dhcp_rebind_tm := s

PUB dhcp_set_ip_renew_time(s)
' Set renewal time for IP address, in seconds
    _dhcp_renewal_tm := s

PUB dhcp_set_max_msg_len(len)
' Set maximum accepted DHCP message length
    _dhcp_max_msg_len := len

PUB dhcp_set_msg_type(msgtype)
' Set DHCP message type
    _dhcp_msg_t := msgtype

PUB dhcp_set_params_reqd(ptr_buff, len)
' Set list of parameters to retrieve from DHCP server
    bytemove(@_dhcp_param_req, ptr_buff, (len <# 5))

PUB dhcp_set_router_ip(addr)
' Set router IP address
    bytemove(@_router_ip, @addr, IPV4ADDR_LEN)

PUB dhcp_set_srv_ip(addr)
' Set DHCP server IP address
    bytemove(@_dhcp_srv_ip, @addr, IPV4ADDR_LEN)

PUB dhcp_set_subnet_mask(mask)
' Set subnet mask
    bytemove(@_subnet_mask, @mask, IPV4ADDR_LEN)

PUB reset_bootp{}
' Reset all values to defaults
    bytefill(@_bootp_data, 0, BOOTP_MSG_SZ)
    _bootp_data[BOOTPM_CLI_HW_T] := ETHERNET
    _bootp_data[BOOTPM_HW_ADDR_LEN] := MACADDR_LEN
    _bootp_data[BOOTPM_LSTM_EL_M] := $00
    _bootp_data[BOOTPM_LSTM_EL_L] := $01

PUB rd_bootp_msg{}: ptr
' Read BOOTP message, as well as DHCP message, if it exists
    net[dev].rdblk_lsbf(@_bootp_data, BOOTP_MSG_SZ)

    { does the message contain a DHCP message? }
    if ( net[dev].rdlong_msbf{} == DHCP_MAGIC_COOKIE )
        rd_dhcp_msg{}
    else
        net[dev].fifo_set_wr_ptr(net[dev].fifo_wr_ptr{}-4)        ' rewind if it's not DHCP
    return net[dev].fifo_wr_ptr{}

PUB rd_dhcp_msg{}: ptr | t
' Read DHCP message
    { read through all TLVs }
    repeat
        t := net[dev].rd_byte{}
        case t
            MSG_TYPE:
                net[dev].rd_byte{}                       ' skip over the length byte
                _dhcp_msg_t := net[dev].rd_byte{}
            DHCP_SRV_ID:
                net[dev].rd_byte{}
                net[dev].rdblk_lsbf(@_dhcp_srv_ip, IPV4ADDR_LEN)
            IP_LEASE_TM:
                net[dev].rd_byte{}
                net[dev].rdblk_msbf(@_dhcp_lease_tm, 4)
            RENEWAL_TM:
                net[dev].rd_byte{}
                net[dev].rdblk_msbf(@_dhcp_renewal_tm, 4)
            REBIND_TM:
                net[dev].rd_byte{}
                net[dev].rdblk_msbf(@_dhcp_rebind_tm, 4)
            SUBNET_MASK:
                net[dev].rd_byte{}
                net[dev].rdblk_lsbf(@_subnet_mask, IPV4ADDR_LEN)
            BCAST_ADDR:
                net[dev].rd_byte{}
                net[dev].rdblk_lsbf(@_bcast_ip, IPV4ADDR_LEN)
            ROUTER:
                net[dev].rd_byte{}
                net[dev].rdblk_lsbf(@_router_ip, IPV4ADDR_LEN)
            DNS:
                net[dev].rd_byte{}
                net[dev].rdblk_lsbf(@_dns_ip, IPV4ADDR_LEN)
            OPT_END:
                net[dev].rd_byte{}
    until (t == OPT_END)    'XXX not safeguarded against bad messages missing the OPT_END ($FF) byte
    return net[dev].fifo_wr_ptr{}

PUB wr_bootp_msg{}: ptr | st
' Write BOOTP message
'   Returns: number of bytes written to buffer
    st := net[dev].fifo_wr_ptr{}
    net[dev].wrblk_lsbf(@_bootp_data, BOOTP_MSG_SZ)
    return net[dev].fifo_wr_ptr{}-st

CON

    LSBF    = 0
    MSBF    = 1

PUB wr_dhcp_msg{}: ptr | st
' Write DHCP message, preceded by BOOTP message
'   NOTE: Ensure DHCP_set_MsgType() is set, prior to calling this method
    st := net[dev].fifo_wr_ptr{}

    { start with BOOTP message }
    wr_bootp_msg{}

    { then the DHCP 'magic cookie' value to identify it as a DHCP message }
    net[dev].wrlong_msbf(DHCP_MAGIC_COOKIE)

    { finally, the DHCP 'options' }
    _dhcp_opts_len := 0
    write_tlv(MSG_TYPE, 1, _dhcp_msg_t, LSBF)
    write_tlv(PARAM_REQLST, 5, @_dhcp_param_req, LSBF)
'    write_tlv(CLIENT_ID, 7, @_client_hw_t, LSBF)       ' HW type, then HW addr
    net[dev].wr_byte(CLIENT_ID)
    net[dev].wr_byte(7)
    net[dev].wr_byte(_bootp_data[BOOTPM_CLI_HW_T])
    net[dev].wrblk_lsbf(@_bootp_data[BOOTPM_CLI_MAC], MACADDR_LEN)
    if ( _dhcp_msg_t == DHCPDISCOVER )
        write_tlv(MAX_DHCP_MSGSZ, 2, _dhcp_max_msg_len, MSBF)
    elseif (_dhcp_msg_t == DHCPREQUEST)
        write_tlv(REQD_IPADDR, 4, @_bootp_data[BOOTPM_YIP], LSBF)
        write_tlv(DHCP_SRV_ID, 4, @_dhcp_srv_ip, LSBF)
    write_tlv(IP_LEASE_TM, 4, @_dhcp_lease_tm, MSBF)
    write_tlv(OPT_END, 0, 0, LSBF)

    { pad the end of the message equal to the number of bytes in the options }
    net[dev].wr_byte_x($00, _dhcp_opts_len)
    _dhcp_msg_len := (net[dev].fifo_wr_ptr{} - st)
    return _dhcp_msg_len

PUB write_tlv(typ, len, val, byte_ord): ptr
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
    _dhcp_opts_len += net[dev].wr_byte(typ)
    case len
        1..2:                                   ' immediate value
            _dhcp_opts_len += net[dev].wr_byte(len)
            _dhcp_opts_len += net[dev].wrblk_msbf(@val, len)
        3..255:                                 ' value pointed to
            _dhcp_opts_len += net[dev].wr_byte(len)
            if ( byte_ord == LSBF )
                _dhcp_opts_len += net[dev].wrblk_lsbf(val, len)
            else
                _dhcp_opts_len += net[dev].wrblk_msbf(val, len)
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

