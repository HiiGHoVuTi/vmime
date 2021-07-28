main {
   MOV r1 !5
   MOV r2 :print
   loop {
      DEC r1
      PSH r1
      CAL r2
      AND r1 r1
      JNQ acc :loop
      JMP :end_loop
   }
   HLT
}
print {
  POP acc
  ;;  print char next to current pos
  RET acc
}
