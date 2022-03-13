{
    --------------------------------------------
    Filename: protocol.net.lldp.spin
    Author: Jesse Burt
    Description: Link-Layer Discovery Protocol
        data unit, TLV parsing and building object
    Started Feb 27, 2022
    Updated Feb 27, 2022
    Copyright 2022
    See end of file for terms of use.
    --------------------------------------------
}

CON

{ Limits }
    MACADDR_LEN             = 6                 ' xx:xx:xx:xx:xx:xx
    ORGID_LEN               = MACADDR_LEN/2     ' top 3 octets of MAC address
    IPV4ADDR_LEN            = 4                 ' ddd.ddd.ddd.ddd
    STRLEN_MAX              = 256+1             ' string plus NUL terminator

{ TLV types }
    TLV_CHASSIS             = 1
    TLV_PORT                = 2
    TLV_TTL                 = 3
    TLV_PORTDESC            = 4
    TLV_SYSNAME             = 5
    TLV_SYSDESC             = 6
    TLV_SYSCAPS             = 7
    TLV_MGMT_ADDR           = 8
    TLV_ORG_SPEC            = 127

{ subtype lengths }
    CHASS_SUBT_LEN          = 7                 ' subtype plus data
    PORT_SUBT_LEN           = 7
    TTL_SUBT_LEN            = 3
    SYSNAME_SUBT_LEN        = STRLEN_MAX        ' max
    SYSDESC_SUBT_LEN        = STRLEN_MAX        ' max
    SYSCAPS_SUBT_LEN        = 4
    MGMTADDR_SUBT_LEN       = 12
    PORTDESC_SUBT_LEN       = STRLEN_MAX        ' max

{ TLV subtypes }
    CHASS_SUBT_MACADDR      = 4
    PORT_SUBT_MACADDR       = 3
    ADDR_SUBT_IPV4          = 1
    IFACE_SUBT_IDX          = 2

{ Capabilities }
    STATION_ONLY            = (1 << 7)
    DOCSIS_CBLDEV           = (1 << 6)
    TELEPH                  = (1 << 5)
    ROUTER                  = (1 << 4)
    WLAN_AP                 = (1 << 3)
    BRIDGE                  = (1 << 2)
    REPEATER                = (1 << 1)
    OTHERCAP                = (1 << 0)

{ Organization-specific }
    { IEEE 802.3 }
    LINK_AGG_SUBT_LEN       = 9
    MACPHY_CFGST_SUBT_LEN   = 9

VAR

{ chassis subtype }
    byte _chass_subt                            ' only MAC addresses actually supported
    byte _chass_id[MACADDR_LEN]                 ' MSB to LSB

{ port subtype }
    byte _port_subt                             ' ditto
    byte _port_id[MACADDR_LEN]
    byte _port_desc[STRLEN_MAX]                 ' string plus NUL terminator

{ time to live }
    word _ttl                                   ' only 16b len supported

{ sys name, description }
    byte _sys_name[STRLEN_MAX]                  ' string plus NUL terminator
    byte _sys_desc[STRLEN_MAX]

{ capabilities }
    word _caps, _caps_en                        ' capabilities, caps. enabled

{ management address }
    byte _mgmt_addr_strlen, _mgmt_addr_subt     ' only IPv4 addresses actually supported
    byte _mgmt_addr[IPV4ADDR_LEN]
    byte _mgmt_if_subt
    long _mgmt_if_num
    byte _mgmt_oid_strlen

{ organization-specific }
    byte _org_id[ORGID_LEN]

OBJ

    str : "string"

PUB Capabilities{}: caps
' Get available capabilities
'   Returns: word
    return _caps

PUB CapsEnabled{}: caps
' Get enabled capabilities
'   Returns: word
    return _caps_en

PUB ChassisID{}: ptr_id
' Get chassis ID
'   Returns: pointer to 6-byte MAC address
    return @_chass_id

PUB ChassisSubt{}: subt
' Get chassis subtype
'   Returns: byte
    return _chass_subt

