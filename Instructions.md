
# Formats

## R
Register name

## L
- 0x0: Literal
- 0x1: Accumulator
- 0x2: Register
- 0x3: Memory

# Instructions

## BOPs 0x0X

## MOVs 0x1X

- MOV: 0x10LL <64> <64>
- MOVRR: 0x11RR
- MOVOR: 0x12LR <64>
- MOVRO: 0x13RL <64>
- MOVAO: 0x140L <64>

## MATH 0x2X

- ADD: 0x20LL <64> <64>
- ADDRR: 0x21RR x
- SUB: 0x22LL <64> <64>

## CTRL 0x3X

- IJMP: 0x30VL <64>
  - IJNQ: 0x301
- JNQ: 0x32LL <64> <64>
