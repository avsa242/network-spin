# network-spin
--------------

This is a P8X32A/Propeller, P2X8C4M64P/Propeller 2 networking stack

**IMPORTANT**: This software is meant to be used with the [spin-standard-library](https://github.com/avsa242/spin-standard-library) (P8X32A) or [p2-spin-standard-library](https://github.com/avsa242/p2-spin-standard-library) (P2X8C4M64P). Please install the applicable library first before attempting to use this code, otherwise you will be missing several files required to build the project.

## Salient Features

* Ethernet II
* IPv4
* ARP
* UDP
* TCP
* ICMP
* IGMP (v3)
* BOOTP/DHCP
* Socket manager (P1: TCP, single socket; P2: TCP, UDP, multiple sockets)


## Requirements

P1/SPIN1:
* spin-standard-library
* an object (e.g., network device driver) that provides FIFO R/W methods

P2/SPIN2:
* p2-spin-standard-library
* an object (e.g., network device driver) that provides FIFO R/W methods


## Compiler Compatibility

| Processor | Language | Compiler               | Backend     | Status                |
|-----------|----------|------------------------|-------------|-----------------------|
| P1        | SPIN1    | FlexSpin (6.9.4)       | Bytecode    | OK                    |
| P1        | SPIN1    | FlexSpin (6.9.4)       | Native code | OK                    |
| P2        | SPIN2    | FlexSpin (7.6.5-beta)  | NuCode      | OK                    |
| P2        | SPIN2    | FlexSpin (7.6.5-beta)  | Native code | OK                    |

(other versions or toolchains not listed are __not supported__, and _may or may not_ work)


## Hardware compatibility

* Tested with ENC28J60 (P1, P2; primary development device)
* Tested with [ENC624J600](https://www.digikey.com/en/products/detail/olimex-ltd/MOD-ENC624J600/21662677?s=N4IgTCBcDaIKYDsDGA2MAWAVigDDkAugL5A) (P2 only)


## Limitations

* Very early in development - may malfunction, or outright fail to build
* Some things are currently hardcoded
* API unstable (only one network device driver currently exists)
* spin1: ICMP is currently _very_ primitive - only enough is implemented to store/retrieve metadata and is written with enough to form reply messages to echo requests.

