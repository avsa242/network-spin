#define NETIF_DRIVER "../enc28j60-spin/net.eth.enc28j60"
#pragma exportdef(NETIF_DRIVER)
#define ip str.strtoip                          { provide a shorthand for the strtoip function }

#include "net-common.spinh"

obj

    sockmgr:    "socketman-onesocket"
    cfg:        "boardcfg.ybox2"
    ser:        "com.serial.terminal.ansi" | SER_BAUD=115_200
    fsyn:       "signal.synth"
    net:        NETIF_DRIVER | CS=1, SCK=2, MOSI=3, MISO=4
    time:       "time"
    str:        "string"


dat _mac_local  byte $02, $98, $0c, $06, $01, $c9

dat _test byte "Test data", 13, 10, 13, 10, 0


var

    byte _app_rxbuff[1000], _app_txbuff[1000]


pub main() | s, e, st, l

    setup()
    sockmgr.init(@net)
    s := cnt
    st := sockmgr.open(     ip(@"10.42.0.216"), 0, ...
                            ip(@"10.42.0.1"), 23, ...
                            sockmgr.ACTIVE | sockmgr.O_BLOCK )
'    sockmgr.open(   str.strtoip(@10.42.0.216"), 23)    ' open a passive (LISTENing) socket, port 23
    e := ||(cnt-s) / 80
    if ( st < 0 )
        ser.printf1(@"Error connecting: %d\n\r", st)
        outa[10] := 0                           ' turn on ybox2 red LED
        dira[10] := 1
        repeat

    outa[9]:=0                                  ' turn on ybox2 green LED
    dira[9]:=1

    repeat
        case ser.rx_check()
            "d":
                sockmgr.close()
            "r":
                l := sockmgr.read(@_app_rxbuff)
                ser.printf1(@"recvd %d bytes\n\r", l)
                ser.hexdump(@_app_rxbuff, 0, 4, l, 16)
            "s":
                s := strsize(@_test)
                bytemove(@_app_txbuff, @_test, s)
                ser.hexdump(@_app_txbuff, 0, 4, s, 16)
                l := sockmgr.send(@_app_txbuff, s, true)
                ser.printf1(@"sent %d bytes\n\r", l)
            "t":
                ser.printf1(@"open() took %dus\n\r", e)


pub setup()

    ser.start()
    time.msleep(30)
    ser.clear()
    ser.strln(@"serial started")
    sockmgr.set_debug_obj(@ser)

    fsyn.synth("A", cfg.ENC_OSCPIN, 25_000_000)
    time.msleep(50)
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

