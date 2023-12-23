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
    telnet:     "protocol.net.telnet"
    time:       "time"
    str:        "string"

var

    long _connected
    byte _state

    byte _local_echo


con #0, ST_CMD, ST_DATA
pub main() | st, ser_ch, rx_ch, o, opts_q, my_ip, server_ip

    setup()
    sockmgr.init(@net)
    sockmgr.set_disconnect_event_func(@disc)
    sockmgr.set_connect_event_func(@conn)
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
                                if ( telnet.option_is_negotiated(o) )
                                    show_opt_verb(o, telnet.negotiated_option_verb(o))
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
                        if ( rx_ch == telnet.IAC )
                            { $ff received? It could be an option negotiation }
                            o := telnet.parse_remote_option()
                            if ( (o => 0) and (o =< 39) )
                                telnet.negotiate_option(o)
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


pub putchar(ch): s
' Send a character to the remote host
    sockmgr.send(@ch, 1, true)


pub show_opt_verb(opt, verb)
' Show an option with its currently set verb

    case verb
        telnet.WILL:
            ser.fgcolor(ser.GREEN)
            ser.str(@"will ")
            ser.fgcolor(ser.GREY)
        telnet.WONT:
            ser.fgcolor(ser.RED)
            ser.str(@"won't ")
            ser.fgcolor(ser.GREY)
        telnet.DOO:
            ser.fgcolor(ser.GREEN)
            ser.str(@"do ")
            ser.fgcolor(ser.GREY)
        telnet.DONT:
            ser.fgcolor(ser.RED)
            ser.str(@"don't ")
            ser.fgcolor(ser.GREY)
        other:
            ser.str(@"invalid")

    case opt
        telnet.TRANSMIT_BIN:       ser.strln(@"transmit binary")
        telnet.ECHO:               ser.strln(@"echo")
        telnet.SUPPRESS_GO_AHEAD:  ser.strln(@"suppress go-ahead")
        telnet.OPT_STATUS:         ser.strln(@"opt status")
        telnet.TIMING_MARK:        ser.strln(@"timing mark")
        telnet.NAOCRD:             ser.strln(@"NAOCRD")
        telnet.NAOHTS:             ser.strln(@"NAOHTS")
        telnet.NAOHTD:             ser.strln(@"NAOHTD")
        telnet.NAOFFD:             ser.strln(@"NAOFFD")
        telnet.NAOVTS:             ser.strln(@"NAOVTS")
        telnet.NAOVTD:             ser.strln(@"NAOVTD")
        telnet.NAOLFD:             ser.strln(@"NAOLFD")
        telnet.EXTEND_ASCII:       ser.strln(@"EXTEND_ASCII")
        telnet.TERMINAL_TYPE:      ser.strln(@"terminal type")
        telnet.NAWS:               ser.strln(@"NAWS")
        telnet.TERMINAL_SPEED:     ser.strln(@"terminal speed")
        telnet.TOGGLE_FLOW_CTRL:   ser.strln(@"toggle flow control")
        telnet.LINEMODE:           ser.strln(@"line-mode")
        telnet.X_DISPLAY_LOC:      ser.strln(@"X display location")
        telnet.ENV_OPT:            ser.strln(@"environment option")
        telnet.AUTHENTICATION:     ser.strln(@"authentication")
        telnet.ENCRYPT:            ser.strln(@"encrypt")
        telnet.NEW_ENV_OPT:        ser.strln(@"new environment option")
        other:
        { invalid option - bail out }
            ser.strln(@"???")
            return


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

    telnet.set_initial_opts()
    telnet.set_socket_getchar(@sockmgr.getchar)
    telnet.set_socket_putchar(@sockmgr.putchar)

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


