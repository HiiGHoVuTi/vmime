main {
  MAP !00
  MAP !01

  MOV r0 !0

  MOV r4 !8
  MOV r5 !281cc00
  MOV r6 !3200
  MOV r7 !0001000000000000
  MOV r8 :end_main

  frames {
    MOV r1 !0
    PSH @2:0

    pixels {
      ADD r0 r4
      MOV r0 acc

      ADD r0 r8
      MOV r3 acc

      FCH r3 !8
      MOV r2 acc

      ADD r1 r7
      MOV r3 acc

      WRD !08
      MOVPTR r3 r2
      WRD !40

      ADD r1 r4
      MOV r1 acc

      SUB r6 r1
      JNQ acc :pixels
      JMP :end_pixels
    }

    UPT !01

    POP acc
    MOV r2 acc
    MOV r3 @2:0
    SUB r3 r2

    MOV r2 acc
    MOV r3 !64
    SUB r3 r2

    SLP acc

    SUB r0 r5
    JNQ acc :frames
    JMP :end_frames
  }
  HLT
}
