main {
   MOV r1 !0
   MOV r2 :printAt
   loop {
      PSH r1
      CAL r2

      INC r1
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
  MOVPTR r1 !23
  RET acc
}