PUB MgmtAddr{}: addr
' Get management address
'   Returns: pointer to 4-byte IPv4 address
    bytemove(@addr, @_mgmt_addr, IPV4ADDR_LEN)

PUB MgmtAddrStrLen{}: len
' Get management address string length
'   Returns: byte
    return _mgmt_addr_strlen

PUB MgmtAddrSubt{}: subt
' Get management address subtype
'   Returns: byte
    return _mgmt_addr_subt

PUB MgmtIfaceNum{}: num
' Get management interface number
'   Returns: long
    return _mgmt_if_num

PUB MgmtIfaceSubt{}: subt
' Get management interface subtype
'   Returns: byte
    return _mgmt_if_subt

PUB MgmtOIDStrLen{}: len
' Get management OID string length
'   Returns: byte
    return _mgmt_oid_strlen

PUB OrgID{}: id
' Get organization ID
'   Returns: pointer to 3-byte MAC address
    bytemove(@id, @_org_id, ORGID_LEN)

PUB PortDesc{}: ptr_str
' Get port description
'   Returns: pointer to string
    return @_port_desc

PUB PortID{}: ptr_id
' Get port ID
'   Returns: pointer to 6-byte MAC address
    return @_port_id

PUB PortSubt{}: subt
' Get port subtype
'   Returns: byte
    return _port_subt

PUB SystemDesc{}: ptr_desc
' Get system description
'   Returns: pointer to string
    return @_sys_desc

PUB SystemName{}: ptr_str
' Get system name
'   Returns: pointer to string
    return @_sys_name

PUB TimeToLive{}: tm
' Get time-to-live
'   Returns: word
    return _ttl

PUB SetCapabilities(caps)
' Set available capabilites bitfield
'   Valid values:
'       Bits 7..0:  XXX bits 15..8 TBD
'       7: Station only
'       6: DOCSIS cable device
'       5: Telephone
'       4: Router
'       3: WLAN access point
'       2: Bridge
'       1: Repeater
'       0: Other
    _caps := caps

PUB SetEnabledCaps(caps)
' Set enabled capabilites bitfield
'   Valid values:
'       Bits 7..0:  XXX bits 15..8 TBD
'       7: Station only
'       6: DOCSIS cable device
'       5: Telephone
'       4: Router
'       3: WLAN access point
'       2: Bridge
'       1: Repeater
'       0: Other
    _caps_en := caps

PUB SetChassisID(ptr_id)
' Set chassis ID
'   Valid values: pointer to 6-byte MAC address
    bytemove(@_chass_id, ptr_id, MACADDR_LEN)

PUB SetChassisSubt(subt)
' Set chassis subtype
'   Valid values: byte
    _chass_subt := subt

PUB SetMgmtAddr(addr)
' Set management address
'   Valid values: 4-byte IPv4 address packed into long
    bytemove(@_mgmt_addr, @addr, IPV4ADDR_LEN)

PUB SetMgmtAddrStrLen(len)
' Set management address string length
'   Valid values: byte
    _mgmt_addr_strlen := len

PUB SetMgmtAddrSubt(subt)
' Set management address subtype
'   Valid values: byte
    _mgmt_addr_subt := subt

PUB SetMgmtIfaceNum(num)
' Set management interface number
'   Valid values: long
    _mgmt_if_num := num

PUB SetMgmtIfaceSubt(subt)
' Set management interface subtype
'   Valid values: byte
    _mgmt_if_subt := subt

PUB SetMgmtOIDStrLen(len)
' Set management OID string length
'   Valid values: byte
    _mgmt_oid_strlen := len

PUB SetOrgID(id)
' Set organization ID
'   Valid values: long (3 MSB's of MAC address)
    bytemove(@_org_id, @id, ORGID_LEN)

PUB SetPortDesc(ptr_str)
' Set port description
'   Valid values: pointer to string (up to STRLEN_MAX bytes will be copied)
    strcopymax(@_port_desc, ptr_str, STRLEN_MAX)

PUB SetPortID(ptr_id)
' Set port ID
'   Valid values: pointer to 6-byte MAC address
    bytemove(@_port_id, ptr_id, MACADDR_LEN)

