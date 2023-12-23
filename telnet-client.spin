{
    --------------------------------------------
    Filename: telnet-client.spin
    Author: Jesse Burt
    Description: Telnet client
        * ENC28J60
    Started Dec 22, 2023
    Updated Dec 22, 2023
    Copyright 2023
    See end of file for terms of use.
    --------------------------------------------
}

#define ENC_EXTERNAL_CLK
#define NETIF_DRIVER "../enc28j60-spin/net.eth.enc28j60"
#pragma exportdef(NETIF_DRIVER)
#define ip str.strtoip                          { provide a shorthand for the strtoip function }

{ set TCP receive buffer size (_must_ be a power of 2) }
#define RECV_BUFFSZ 1024
#pragma exportdef(RECV_BUFFSZ)

#include "net-common.spinh"

dat

    { this host's MAC address }
    _mac_local  byte $02, $98, $0c, $01, $02, $03


obj

    sockmgr:    "socketman-onesocket"
    cfg:        "boardcfg.ybox2"
    ser:        "com.serial.terminal.ansi" | SER_BAUD=115_200
#ifdef ENC_EXTERNAL_CLK
    fsyn:       "signal.synth"
#endif
    net:        NETIF_DRIVER | CS=1, SCK=2, MOSI=3, MISO=4
    time:       "time"
    str:        "string"

var

    long _connected
    byte _state
    byte _local_opts[40]
    byte _remote_opts[40]
    byte _negd_opts[40]

    byte _local_echo


con #0, ST_CMD, ST_DATA
pub main() | st, ser_ch, rx_ch, o, opts_q, my_ip, server_ip

    setup()
    sockmgr.init(@net)
    sockmgr.set_disconnect_event_func(@disc)
    sockmgr.set_connect_event_func(@conn)
    sockmgr.set_push_received_event_func(@push)
    opts_q := 0

    repeat
        case _state        
            ST_CMD:
                repeat
                    ser.newline()
                    ser.str(@"telnet> ")
                    case ser.getchar()
                        "c":
                            my_ip := ip(@"192.168.1.10")
                            server_ip := ip(@"192.168.1.1")
                            ser.strln(@"connecting...")
                            st := sockmgr.open(     my_ip, 0, ...
                                                    server_ip, 23, ...
                                                    sockmgr.ACTIVE | sockmgr.O_BLOCK, ...
                                                    5000 )
                            if ( st < 0 )
                                ser.printf1(@"Error connecting: %d\n\r", st)
                            else
                                _state := ST_DATA
                        "d":
                            ser.str(@"disconnecting...")
                            sockmgr.close()
                        "e":
                            _local_echo ^= 1
                            ser.printf1(@"Local echo: %s\n\r", lookupz(_local_echo: @"OFF", @"ON"))
                        "h", "?":
                            ser.strln(@"c: connect")
                            ser.strln(@"d: disconnect")
                            ser.strln(@"e: toggle local echo on/off")
                            ser.strln(@"o: show negotiated options")
                            ser.strln(@"s: connection status")
                            ser.strln(@"t: show open() elapsed time")
                            ser.strln(@">: go back online")
                        "o":
                            repeat o from 0 to 39
                                if ( _negd_opts[o] )
                                    show_opt_verb(o, _negd_opts[o])
                        "s":
                            if ( sockmgr._state == sockmgr.ESTABLISHED )
                                ser.newline()
                                ser.strln(@"state: connected")
                            else
                                ser.newline()
                                ser.strln(@"state: disconnected")
                        ">":
                            _state := ST_DATA
                            quit
                    ser.newline()
                while ( _state == ST_CMD )
            ST_DATA:
                repeat
                    { check for received data from the server }
                    if ( sockmgr.available() )
                        rx_ch := sockmgr.getchar()
                        if ( rx_ch == IAC )
                            { $ff received? It could be an option negotiation }
                            o := parse_remote_option()
                            if ( (o => 0) and (o =< 39) )
                                negotiate_option(o)
                                opts_q := true
                        else
                            { just terminal data - show it locally }
                            ser.putchar(rx_ch)
                    else
                        if ( opts_q )
                            { options that haven't yet been resolved; send them to the server }
                            sockmgr.push_now()
                            opts_q := false
                    { check for local keypresses }
                    ser_ch := ser.rx_check()
                    if ( ser_ch < 0 )
                        next
                    if ( ser_ch == ">" )
                        _state := ST_CMD
                        quit
                    else
                        if ( _local_echo )
                            ser.putchar(ser_ch)
                        putchar(ser_ch)
                while ( _state == ST_DATA )


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
    'ser.str(@">>> ")
    'show_opt_verb(opt, out_verb)


pub parse_remote_option(): opt | verb
' Parse remote node's option
'   Returns: the option number received
    opt := 0
    verb := sockmgr.getchar()
    case verb
        $ff:
            { literal $ff - don't process further - just return }
            ser.putchar($ff)
            return $ff
        DOO, DONT, WILL, WONT:
            { cache the remote's option locally; the verb is stored in the array at the offset of
                the particular option }
            opt := sockmgr.getchar()
            _remote_opts[opt] := verb
    'ser.str(@"<<< ")
    'show_opt_verb(opt, verb)


pub push()


pub putchar(ch): s
' Send a character to the remote host
    sockmgr.send(@ch, 1, true)


pub queue_opt(opt, verb)
' Queue a Telnet option
    sockmgr.putchar(IAC)
    sockmgr.putchar(verb)
    sockmgr.putchar(opt)


pub show_opt_verb(opt, verb)
' Show an option with its currently set verb
    case verb
        WILL:
            ser.fgcolor(ser.GREEN)
            ser.str(@"will ")
            ser.fgcolor(ser.GREY)
        WONT:
            ser.fgcolor(ser.RED)
            ser.str(@"won't ")
            ser.fgcolor(ser.GREY)
        DOO:
            ser.fgcolor(ser.GREEN)
            ser.str(@"do ")
            ser.fgcolor(ser.GREY)
        DONT:
            ser.fgcolor(ser.RED)
            ser.str(@"don't ")
            ser.fgcolor(ser.GREY)
        other:
            ser.str(@"invalid")

    case opt
        TRANSMIT_BIN:       ser.strln(@"transmit binary")
        ECHO:               ser.strln(@"echo")
        SUPPRESS_GO_AHEAD:  ser.strln(@"suppress go-ahead")
        OPT_STATUS:         ser.strln(@"opt status")
        TIMING_MARK:        ser.strln(@"timing mark")
        NAOCRD:             ser.strln(@"NAOCRD")
        NAOHTS:             ser.strln(@"NAOHTS")
        NAOHTD:             ser.strln(@"NAOHTD")
        NAOFFD:             ser.strln(@"NAOFFD")
        NAOVTS:             ser.strln(@"NAOVTS")
        NAOVTD:             ser.strln(@"NAOVTD")
        NAOLFD:             ser.strln(@"NAOLFD")
        EXTEND_ASCII:       ser.strln(@"EXTEND_ASCII")
        TERMINAL_TYPE:      ser.strln(@"terminal type")
        NAWS:               ser.strln(@"NAWS")
        TERMINAL_SPEED:     ser.strln(@"terminal speed")
        TOGGLE_FLOW_CTRL:   ser.strln(@"toggle flow control")
        LINEMODE:           ser.strln(@"line-mode")
        X_DISPLAY_LOC:      ser.strln(@"X display location")
        ENV_OPT:            ser.strln(@"environment option")
        AUTHENTICATION:     ser.strln(@"authentication")
        ENCRYPT:            ser.strln(@"encrypt")
        NEW_ENV_OPT:        ser.strln(@"new environment option")
        other:
        { invalid option - bail out }
            ser.strln(@"???")
            return


con #0, UNSUPPORTED, SUPPORTED
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


con

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


pub conn()
' Function to call when a connection is established
    _connected := true
    _state := ST_DATA
    ser.strln(@"connected")


pub disc()
' Function to call when a disconnect occurs
    ser.strln(@"remote host disconnected")
    _state := ST_CMD


pub setup()

    set_initial_opts()

    ser.start()
    time.msleep(30)
    ser.clear()
    ser.strln(@"serial started")
    'sockmgr.set_debug_obj(@ser)

#ifdef ENC_EXTERNAL_CLK
    { for boards where the ENC28J60 doesn't have a clock (e.g., the YBox2), it can be generated
        by the Propeller }
    fsyn.synth("A", cfg.ENC_OSCPIN, 25_000_000)
    time.msleep(50)
#endif
    if ( net.start() )
        net.set_pkt_filter(0)
        net.preset_fdx()
        net.node_address(@_mac_local)
        ser.strln(@"ENC28J60 driver started")
        ser.str(@"waiting for PHY link...")
        repeat until ( net.phy_link_state() == net.UP )
        ser.strln(@"link UP")
    else
        ser.strln(@"ENC28J60 driver failed to start - halting")
        repeat

    _local_echo := false

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


