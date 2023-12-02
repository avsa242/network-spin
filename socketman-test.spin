#define NETIF_DRIVER "../enc28j60-spin/net.eth.enc28j60"
#pragma exportdef(NETIF_DRIVER)

#include "net-common.spinh"

obj

    sockmgr:    "socketman-onesocket"
    cfg:        "boardcfg.ybox2"
    ser:        "com.serial.terminal.ansi" | SER_BAUD=115_200
    fsyn:       "signal.synth"
    net:        NETIF_DRIVER | CS=1, SCK=2, MOSI=3, MISO=4
    time:       "time"
    str:        "string"


pub main() | s

    setup()
    sockmgr.init(@net)
    sockmgr.open(   str.strtoip(@"10.42.0.216"), 0, ...
                    str.strtoip(@"10.42.0.1"), 23, ...
                    sockmgr.ACTIVE )
'    sockmgr.open(   str.strtoip(@10.42.0.216"), 23)    ' open a passive (LISTENing) socket, port 23
    sockmgr.loop()
    repeat


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

