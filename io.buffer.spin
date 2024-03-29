{
    --------------------------------------------
    Filename: io.buffer.spin
    Author: Jesse Burt
    Description: Generic buffer I/O operations
    Started Mar 21, 2022
    Updated Sep 11, 2022
    Copyright 2022
    See end of file for terms of use.
    --------------------------------------------
}
CON

    FIFO_MAX = 8191

VAR

    long _ptr_dest, _ptr

PUB init(ptr_buff)
' Initialize
'   Set pointer to operating buffer
'   Set pointer index to 0
    _ptr_dest := ptr_buff
    _ptr := 0

PUB deinit{}
' Deinitialize
'   Clear variable space
    longfill(@_ptr_dest, 0, 2)

PUB curr_byte{}: b
' Read byte at current pointer without advancing
    return byte[_ptr_dest][_ptr]

PUB dec_ptr(val)
' Manually decrement pointer by val
    _ptr -= val

PUB fifo_set_wr_ptr(ptr)
' Set write position within FIFO
'   Valid values: 0..FIFO_MAX
    _ptr := 0 #> ptr <# FIFO_MAX

PUB fifo_wr_ptr{}: p
' Get current write position within FIFO
    return _ptr

PUB inc_ptr(val)
' Manually increment pointer by val
    _ptr += val

PUB rdblk_lsbf(ptr_buff, len): ptr
' Read block of data from ptr_buff, least-significant (first) byte first
'   Returns: number of bytes read
    repeat ptr from 0 to (len-1)
        byte[ptr_buff][ptr] := byte[_ptr_dest][_ptr++]

PUB rdblk_msbf(ptr_buff, len): ptr
' Read block of data from ptr_buff, most-significant (last) byte first
'   Returns: number of bytes read
    repeat ptr from (len-1) to 0
        byte[ptr_buff][ptr] := byte[_ptr_dest][_ptr++]
    return len

PUB rd_byte{}: b
' Read byte from buffer
    return byte[_ptr_dest][_ptr++]

PUB rdlong_lsbf{}: l | i
' Read long from buffer, least-significant byte first
    repeat i from 0 to 3
        l.byte[i] := byte[_ptr_dest][_ptr++]

PUB rdlong_msbf{}: l | i
' Read long from buffer, most-significant byte first
    repeat i from 3 to 0
        l.byte[i] := byte[_ptr_dest][_ptr++]

PUB rdword_lsbf{}: w
' Read word from buffer, least-significant byte first
    w.byte[0] := byte[_ptr_dest][_ptr++]
    w.byte[1] := byte[_ptr_dest][_ptr++]

PUB rdword_msbf{}: w
' Read word from buffer, most-significant byte first
    w.byte[1] := byte[_ptr_dest][_ptr++]
    w.byte[0] := byte[_ptr_dest][_ptr++]

PUB wrblk_lsbf(ptr_buff, len): ptr
' Write block of data, least-significant (first) byte first
    bytemove(_ptr_dest+_ptr, ptr_buff, len)
    _ptr += len
    return len

PUB wrblk_msbf(ptr_buff, len): ptr
' Write block of data, most-significant (last) byte first
    repeat ptr from (len-1) to 0
        byte[_ptr_dest][_ptr++] := byte[ptr_buff][ptr]
    return len

PUB wr_byte(b): len
' Write byte to buffer
'   Increment offset
    byte[_ptr_dest][_ptr++] := b
    return 1

PUB wr_byte_x(b, nr_bytes): len
' Repeatedly write byte 'b', 'nr_bytes' times
    repeat nr_bytes
        byte[_ptr_dest][_ptr++] := b
    return nr_bytes

PUB wrlong_lsbf(l): len | i
' Write long to buffer, least-significant byte first
'   Increment offset
    repeat i from 0 to 3
        byte[_ptr_dest][_ptr++] := l.byte[i]
    return 4

PUB wrlong_msbf(l): len | i
' Write long to buffer, most-significant byte first
'   Increment offset
    repeat i from 3 to 0
        byte[_ptr_dest][_ptr++] := l.byte[i]
    return 4

PUB wrword_lsbf(w): len
' Write word to buffer, least-significant byte first
'   Increment offset
    byte[_ptr_dest][_ptr++] := w.byte[0]
    byte[_ptr_dest][_ptr++] := w.byte[1]
    return 2

PUB wrword_msbf(w): len
' Write word to buffer, most-significant byte first
'   Increment offset
    byte[_ptr_dest][_ptr++] := w.byte[1]
    byte[_ptr_dest][_ptr++] := w.byte[0]
    return 2

