{
    --------------------------------------------
    Filename: protocol.net.bootp.spin
    Author: Jesse Burt
    Description: Boot Protocol/Dynamic Host Configuration Protocol
    Started Feb 28, 2022
    Updated Mar 19, 2022
    Copyright 2022
    See end of file for terms of use.
    --------------------------------------------
}
#include "net-common.spinh"

CON

    DHCP_MAGIC_COOKIE   = $63_82_53_63
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
    word _ptr
    word _dhcp_max_msg_len

    byte _bootp_opcode
    byte _hdw_addr_len
    byte _hops
    byte _client_hw_t
    byte _client_mac[MACADDR_LEN]
    byte _client_hdw_addr_pad
    byte _srv_hostname[SRV_HOSTN_LEN+1]         ' str + 0
    byte _boot_fname[BOOT_FN_LEN+1]             ' str + 0

    byte _dhcp_optsz
    byte _dhcp_param_req[5]
    byte _dhcp_msg_t

OBJ

    time    : "time"

PUB GetBroadcastIP{}: addr
' Get broadcast IP address
    return _bcast_ip

PUB GetBootFName{}: ptr_str
' Get boot filename
    bytemove(ptr_str, @_boot_fname, strsize(@_boot_fname))

PUB GetBroadcastFlag{}: f
' Get BOOTP broadcast flag
    return (((_flags >> FLAG_B) & 1) == 1)

PUB GetCliHdwAddrPadLen{}: len
' Get length of client hardware address padding
    return _client_hdw_addr_pad

PUB GetClientIP{}: addr
' Get client IP address
    bytemove(@addr, @_client_ip, IPV4ADDR_LEN)

PUB GetClientMAC{}: ptr_addr
' Get client MAC address
    bytemove(ptr_addr, @_client_mac, MACADDR_LEN)

PUB GetDHCPMsgType{}: t
' Get type of DHCP message
    return _dhcp_msg_t

PUB GetDHCPSrvIP{}: addr
' Get DHCP server IP address
    bytemove(@addr, @_dhcp_srv_ip, IPV4ADDR_LEN)

PUB GetDNSIP{}: addr
' Get domain name server IP address
    return _dns_ip

PUB GetGatewayIP{}: addr
' Get relay agent IP address
    return _gwy_ip

PUB GetHdwAddrLen{}: len
' Set hardware address length
    return _hdw_addr_len

PUB GetHdwType{}: t
' Get hardware type
    return _client_hw_t

PUB GetHops{}: h
' Get number of hops
    return _hops

PUB GetIPLeaseTime{}: s
' Get lease time of IP address, in seconds
    return _dhcp_lease_tm

PUB GetIPRebindTime{}: s
' Get rebinding time of IP address, in seconds
    return _dhcp_rebind_tm

PUB GetIPRenewalTime{}: s
' Get renewal time of IP address, in seconds
    return _dhcp_renewal_tm

PUB GetLeaseElapsed{}: s
' Get time elapsed since start of attempt to acquire or renew lease
    return _lstime_elapsed

PUB GetOpCode{}: c
' Get BOOTP message opcode
    return _bootp_opcode

PUB GetRouterIP{}: addr
' Get router IP address
    return _router_ip

PUB GetRsvdFlags{}: flags
' Get BOOTP reserved flags
    return _flags & $7fff

PUB GetServerHostname{}: ptr_str
' Set server hostname
    bytemove(ptr_str, @_srv_hostname, strsize(@_srv_hostname))

PUB GetServerIP{}: addr
' Get next server IP address
    return _srv_ip

PUB GetSubnetMask{}: mask
' Get subnet mask
    return _subnet_mask

PUB GetTransID{}: id
' Get transaction ID
    return _trans_id

PUB GetYourIP{}: addr | i
' Get your IP address
    return _your_ip

PUB BootFName(ptr_str)
' Set boot filename
    bytemove(@_boot_fname, ptr_str, strsize(ptr_str))

PUB BroadcastFlag(flag)
' Set BOOTP broadcast flag
    _flags := (||(flag <> 0)) << FLAG_B

