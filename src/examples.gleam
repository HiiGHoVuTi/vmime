import vm/system
import vm/ram
import vm/cpu
import vm/messages
import vm/memory
import vm/console
import vm/imported
import clock
import gleam/otp/actor
import gleam/otp/process
import gleam/io
import gleam/result
import gleam/bit_string
import gleam/float
import gleam/int
import gleam/string

pub fn words_size(word_count: Int) -> String {
  float.to_string(int.to_float(word_count) *. 64.0 /. 1024.0)
  |> string.append("kb")
}

pub fn basic_system(nram: Int, dt: Int) {
  let state = system.initial(cpus: [], rams: [])
  assert Ok(sys) = actor.start(state, system.handle)
  assert Ok(cpu) =
    cpu.initial(
      sys,
      [
        "ip", "acc", "sp", "fp", // Special registers
        "r0", "r1", "r2", //"r3", "r4", "r5", "r6", "r7", // GP registers 
        //"r8", "r9", "r10", "r11", "r12", "r13", "r14", "r15",
        "r3",
      ],
      nram,
    )
    |> actor.start(cpu.handle)
  assert Ok(ram) =
    ram.initial(nram)
    |> actor.start(ram.handle)

  assert Ok(cnsl) =
    console.initial(16, 16)
    |> actor.start(console.handle)

  sys
  |> process.send(messages.AddCPU(cpu))
  |> process.send(messages.AddRAM(cnsl))
  |> process.send(messages.AddRAM(ram))

  let timer = clock.new(dt)

  timer
  |> process.send(clock.AddNotify(
    actor: sys
    |> system.to_timer_sender,
  ))

  #(
    sys,
    fn() {
      timer
      |> process.send(clock.TimeUpdate(dt: 0))
    },
    fn(t: Int) {
      let #(_sender, receiver) = process.new_channel()
      let _ = process.receive(receiver, t)
      // completely broken
      timer
      |> process.pid
      |> process.send_exit("Stopped by command")
    },
  )
}

pub fn file_executing_system(nram: Int, fpath: String, dt: Int) {
  let state = system.initial(cpus: [], rams: [])
  assert Ok(sys) = actor.start(state, system.handle)
  assert Ok(cpu) =
    cpu.initial(
      sys,
      [
        "ip", "acc", "sp", "fp", // Special registers
        "r0", "r1", "r2", //"r3", "r4", "r5", "r6", "r7", // GP registers 
        //"r8", "r9", "r10", "r11", "r12", "r13", "r14", "r15",
        "r3",
      ],
      nram,
    )
    |> actor.start(cpu.handle)
  assert Ok(ram) =
    ram.preloaded_program(nram, fpath)
    |> actor.start(ram.handle)

  assert Ok(cnsl) =
    console.initial(16, 16)
    |> actor.start(console.handle)

  sys
  |> process.send(messages.AddCPU(cpu))
  |> process.send(messages.AddRAM(cnsl))
  |> process.send(messages.AddRAM(ram))

  let timer = clock.new(dt)

  timer
  |> process.send(clock.AddNotify(
    actor: sys
    |> system.to_timer_sender,
  ))

  #(
    sys,
    fn() {
      timer
      |> process.send(clock.TimeUpdate(dt: 0))
    },
    fn(t: Int) {
      let #(_sender, receiver) = process.new_channel()
      let _ = process.receive(receiver, t)
      // completely broken
      timer
      |> process.pid
      |> process.send_exit("Stopped by command")
    },
  )
}

pub fn first_loop() {
  let dt = 300
  let #(sys, start, stop_after) = basic_system(256 * 256, dt)
  sys
  |> process.send(messages.WriteRAMAddress(
    0x0,
    <<
      0x1231:16, 0x0200:64, // MOV #0200 r1
      0x1202:16, 0x0001:64, // MOV 0x1 r2
      0x2112:16, // ADD r1 r2
      0x1403:16, 0x0200:64, // MOV acc #0200
      0x2210:16, 0x0000:64, 0x0003:64, // SUB acc 0x3
      0x3310:16, 0x0000:64, // IJNQ #0000 
      0xffff:16,
    >>,
  ))

  start()

  stop_after(40 * dt)
  sys
}

pub fn test_program() {
  let dt = 100
  let #(sys, start, stop_after) = basic_system(256 * 256, dt)
  sys
  |> process.send(messages.WriteRAMAddress(
    0x0,
    // Main
    <<
      0x1003:16, 0x0048:64, 0x1:16, 0x00:48, // H
      0x1003:16, 0x0065:64, 0x1:16, 0x01:48, // e
      0x1003:16, 0x006c:64, 0x1:16, 0x02:48, // l
      0x1003:16, 0x006c:64, 0x1:16, 0x03:48, // l
      0x1003:16, 0x006f:64, 0x1:16, 0x04:48, // o
      0x1003:16, 0x0020:64, 0x1:16, 0x05:48, // 
      0x1003:16, 0x0057:64, 0x1:16, 0x06:48, // W
      0x1003:16, 0x006f:64, 0x1:16, 0x07:48, // o
      0x1003:16, 0x0072:64, 0x1:16, 0x08:48, // r
      0x1003:16, 0x006c:64, 0x1:16, 0x09:48, // l
      0x1003:16, 0x0064:64, 0x1:16, 0x0a:48, // d
      0xffff:16,
    >>,
  ))

  start()

  stop_after(50 * dt)
  sys
}

pub fn test_asm_program() {
  let dt = 100
  let #(sys, start, stop_after) =
    file_executing_system(256 * 256, "./asm/example-asm.o", dt)

  start()

  stop_after(50 * dt)

  sys
}

pub fn test_memory() {
  let mem = memory.new(1024)
  assert Ok(data) =
    mem
    |> memory.put(
      0x0,
      <<
        0x1033:16, 0x190:64, 0x198:64, // MOVMM
        0x1033:16, 0x198:64, 0x1a0:64, // MOVMM 
        0x2030:16, 0x198:64, 0x198:64, // ADDML
        0x1013:16, 0x000:64, 0x1a0:64, // MOVAM
        0xffff:16,
      >>,
    )
    |> memory.read(288 + 128, 16)
  //assert <<a:256>> = data
  data
  |> imported.bitstring_to_hex_string
}

pub fn test_files() {
  imported.read_binfile("./asm/example-asm.o")
}

pub fn test_binary() {
  let <<a:5>> = <<0:1, 0:1, 0:1, 0:1, 0:1>>
  a
}

pub fn test_utf() {
  let bin = <<0x41:64>>
  assert Ok(str) = bit_string.to_string(bin)
  io.println(str)
}
