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

## Requirements

P1/SPIN1:
* spin-standard-library
* #inclusion by an object (e.g., network device driver) that provides FIFO R/W methods

P2/SPIN2:
* p2-spin-standard-library
* #inclusion by an object (e.g., network device driver) that provides FIFO R/W methods

## Compiler Compatibility

| Processor | Language | Compiler               | Backend     | Status                |
|-----------|----------|------------------------|-------------|-----------------------|
| P1        | SPIN1    | FlexSpin (5.9.25-beta) | Bytecode    | OK                    |
| P1        | SPIN1    | FlexSpin (5.9.25-beta) | Native code | OK                    |
| P1        | SPIN1    | OpenSpin (1.00.81)     | Bytecode    | Untested (deprecated) |
| P2        | SPIN2    | FlexSpin (5.9.25-beta) | NuCode      | OK                    |
| P2        | SPIN2    | FlexSpin (5.9.25-beta) | Native code | Untested              |
| P1        | SPIN1    | Brad's Spin Tool (any) | Bytecode    | Unsupported           |
| P1, P2    | SPIN1, 2 | Propeller Tool (any)   | Bytecode    | Unsupported           |
| P1, P2    | SPIN1, 2 | PNut (any)             | Bytecode    | Unsupported           |

## Limitations

* Very early in development - may malfunction, or outright fail to build
* Some things are currently hardcoded
* API unstable
* IP only really supports 20-byte headers
* TCP and ICMP are currently _very_ primitive - only enough is implemented to store/retrieve metadata. No state machine exists for TCP and ICMP is written with enough to form reply messages to echo requests in mind.

