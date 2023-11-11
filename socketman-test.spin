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


dat

    _mac_local  byte $02, $98, $0c, $06, $01, $c9
    _my_ip      long 10 | (42 << 8) | (0 << 16) | (216 << 24)
    _rem_ip     long 10 | (42 << 8) | (0 << 16) | (1 << 24)


pub main() | s

    setup()
    sockmgr.init(@net, _my_ip, @_mac_local)
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

