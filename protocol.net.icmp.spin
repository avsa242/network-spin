{
    --------------------------------------------
    Filename: protocol.net.icmp.spin
    Author: Jesse Burt
    Description: Internet Control Message Protocol
    Started Mar 31, 2022
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
    ICMP_MSG_SZ     = 8                         ' message length
    ICMP_ECHO_MSG_SZ= 12                        ' echo metadata (_not_ echoed data)

    { offsets within header }
    ICMP_ABS_ST     = IP_DSTIP + 4              ' add to the below for abs. position within frame

    ICMP_T          = 0
    ICMP_CD         = 1
    ICMP_CKSUM      = 2
     ICMP_CKSUM_L   = 3
    ICMP_DATA       = 50                        ' data for ECHO messages

    { ECHO: offsets within metadata }
    ICMP_IDENT_M    = 0
    ICMP_IDENT_L    = 1
    ICMP_SEQNR_M    = 2
    ICMP_SEQNR_L    = 3
    ICMP_TMSTMP_M   = 4
    ICMP_TMSTMPF_M  = 8

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

    long _icmp_tm_stamp
    word _icmp_ident, _icmp_seq_nr
    byte _icmp_msg_len

    byte _icmp_data[ICMP_MSG_SZ]
    byte _icmp_echo[ICMP_ECHO_MSG_SZ]

PUB ICMP_SetChksum(ck)
' Set checksum (optional; set to 0 to ignore)
    _icmp_data[ICMP_CKSUM] := ck.byte[0]
    _icmp_data[ICMP_CKSUM_L] := ck.byte[1]

PUB ICMP_SetCode(icmp_c)
' Set ICMP subtype
    _icmp_data[ICMP_CD] := icmp_c

PUB ICMP_SetIdent(iid)
' Set ICMP identifier
    _icmp_echo[ICMP_IDENT_M] := iid.byte[0]
    _icmp_echo[ICMP_IDENT_L] := iid.byte[1]

PUB ICMP_SetMsgType(msg_t)
' Set ICMP message type
    _icmp_data[ICMP_T] := msg_t

PUB ICMP_SetSeqNr(seq_nr)
' Set ICMP sequence number
    _icmp_echo[ICMP_SEQNR_M] := seq_nr.byte[0]
    _icmp_echo[ICMP_SEQNR_L] := seq_nr.byte[1]

PUB ICMP_SetTimeStamp(tm) | i
' Set timestamp for ICMP message
    repeat i from 0 to 3
        _icmp_echo[ICMP_TMSTMP_M+i] := tm.byte[i]

PUB ICMP_Chksum{}: ck
' Get checksum
    ck.byte[0] := _icmp_data[ICMP_CKSUM]
    ck.byte[1] := _icmp_data[ICMP_CKSUM_L]

PUB ICMP_Code{}: icmp_c
' Get ICMP subtype/code
    icmp_c := _icmp_data[ICMP_CD]

PUB ICMP_Ident{}: iid
' Get ICMP identifier
    iid.byte[0] := _icmp_echo[ICMP_IDENT_M]
    iid.byte[1] := _icmp_echo[ICMP_IDENT_L]

PUB ICMP_MsgLen{}: len
' Get length of currently assembled ICMP message
    return _icmp_msg_len

PUB ICMP_MsgType{}: msg_t
' Get ICMP message type
    msg_t := _icmp_data[ICMP_T]

PUB ICMP_SeqNr{}: seq_nr
' Get ICMP sequence number
    seq_nr.byte[0] := _icmp_echo[ICMP_SEQNR_M]
    seq_nr.byte[1] := _icmp_echo[ICMP_SEQNR_L]

PUB ICMP_TimeStamp{}: tm
' Get timestamp from ICMP message
    return _icmp_tm_stamp

PUB Rd_ICMP_Msg{}: ptr
' Read/disassemble ICMP message
'   Returns: length of read message, in bytes
    rdblk_lsbf(@_icmp_data, 4)
    if (_icmp_data[ICMP_T] == ECHO_REQ)
        rdblk_lsbf(@_icmp_echo, ICMP_ECHO_MSG_SZ)
    return currptr{}

PUB Wr_ICMP_Msg{}: ptr | st
' Write/assemble ICMP message
'   Returns: length of assembled message, in bytes
    st := currptr{}
    wrblk_lsbf(@_icmp_data, 4)
    if (_icmp_data[ICMP_T] == ECHO_REPL)
        wrblk_lsbf(@_icmp_echo, ICMP_ECHO_MSG_SZ)
    _icmp_msg_len := currptr{} - st
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

