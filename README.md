# network-spin
--------------

This is a P8X32A/Propeller, P2X8C4M64P/Propeller 2 networking stack

**IMPORTANT**: This software is meant to be used with the [spin-standard-library](https://github.com/avsa242/spin-standard-library) (P8X32A) or [p2-spin-standard-library](https://github.com/avsa242/p2-spin-standard-library) (P2X8C4M64P). Please install the applicable library first before attempting to use this code, otherwise you will be missing several files required to build the project.

## Salient Features

* Ethernet II
* IP
* ARP
* UDP
* TCP
* ICMP
* BOOTP/DHCP
* Socket manager (P1: TCP, single socket, P2: TCP, UDP, multiple sockets; both currently only support the ENC28J60)


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
| P2        | SPIN2    | FlexSpin (7.3.1-beta)  | NuCode      | FTBFS                 |
| P2        | SPIN2    | FlexSpin (7.3.1-beta)  | Native code | OK                    |

(other versions or toolchains not listed are __not supported__, and _may or may not_ work)


## Hardware compatibility

* Tested with ENC28J60 (primary development device)


## Limitations

* Very early in development - may malfunction, or outright fail to build
* Some things are currently hardcoded
* API unstable (only one network device driver currently exists)
* IP only really supports 20-byte headers
* spin1: ICMP is currently _very_ primitive - only enough is implemented to store/retrieve metadata and is written with enough to form reply messages to echo requests.

