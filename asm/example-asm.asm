main {
   MOV r1 !4c9
   MOV r2 !0
   MOV r3 :printAt
   loop {
      DEC r1

      PSH r2
      CAL r3

      INC r2

      AND r1 r1
      JNQ acc :loop
      JMP :end_loop
   }
   HLT
}

printAt {
  PTSTK !400
  MOV r0 acc

  MOV r1 !0001000000000000

  ADD r0 r1
  MOV r1 acc

  MOVPTR r1 !2a

  RET r0
}
