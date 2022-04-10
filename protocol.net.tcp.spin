{
    --------------------------------------------
    Filename: protocol.net.tcp.spin
    Author: Jesse Burt
    Description: Transmission Control Protocol
    Started Apr 5, 2022
    Updated Apr 5, 2022
    Copyright 2022
    See end of file for terms of use.
    --------------------------------------------
}
#ifndef NET_COMMON
#include "net-common.spinh"
#endif

CON

{ Limits }

{ offsets within header }
    IDX_TCP_SRCP    = 0
    IDX_TCP_DESTP   = IDX_TCP_SRCP+2
    IDX_TCP_SEQNR   = IDX_TCP_DESTP+2
    IDX_TCP_ACKNR   = IDX_TCP_SEQNR+4
    IDX_TCP_HDRLEN  = IDX_TCP_ACKNR+4
    IDX_TCP_FLAGS   = IDX_TCP_HDRLEN+1
    IDX_TCP_WIN     = IDX_TCP_FLAGS+2
    IDX_TCP_CKSUM   = IDX_TCP_WIN+2
    IDX_TCP_URGPTR  = IDX_TCP_CKSUM+2
    IDX_TCP_OPTS    = IDX_TCP_URGPTR+2

{ TCP flags/control bits }
    NONCE           = 1 << 8
    CWR             = 1 << 7
    ECN_ECHO        = 1 << 6
    URG             = 1 << 5
    ACK             = 1 << 4
    PSH             = 1 << 3
    RST             = 1 << 2
    SYN             = 1 << 1
    FIN             = 1 << 0

{ TCP options }
    NOOP            = $01
    MSS             = $02
    WIN_SCALE       = $03
    SACK_PRMIT      = $04
    TMSTAMPS        = $08

VAR

    long _seq_nr, _ack_nr
    word _tcp_src_port, _tcp_dest_port
    word _tcp_cksum
    word _tcp_win
    word _urg_ptr
    word _tcp_flags
    word _tcp_msglen
    byte _tcp_hdrlen

PUB TCP_SetAckNr(ack_nr)
' Set TCP acknowledgement number
    _ack_nr := ack_nr

PUB TCP_SetChksum(ck)
' Set checksum
    _tcp_cksum := ck

PUB TCP_SetDestPort(p)
' Set destination port field
    _tcp_dest_port := p

PUB TCP_SetFlags(flags)
' Set TCP header flags
    _tcp_flags := flags

PUB TCP_SetHdrLen(length)
' Set TCP header length (must be a multiple of 4)
    _tcp_hdrlen := length/4

PUB TCP_SetSeqNr(seq_nr)
' Set TCP sequence number
    _seq_nr := seq_nr

PUB TCP_SetSrcPort(p)
' Set source port field
    _tcp_src_port := p

PUB TCP_SetUrgentPtr(uptr)
' Set TCP urgent pointer
    _urg_ptr := uptr

PUB TCP_SetWindow(win)
' Set TCP window
    _tcp_win := win

PUB TCP_AckNr{}: ack_nr
' Get TCP acknowledgement number
    return _ack_nr

PUB TCP_Chksum{}: ck
' Get checksum
    return _tcp_cksum

PUB TCP_DestPort{}: p
' Get destination port field
    return _tcp_dest_port

PUB TCP_Flags{}: flags
' Get TCP header flags
    return _tcp_flags

PUB TCP_HdrLen{}: len
' Get current header length
    return _tcp_hdrlen

PUB TCP_MsgLen{}: len
' Get current message length
    return _tcp_msglen

PUB TCP_SeqNr{}: seq_nr
' Get TCP sequence number
    return _seq_nr

PUB TCP_SrcPort{}: p
' Get source port field
    return _tcp_src_port

PUB TCP_UrgentPtr{}: uptr
' Get TCP urgent pointer
    return _urg_ptr

PUB TCP_Window{}: win
' Get TCP header window
    return _tcp_win

PUB Rd_TCP_Header{} | tmp
' Read/disassemble TCP header
'   Returns: length of read header, in bytes
    _tcp_src_port := rdword_msbf{}
    _tcp_dest_port := rdword_msbf{}
    _seq_nr := rdlong_msbf{}
    _ack_nr := rdlong_msbf{}
    tmp := rd_byte{}
    _tcp_hdrlen := ((tmp >> 4) & $0f)

    _tcp_flags := (tmp & 1) << NONCE
    tmp := rd_byte{}
    _tcp_flags |= tmp                           ' remaining flags
    _tcp_win := rdword_msbf{}
    _tcp_cksum := rdword_msbf{}
    _urg_ptr := rdword_msbf{}

    'TODO: TCP options
    return currptr{}

PUB Wr_TCP_Header{}: ptr | st   ' UNTESTED
' Write/assemble TCP header
'   Returns: length of assembled header, in bytes
    st := currptr{}
    wrword_msbf(_tcp_src_port)
    wrword_msbf(_tcp_dest_port)
    wrlong_msbf(_seq_nr)
    wrlong_msbf(_ack_nr)
    wr_byte((_tcp_hdrlen << 4) | ((_tcp_flags >> NONCE) & 1))
    wr_byte(_tcp_flags & $ff)
    wrword_msbf(_tcp_win)
    wrword_msbf(_tcp_cksum)
    wrword_msbf(_urg_ptr)

    _tcp_msglen := currptr{}-st
    'TODO: TCP options
    return _tcp_msglen

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