PUB SetPortSubt(subt)
' Set port subtype
'   Valid values: byte
    _port_subt := subt

PUB SetSystemDesc(ptr_str)
' Set system description
'   Valid values: pointer to string (up to STRLEN_MAX bytes will be copied)
    strcopymax(@_sys_desc, ptr_str, STRLEN_MAX)

PUB SetSystemName(ptr_str)
' Set system name
'   Valid values: pointer to string (up to STRLEN_MAX bytes will be copied)
    strcopymax(@_sys_name, ptr_str, STRLEN_MAX)

PUB SetTimeToLive(tm)
' Set time-to-live
'   Valid values: 0..65535
    _ttl := tm

PUB ReadTLV(ptr_buff): tlv_len | tlv_t, tlv_subt, ptr, i
' Read TLV from buffer
'   Returns: length of TLV read, in bytes
    tlv_len := tlv_t := tlv_subt := ptr := i := 0

    { extract TLV type and length }
    tlv_t := ((byte[ptr_buff][ptr] >> 1) & $7f)
    tlv_len := ((byte[ptr_buff][ptr++] & 1) << 8) | byte[ptr_buff][ptr++]

    case tlv_t
        TLV_CHASSIS:
            _chass_subt := byte[ptr_buff][ptr++]
            case _chass_subt
                CHASS_SUBT_MACADDR:
                    repeat i from 5 to 0
                        _chass_id[i] := byte[ptr_buff][ptr++]
                other:  ' unsupported
        TLV_PORT:
            _port_subt := byte[ptr_buff][ptr++]
            case _port_subt
                PORT_SUBT_MACADDR:
                    repeat i from 5 to 0
                        _port_id[i] := byte[ptr_buff][ptr++]
                other:  ' unsupported
        TLV_TTL:
            _ttl := (byte[ptr_buff][ptr++] << 8) | byte[ptr_buff][ptr++]
        TLV_PORTDESC:
            repeat i from 0 to tlv_len-1
                _port_desc[i] := byte[ptr_buff][ptr++]
        TLV_SYSNAME:
            repeat i from 0 to tlv_len-1
                _sys_name[i] := byte[ptr_buff][ptr++]
        TLV_SYSDESC:
            repeat i from 0 to tlv_len-1
                _sys_desc[i] := byte[ptr_buff][ptr++]
        TLV_SYSCAPS:
            if (tlv_len == SYSCAPS_SUBT_LEN)
                _caps := (byte[ptr_buff][ptr++] << 8) | byte[ptr_buff][ptr++]
                _caps_en := (byte[ptr_buff][ptr++] << 8) | byte[ptr_buff][ptr++]
            else
        TLV_MGMT_ADDR:
            if (tlv_len == MGMTADDR_SUBT_LEN)
                _mgmt_addr_strlen := byte[ptr_buff][ptr++]
                _mgmt_addr_subt := byte[ptr_buff][ptr++]
                repeat i from 3 to 0    'MSB to LSB
                    _mgmt_addr[i] := byte[ptr_buff][ptr++]
                _mgmt_if_subt := byte[ptr_buff][ptr++]
                repeat i from 3 to 0
                    _mgmt_if_num.byte[i] := byte[ptr_buff][ptr++]
                _mgmt_oid_strlen := byte[ptr_buff][ptr++]
            else
        TLV_ORG_SPEC:
            repeat i from 2 to 0
                _org_id[i] := byte[ptr_buff][ptr++]
        other:

    return tlv_len+2                            ' tlv_subt + tlv_len

PUB WriteLLDPDU(ptr_buff): len
' Write assembled LLDP data unit

PUB WriteTLV(ptr_buff): len
' Write assembled TLV to ptr_buff

PRI StrCopyMax(ptr_dest, ptr_src, max_chars)
' Copy string from ptr_src to ptr_dest, up to max_chars
    bytemove(ptr_dest, ptr_src, (strsize(ptr_src) + 1) <# max_chars)
    return ptr_dest