PUB ClientIP(addr)
' Set client IP address
    bytemove(@_client_ip, @addr, IPV4ADDR_LEN)

PUB ClientMAC(ptr_addr)
' Set client MAC address
    bytemove(@_client_mac, ptr_addr, MACADDR_LEN)

PUB DHCPMaxMsgLen(len)
' Set maximum accepted DHCP message length
    _dhcp_max_msg_len := len

PUB DHCPMsgLen{}: ptr
' Get length of assembled DHCP message
    return _ptr

PUB DHCPMsgType(type)
' Set DHCP message type
    _dhcp_msg_t := type

PUB GatewayIP(addr)
' Set relay agent IP address
    _gwy_ip := addr

PUB HdwAddrLen(len)
' Set hardware address length
    _hdw_addr_len := len

PUB HdwType(t)
' Set hardware type
    _client_hw_t := t

PUB Hops(h)
' Set number of hops
    _hops := h

PUB IPLeaseTime(s)
' Set lease time for IP address, in seconds
    _dhcp_lease_tm := s

PUB IPRebindTime(s)
' Set rebinding time for IP address, in seconds
    _dhcp_rebind_tm := s

PUB IPRenewalTime(s)
' Set renewal time for IP address, in seconds
    _dhcp_renewal_tm := s

PUB LeaseStartElapsed(s)
' Set time elapsed since start of attempt to acquire or renew lease
    _lstime_elapsed := s

PUB OpCode(c)
' Set BOOTP message opcode
    _bootp_opcode := c

