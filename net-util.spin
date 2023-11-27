obj

    { virtual terminal driver }
    term=   TERM_DRIVER

    str:    "string"

var

    { terminal driver object pointer }
    long drv


pub attach = attach_terminal_driver
pub attach_terminal_driver(optr)
' Initialize: set the terminal output driver
    drv := optr


PUB show_ip_addr(ptr_premsg, addr, ptr_postmsg) | i
' Display IP address, with optional prefixed/postfixed strings (pass 0 to ignore)
    if (ptr_premsg)
        term[drv].str(ptr_premsg)
    repeat i from 0 to 3
        term[drv].dec(addr.byte[i])
        if (i < 3)
            term[drv].char(".")
    if (ptr_postmsg)
        term[drv].str(ptr_postmsg)


PUB show_mac_addr(ptr_premsg, ptr_addr, ptr_postmsg) | i
' Display MAC address, with optional prefixed/postfixed strings (pass 0 to ignore)
    if (ptr_premsg)
        term[drv].str(ptr_premsg)
    repeat i from 0 to 5
        term[drv].hexs(byte[ptr_addr][i], 2)
        if (i < 5)
            term[drv].char(":")
    if (ptr_postmsg)
        term[drv].str(ptr_postmsg)

PUB show_tcp_flags(flags) | i
' Display the TCP header's flag bits as symbols
    term[drv].str(@"Flags: [")
    repeat i from 7 to 0
        if ( flags & |<(i) )
            if ( flags & (1 << 2) )
                term[drv].fgcolor(term[drv].RED)
            else
                term[drv].fgcolor(term[drv].GREEN)
            term[drv].str(@_tcp_flagstr[i*6])
        else
            term[drv].fgcolor(term[drv].DKGREY)
            term[drv].str(@_tcp_flagstr[i*6])
    term[drv].fgcolor(term[drv].GREY)
    term[drv].putchar("]")
    term[drv].newline()
DAT

    { TCP flags: strings }
    _tcp_flagstr
        byte    " FIN ", 0
        byte    " SYN ", 0
        byte    " RST ", 0
        byte    " PSH ", 0
        byte    " ACK ", 0
        byte    " URG ", 0
        byte    " ECN ", 0
        byte    " CWR ", 0


pub str2ip(ptr_str): ip | o
' Convert an IP address in string representation to an integer (long)
'   NOTE: string must be in the format ddd.ddd.ddd.ddd, where d are decimal digits
'       (leading zeroes are not required)
    repeat o from 0 to 3
        ip.byte[o] := str.atoi( str.getfield(ptr_str, o, ".") )


pub str2mac(rd_str, dest_mac) | o
' Convert a MAC address in string representation to an array of integers
'   rd_str: string representation of MAC address
'   dest_mac: pointer to the start of an array to copy MAC address to (must be at least 6 bytes)
'   NOTE: string must be in the format xx:xx:xx:xx:xx:xx, where x are hexadecimal digits
'       (leading zeroes are not required)
    repeat o from 0 to 5
        byte[dest_mac][o] := str.atoib( str.getfield(rd_str, o, ":"), ...
                                        str.IHEX )


