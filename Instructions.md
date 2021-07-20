
"x" means not implemented.

# TODO

- Binary operations

# Formats

## R
Register name

## L
- 0x0: Literal
- 0x1: Accumulator
- 0x2: Register
- 0x3: Memory
- 0x4: Address in register

# Instructions

## BOPs 0x0X

## MOVs 0x1X

- MOV: 0x10LL <64> <64>
- MOVRR: 0x11RR
- MOVOR: 0x12LR <64>
- MOVRO: 0x13RL <64>
- MOVAO: 0x140L <64>
- MOVAR: 0x150R

- GTH: 0x16RR

- PSH: 0x18VV
  - PSHL: 0x180L <64>
  - PSHR: 0x181R
- POP: 0x19VV x
  - POPL: 0x190L <64> x
  - POPR: 0x191R x
  - POPA: 0x1920


## MATH 0x2X

- ADD: 0x20LL <64> <64>
- ADDRR: 0x21RR x
- SUB: 0x22LL <64> <64>

## CTRL 0x3X

- CMP: 0x30LL <64> <64> x
- ICMP: 0x310L <64> x
- CMPRR: 0x32RR x
- IJMP: 0x33VL <64>
  - IJNQ: 0x331L <64>
- JNQ: 0x35LL <64> <64>
