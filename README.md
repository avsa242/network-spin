# network-spin
--------------

This is a P8X32A/Propeller, P2X8C4M64P/Propeller 2 networking stack

**IMPORTANT**: This software is meant to be used with the [spin-standard-library](https://github.com/avsa242/spin-standard-library) (P8X32A) or [p2-spin-standard-library](https://github.com/avsa242/p2-spin-standard-library) (P2X8C4M64P). Please install the applicable library first before attempting to use this code, otherwise you will be missing several files required to build the project.

## Salient Features

* IP
* ARP
* UDP
* BOOTP/DHCP
* ICMP
* Buffer-oriented (individual components of datagrams are stored as variables, manipulated or retrieved using object methods, and used to assemble datagrams which are then copied to a user-specified buffer)

## Requirements

P1/SPIN1:
* spin-standard-library

P2/SPIN2:
* p2-spin-standard-library

## Compiler Compatibility

* P1/SPIN1 OpenSpin (bytecode): Untested (deprecated)
* P1/SPIN1 FlexSpin (bytecode): OK, tested with 5.9.9-beta
* P1/SPIN1 FlexSpin (native): OK, tested with 5.9.9-beta
* ~~P2/SPIN2 FlexSpin (nu-code):~~ FTBFS
* P2/SPIN2 FlexSpin (native): OK, tested with 5.9.9-beta
* ~~BST~~ (incompatible - no preprocessor)
* ~~Propeller Tool~~ (incompatible - no preprocessor)
* ~~PNut~~ (incompatible - no preprocessor)

## Limitations

* Very early in development - may malfunction, or outright fail to build
* Some things are currently hardcoded
* Only buffer-oriented currently, so can be quite memory hungry (depending on network frame buffer size)
* API unstable