PUB ParamsReqd(ptr_buff, len)
' Set list of parameters to retrieve from DHCP server
    bytemove(@_dhcp_param_req, ptr_buff, (len <# 5))

PUB Rd_BOOTP_Msg(ptr_buff): ptr | i
' Read BOOTP message, as well as DHCP message, if it exists
    _ptr := ptr := 0
    _bootp_opcode := byte[ptr_buff][_ptr++]
    _client_hw_t := byte[ptr_buff][_ptr++]
    _hdw_addr_len := byte[ptr_buff][_ptr++]
    _hops := byte[ptr_buff][_ptr++]
    repeat i from 3 to 0
        _trans_id.byte[i] := byte[ptr_buff][_ptr++]
    _lstime_elapsed.byte[1] := byte[ptr_buff][_ptr++]
    _lstime_elapsed.byte[0] := byte[ptr_buff][_ptr++]
    _flags.byte[1] := byte[ptr_buff][_ptr++]
    _flags.byte[0] := byte[ptr_buff][_ptr++]
    bytemove(@_client_ip, ptr_buff+_ptr, IPV4ADDR_LEN)
    _ptr += IPV4ADDR_LEN
    bytemove(@_your_ip, ptr_buff+_ptr, IPV4ADDR_LEN)
    _ptr += IPV4ADDR_LEN
    bytemove(@_srv_ip, ptr_buff+_ptr, IPV4ADDR_LEN)
    _ptr += IPV4ADDR_LEN
    bytemove(@_gwy_ip, ptr_buff+_ptr, IPV4ADDR_LEN)
    _ptr += IPV4ADDR_LEN
    bytemove(@_client_mac, ptr_buff+_ptr, MACADDR_LEN)
    _ptr += MACADDR_LEN

    repeat (HDWADDRLEN_MAX-MACADDR_LEN)
        _ptr++                                  ' skip over hdw addr padding
    _client_hdw_addr_pad := (HDWADDRLEN_MAX-MACADDR_LEN)

    bytemove(@_srv_hostname, ptr_buff+_ptr, SRV_HOSTN_LEN)
    _ptr += SRV_HOSTN_LEN
    bytemove(@_boot_fname, ptr_buff+_ptr, BOOT_FN_LEN)
    _ptr += BOOT_FN_LEN

    { DHCP message? Check it without advancing the pointer, in case it's not }
    if (byte[ptr_buff][_ptr] == ((DHCP_MAGIC_COOKIE >> 24) & $ff)) and {
}   (byte[ptr_buff][_ptr+1] == ((DHCP_MAGIC_COOKIE >> 16) & $ff)) and {
}   (byte[ptr_buff][_ptr+2] == ((DHCP_MAGIC_COOKIE >> 8) & $ff)) and {
}   (byte[ptr_buff][_ptr+3] == (DHCP_MAGIC_COOKIE & $ff))
        _ptr += 4
        rd_DHCP_msg(ptr_buff)

    return _ptr

PUB Rd_DHCP_Msg(ptr_buff): ptr | i, t, v

    { read through all TLVs }
    repeat
        t := byte[ptr_buff][_ptr++]
        case t
            MSG_TYPE:
                _ptr++                          ' skip over the length byte
                _dhcp_msg_t := byte[ptr_buff][_ptr++]
            DHCP_SRV_ID:
                _ptr++
                bytemove(@_dhcp_srv_ip, ptr_buff+_ptr, IPV4ADDR_LEN)
                _ptr += IPV4ADDR_LEN
            IP_LEASE_TM:
                _ptr++
                repeat i from 3 to 0
                    _dhcp_lease_tm.byte[i] := byte[ptr_buff][_ptr++]
            RENEWAL_TM:
                _ptr++
                repeat i from 3 to 0
                    _dhcp_renewal_tm.byte[i] := byte[ptr_buff][_ptr++]
            REBIND_TM:
                _ptr++
                repeat i from 3 to 0
                    _dhcp_rebind_tm.byte[i] := byte[ptr_buff][_ptr++]
            SUBNET_MASK:
                _ptr++
                bytemove(@_subnet_mask, ptr_buff+_ptr, IPV4ADDR_LEN)
                _ptr += IPV4ADDR_LEN
            BCAST_ADDR:
                _ptr++
                bytemove(@_bcast_ip, ptr_buff+_ptr, IPV4ADDR_LEN)
                _ptr += IPV4ADDR_LEN
            ROUTER:
                _ptr++
                bytemove(@_router_ip, ptr_buff+_ptr, IPV4ADDR_LEN)
                _ptr += IPV4ADDR_LEN
            DNS:
                _ptr++
                bytemove(@_dns_ip, ptr_buff+_ptr, IPV4ADDR_LEN)
                _ptr += IPV4ADDR_LEN
            OPT_END:
                _ptr++
    until (t == OPT_END)    'XXX not safeguarded against bad messages missing the OPT_END ($FF) byte
    return _ptr

PUB ServerIP(addr)
' Set server IP address
    bytemove(@_srv_ip, @addr, IPV4ADDR_LEN)

PUB Wr_BOOTP_Msg(ptr_buff): ptr | i
' Write BOOTP message
'   Returns: number of bytes written to buffer
    byte[ptr_buff][_ptr++] := _bootp_opcode
    byte[ptr_buff][_ptr++] := _client_hw_t
    byte[ptr_buff][_ptr++] := _hdw_addr_len
    byte[ptr_buff][_ptr++] := _hops
    repeat i from 3 to 0
        byte[ptr_buff][_ptr++] := _trans_id.byte[i]
    byte[ptr_buff][_ptr++] := _lstime_elapsed.byte[1]
    byte[ptr_buff][_ptr++] := _lstime_elapsed.byte[0]
    byte[ptr_buff][_ptr++] := _flags.byte[1]
    byte[ptr_buff][_ptr++] := _flags.byte[0]
    bytemove(ptr_buff+_ptr, @_client_ip, IPV4ADDR_LEN)
    _ptr += IPV4ADDR_LEN
    bytemove(ptr_buff+_ptr, @_your_ip, IPV4ADDR_LEN)
    _ptr += IPV4ADDR_LEN
    bytemove(ptr_buff+_ptr, @_srv_ip, IPV4ADDR_LEN)
    _ptr += IPV4ADDR_LEN
    bytemove(ptr_buff+_ptr, @_gwy_ip, IPV4ADDR_LEN)
    _ptr += IPV4ADDR_LEN
    bytemove(ptr_buff+_ptr, @_client_mac, MACADDR_LEN)
    _ptr += MACADDR_LEN

    repeat (HDWADDRLEN_MAX-MACADDR_LEN)
        byte[ptr_buff][_ptr++] := $00
    bytemove(ptr_buff+_ptr, @_srv_hostname, SRV_HOSTN_LEN)
    _ptr += SRV_HOSTN_LEN
    bytemove(ptr_buff+_ptr, @_boot_fname, BOOT_FN_LEN)
    _ptr += BOOT_FN_LEN
    return _ptr

PUB Wr_DHCP_Msg(ptr_buff, msg_t): ptr
' Write DHCP message
'   Valid values:
'       msg_t: DHCPDISCOVER ($01), DHCPREQUEST ($03)

    { start with BOOTP message }
    wr_bootp_msg(ptr_buff)

    { then the DHCP 'magic cookie' value to identify it as a DHCP message }
    byte[ptr_buff][_ptr++] := (DHCP_MAGIC_COOKIE >> 24) & $ff   ' XXX separate CON into 4 octets
    byte[ptr_buff][_ptr++] := (DHCP_MAGIC_COOKIE >> 16) & $ff   ' to avoid runtime shift & mask
    byte[ptr_buff][_ptr++] := (DHCP_MAGIC_COOKIE >> 8) & $ff
    byte[ptr_buff][_ptr++] := DHCP_MAGIC_COOKIE & $ff

    { finally, the DHCP 'options' }
    _dhcp_optsz := 0
    _ptr += writetlv(ptr_buff+_ptr, MSG_TYPE, 1, msg_t)
    _ptr += writetlv(ptr_buff+_ptr, PARAM_REQLST, 5, @_dhcp_param_req)
    _ptr += writetlv(ptr_buff+_ptr, CLIENT_ID, 7, @_client_hw_t)    ' HW type, then HW addr
    if (msg_t == DHCPDISCOVER)
        _ptr += writetlv(ptr_buff+_ptr, MAX_DHCP_MSGSZ, 2, _dhcp_max_msg_len)
    if (msg_t == DHCPREQUEST)
        _ptr += writetlv(ptr_buff+_ptr, REQD_IPADDR, 4, @_your_ip)
        _ptr += writetlv(ptr_buff+_ptr, DHCP_SRV_ID, 4, @_dhcp_srv_ip)
    _ptr += writetlv(ptr_buff+_ptr, IP_LEASE_TM, 4, @_dhcp_lease_tm)
    _ptr += writetlv(ptr_buff+_ptr, OPT_END, 0, 0)

    { pad the end of the message equal to the number of bytes in the options }
    repeat _dhcp_optsz
        byte[ptr_buff][_ptr++] := $00
    return _ptr

PUB ResetPtr{}  ' XXX tentative
' Reset message pointer
    _ptr := 0

PUB ServerHostname(ptr_str)
' Set server hostname
    bytemove(@_srv_hostname, ptr_str, strsize(ptr_str) <# SRV_HOSTN_LEN)

PUB TransID(id)
' Set transaction ID
    _trans_id := id

PUB WriteTLV(ptr_buff, type, len, val): ptr | i 'XXX rewrite using underlying memory-agnostic 'writer' methods
' Write TLV to ptr_buff
'   len:
'       1..4: values will be read (MSByte-first) directly from parameter
'       5..255: values will be read by pointer passed in ptr_val
'       other values: only the type will be written
'   Returns: total length of TLV (includes: type, length, and all values)
    ptr := 0
    byte[ptr_buff][ptr++] := type
    case len
        1..2:                                   ' immediate value
            byte[ptr_buff][ptr++] := len
            repeat i from len-1 to 0
                byte[ptr_buff][ptr++] := val.byte[i]
        3..255:                                 ' value pointed to
            byte[ptr_buff][ptr++] := len
            if (type == REQD_IPADDR or type == DHCP_SRV_ID or type == CLIENT_ID) 'XXX temp hack - add byte order param?
                repeat i from 0 to len-1
                    byte[ptr_buff][ptr++] := byte[val][i]
            else
                repeat i from len-1 to 0
                    byte[ptr_buff][ptr++] := byte[val][i]
        other:                                  ' type only

    _dhcp_optsz += ptr

PUB YourIP(addr)
' Set 'your' IP address
    bytemove(@_your_ip, @addr, IPV4ADDR_LEN)

