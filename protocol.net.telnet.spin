{
    --------------------------------------------
    Filename: protocol.net.telnet.spin
    Author: Jesse Burt
    Description: Telnet Protocol
    Started Dec 23, 2023
    Updated Dec 23, 2023
    Copyright 2023
    See end of file for terms of use.
    --------------------------------------------
}

con

    UNSUPPORTED         = 0
    SUPPORTED           = 1


    { Telnet option negotiation }
    IAC                 = $ff

    IS                  = $00
    SUBNEG_END          = $f0
    NOOP                = $f1
    DATA_MARK           = $f2
    BREAK               = $f3
    INT_PROCS           = $f4
    ABORT_OUT           = $f5
    R_U_THERE           = $f6
    ERASE_CHAR          = $f7
    ERASE_LINE          = $f8
    GO_AHEAD            = $f9
    SUBNEG              = $fa
    WILL                = $fb
    WONT                = $fc
    DOO                 = $fd
    DONT                = $fe

    { Options }
    TRANSMIT_BIN        = $00
    ECHO                = $01
    SUPPRESS_GO_AHEAD   = $03
    OPT_STATUS          = $05
    TIMING_MARK         = $06
    NAOCRD              = $0a
    NAOHTS              = $0b
    NAOHTD              = $0c
    NAOFFD              = $0d
    NAOVTS              = $0e
    NAOVTD              = $0f
    NAOLFD              = $10
    EXTEND_ASCII        = $11
    TERMINAL_TYPE       = $18
    NAWS                = $1f
    TERMINAL_SPEED      = $20
    TOGGLE_FLOW_CTRL    = $21
    LINEMODE            = $22
    X_DISPLAY_LOC       = $23
    ENV_OPT             = $24
    AUTHENTICATION      = $25
    ENCRYPT             = $26
    NEW_ENV_OPT         = $27


var

    { function pointers }
    long socket_getchar
    long socket_putchar

    byte _local_opts[40]
    byte _remote_opts[40]
    byte _negd_opts[40]


pub set_socket_getchar(fptr)
' Read a character from the socket
    socket_getchar := fptr


pub set_socket_putchar(fptr)
' Write a character to the socket
    socket_putchar := fptr


pub i_will(opt)
' Indicate desire to begin performing, or confirmation that this client is now performing
'   the indicated option
    _local_opts[opt] := WILL


pub i_wont(opt)
' Indicate refusal to perform or to continue performing the indicated option
    _local_opts[opt] := WONT


pub please_do(opt)
' Request that the remote host perform or confirm the remote host is expected to perform
'   the indicated option
    _local_opts[opt] := DOO


pub please_dont(opt)
' Demand the remote host stop performing, or indicate the remote host is no longer expected to
'   perform the indicated option
    _local_opts[opt] := DONT


pub negotiate_option(opt) | out_verb
' Check an option against what this telnet client supports or allows, and queue the
'   negotiated response to it in the socket send queue.
    case _remote_opts[opt]                      ' get remote's verb
        DOO:
            if ( _local_opts[opt] == SUPPORTED )
                { if the server says "do", and we support this option, say we will }
                out_verb := WILL
            else
                out_verb := WONT
        DONT:
            { if the server requests we suppress some option, honor it }
            out_verb := WONT
        WILL:
            { if the server says it's willing to negotiate an option and we support it,
                request that it do so }
            if ( _local_opts[opt] == SUPPORTED )
                out_verb := DOO
            else
                out_verb := DONT
        WONT:

    'xxx this seems a little unsafe as-written: an option is queued regardless
    'xxx should we even queue anything for DONT or WONT? or should they just silently be honored?
    queue_opt(opt, out_verb)
    _negd_opts[opt] := out_verb


pub negotiated_option_verb = negotiated_option
pub option_is_negotiated = negotiated_option
pub negotiated_option(opt): s

    return ( _negd_opts[opt] )


pub parse_remote_option(): opt | verb
' Parse remote node's option
'   Returns: the option number received
    opt := 0
    verb := socket_getchar()
    case verb
        $ff:
            { literal $ff - don't process further - just return }
            return $ff
        DOO, DONT, WILL, WONT:
            { cache the remote's option locally; the verb is stored in the array at the offset of
                the particular option }
            opt := socket_getchar()
            _remote_opts[opt] := verb


pub queue_opt(opt, verb)
' Queue a Telnet option
    socket_putchar(IAC)
    socket_putchar(verb)
    socket_putchar(opt)


pub set_initial_opts()
' Set the options this telnet client supports
'   xxx a few of these marked SUPPORTED aren't actually supported, but it seems they need to
'   xxx be in order to complete the options negotiation to a point where we get a remote shell
    _local_opts[TRANSMIT_BIN] := UNSUPPORTED
    _local_opts[ECHO] := UNSUPPORTED
    _local_opts[SUPPRESS_GO_AHEAD] := SUPPORTED
    _local_opts[OPT_STATUS] := SUPPORTED
    _local_opts[TIMING_MARK] := UNSUPPORTED
    _local_opts[NAOCRD] := UNSUPPORTED
    _local_opts[NAOHTS] := UNSUPPORTED
    _local_opts[NAOFFD] := UNSUPPORTED
    _local_opts[NAOVTS] := UNSUPPORTED
    _local_opts[NAOVTD] := UNSUPPORTED
    _local_opts[NAOLFD] := UNSUPPORTED
    _local_opts[EXTEND_ASCII] := UNSUPPORTED
    _local_opts[TERMINAL_TYPE] := UNSUPPORTED
    _local_opts[NAWS] := SUPPORTED
    _local_opts[TERMINAL_SPEED] := UNSUPPORTED
    _local_opts[TOGGLE_FLOW_CTRL] := UNSUPPORTED
    _local_opts[LINEMODE] := UNSUPPORTED
    _local_opts[X_DISPLAY_LOC] := UNSUPPORTED
    _local_opts[ENV_OPT] := UNSUPPORTED
    _local_opts[AUTHENTICATION] := SUPPORTED
    _local_opts[ENCRYPT] := SUPPORTED
    _local_opts[NEW_ENV_OPT] := UNSUPPORTED


DAT
{
Copyright 2023 Jesse Burt

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
associated documentation files (the "Software"), to deal in the Software without restriction,
including without limitation the rights to use, copy, modify, merge, publish, distribute,
sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or
substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT
OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
}

