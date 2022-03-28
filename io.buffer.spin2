{
    --------------------------------------------
    Filename: io.buffer.spin
    Author: Jesse Burt
    Description: Generic buffer I/O operations
    Started Mar 21, 2022
    Updated Mar 25, 2022
    Copyright 2022
    See end of file for terms of use.
    --------------------------------------------
}
VAR

    long _ptr_dest, _ptr

PUB Init(ptr_buff)
' Initialize
'   Set pointer to operating buffer
'   Set pointer index to 0
    _ptr_dest := ptr_buff
    _ptr := 0

PUB DeInit{}
' Deinitialize
'   Clear variable space
    longfill(@_ptr_dest, 0, 2)

PUB CurrByte{}: b
' Read byte at current pointer without advancing
    return byte[_ptr_dest][_ptr]

PUB CurrPtr{}: p
' Get current pointer index/offset
    return _ptr

PUB DecPtr(val)
' Manually decrement pointer by val
    _ptr -= val

PUB IncPtr(val)
' Manually increment pointer by val
    _ptr += val

PUB RdBlk_LSBF(ptr_buff, len): ptr
' Read block of data from ptr_buff, least-significant (first) byte first
'   Returns: number of bytes read
    repeat ptr from 0 to (len-1)
        byte[ptr_buff][ptr] := byte[_ptr_dest][_ptr++]

PUB RdBlk_MSBF(ptr_buff, len): ptr
' Read block of data from ptr_buff, most-significant (last) byte first
'   Returns: number of bytes read
    repeat ptr from (len-1) to 0
        byte[ptr_buff][ptr] := byte[_ptr_dest][_ptr++]
    return len

PUB Rd_Byte{}: b
' Read byte from buffer
    return byte[_ptr_dest][_ptr++]

PUB RdLong_LSBF{}: l | i
' Read long from buffer, least-significant byte first
    repeat i from 0 to 3
        l.byte[i] := byte[_ptr_dest][_ptr++]

PUB RdLong_MSBF{}: l | i
' Read long from buffer, most-significant byte first
    repeat i from 3 to 0
        l.byte[i] := byte[_ptr_dest][_ptr++]

PUB RdWord_LSBF{}: w
' Read word from buffer, least-significant byte first
    w.byte[0] := byte[_ptr_dest][_ptr++]
    w.byte[1] := byte[_ptr_dest][_ptr++]

PUB RdWord_MSBF{}: w
' Read word from buffer, most-significant byte first
    w.byte[1] := byte[_ptr_dest][_ptr++]
    w.byte[0] := byte[_ptr_dest][_ptr++]

PUB SetPtr(p)
' Set pointer index/offset
    _ptr := p

PUB WrBlk_LSBF(ptr_buff, len): ptr
' Write block of data, least-significant (first) byte first
    bytemove(_ptr_dest+_ptr, ptr_buff, len)
    _ptr += len
    return len

PUB WrBlk_MSBF(ptr_buff, len): ptr
' Write block of data, most-significant (last) byte first
    repeat ptr from (len-1) to 0
        byte[_ptr_dest][_ptr++] := byte[ptr_buff][ptr]
    return len

PUB Wr_Byte(b): len
' Write byte to buffer
'   Increment offset
    byte[_ptr_dest][_ptr++] := b
    return 1

PUB Wr_ByteX(b, nr_bytes): len
' Repeatedly write byte 'b', 'nr_bytes' times
    repeat nr_bytes
        byte[_ptr_dest][_ptr++] := b
    return nr_bytes

PUB WrLong_LSBF(l): len | i
' Write long to buffer, least-significant byte first
'   Increment offset
    repeat i from 0 to 3
        byte[_ptr_dest][_ptr++] := l.byte[i]
    return 4

PUB WrLong_MSBF(l): len | i
' Write long to buffer, most-significant byte first
'   Increment offset
    repeat i from 3 to 0
        byte[_ptr_dest][_ptr++] := l.byte[i]
    return 4

PUB WrWord_LSBF(w): len
' Write word to buffer, least-significant byte first
'   Increment offset
    byte[_ptr_dest][_ptr++] := w.byte[0]
    byte[_ptr_dest][_ptr++] := w.byte[1]
    return 2

PUB WrWord_MSBF(w): len
' Write word to buffer, most-significant byte first
'   Increment offset
    byte[_ptr_dest][_ptr++] := w.byte[1]
    byte[_ptr_dest][_ptr++] := w.byte[0]
    return 2

