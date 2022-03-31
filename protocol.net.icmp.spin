{
    --------------------------------------------
    Filename: protocol.net.icmp.spin
    Author: Jesse Burt
    Description: Internet Control Message Protocol
    Started Mar 31, 2022
    Updated Mar 31, 2022
    Copyright 2022
    See end of file for terms of use.
    --------------------------------------------
}
#ifndef NET_COMMON
#include "net-common.spinh"
#endif

'#include "services.spinh"

CON

{ Limits }
    ICMP_MSG_LEN    = 8

{ offsets within header }
    IDX_ICMP_T      = 0
    IDX_ICMP_CODE   = 1
    IDX_ICMP_CKSUM  = 2

{ error message types }
    DEST_UNREACH    = 3
    SRC_QUENCH      = 4
    REDIRECT        = 5
    TM_EXCEEDED     = 11
    PARAM_PROB      = 12

{ info message types }
    ECHO_REPL       = 0
    ECHO_REQ        = 8
    ROUTER_ADV      = 9
    ROUTER_SOL      = 10
    TMSTAMP_REQ     = 13
    TMSTAMP_REPL    = 14
    INFO_REQ        = 15    ' obsolete
    INFO_REPL       = 16    ' obsolete
    ADDRMASK_REQ    = 17
    ADDRMASK_REPL   = 18
    TRACERT         = 30

{ message codes/subtypes }
    NET_UNREACH     = 0                         ' unreachable (net)
    HOST_UNREACH    = 1                         ' unreachable (host)
    PROTO_UNREACH   = 2                         ' unreachable (protocol)
    PORT_UNREACH    = 3                         ' unreachable (port)
    FRAG_NEEDED     = 4                         ' frag needed but DF set
    SRC_RT_FAILED   = 5                         ' source route failed
    DEST_NET_UNK    = 6                         ' not used; use NET_UNREACH
    DEST_HOST_UNK   = 7                         ' dest. unknown (host)
    SRC_HOST_ISOL   = 8                         ' obsolete
    NOPERM_NET      = 9                         ' comm. prohibited (net)
    NOPERM_HOST     = 10                        ' comm. prohibited (host)
    NET_SVC_UNREACH = 11                        ' dest. net unreachable (type of service)
    HOST_SVC_UNREACH= 12                        ' dest. host unreachable (type of service)
    FILTERED        = 13                        ' comm. prohibited
    NOPERM_PREC     = 14                        ' host precedence violation
    PREC_CUTOFF     = 15                        ' precedence cutoff in effect


VAR

    word _icmp_cksum
    byte _icmp_type, _icmp_code

PUB ICMP_SetChksum(ck)
' Set checksum (optional; set to 0 to ignore)
    _icmp_cksum := ck

PUB ICMP_SetCode(icmp_c)
' Set ICMP subtype
    _icmp_code := icmp_c

PUB ICMP_SetMsgType(icmp_t)
' Set ICMP message type
    _icmp_type := icmp_t

PUB ICMP_Chksum{}: ck
' Get checksum
    return _icmp_cksum

PUB ICMP_Code{}: icmp_c
' Get ICMP subtype/code
    return _icmp_code

PUB ICMP_MsgType{}: icmp_t
' Get ICMP message type
    return _icmp_type

PUB Rd_ICMP_Msg{}: ptr
' Read/disassemble ICMP message
'   Returns: length of read header, in bytes
    _icmp_type := rd_byte{}
    _icmp_code := rd_byte{}
    _cksum := rdword_msbf{}
    rdlong_lsbf{}                               ' discard unused bytes
    return currptr{}

PUB Wr_ICMP_Msg{}: ptr
' Write/assemble ICMP message
'   Returns: length of assembled header, in bytes
    wr_byte(_icmp_type)
    wr_byte(_icmp_code)
    wrword_msbf(_cksum)
    wr_bytex($00, 4)                            ' unused
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

