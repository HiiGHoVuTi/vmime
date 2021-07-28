import vm/system
import vm/messages
import vm/memory.{Memory}
import gleam/otp/actor
import gleam/otp/process
import gleam/list
import gleam/map.{Map}
import gleam/bit_string.{BitString}
import gleam/result
import gleam/string
import gleam/int
import gleam/io
import vm/imported

pub opaque type State {
  State(
    system: process.Sender(messages.System),
    registers: Memory,
    register_map: Map(String, Int),
    register_names: List(String),
    registers_size: Int,
    frame_size: Int,
  )
}

// nram is a temporary argument
pub fn initial(system, register_names, nram) {
  let stack_pos = nram - 64
  State(
    system,
    frame_size: 0,
    registers: memory.new(list.length(register_names) * 64),
    register_names: register_names,
    registers_size: list.length(register_names) * 64,
    register_map: register_names
    |> list.index_map(fn(i, e) { #(e, i * 64) })
    |> map.from_list,
  )
  // manually set the registers
  |> set_register("fp", <<stack_pos:64>>)
  |> set_register("sp", <<stack_pos:64>>)
}

pub fn read_register(state: State, regname: String) -> BitString {
  let idx =
    state.register_map
    |> map.get(regname)
    // default to acc
    |> result.unwrap(or: 1)

  state.registers
  // read a single word
  |> memory.read(idx, 64)
  |> result.unwrap(<<0:64>>)
}

pub fn set_register(state: State, regname: String, value: BitString) -> State {
  let idx =
    state.register_map
    |> map.get(regname)
    // default to acc
    |> result.unwrap(or: 1)

  let new_registers =
    state.registers
    |> memory.put(idx, value)

  State(..state, registers: new_registers)
}

pub fn read_ram(state: State, address: Int, count: Int) -> BitString {
  let #(sender, receiver) = process.new_channel()

  // fetch (always first ram for now)
  state.system
  |> process.send(messages.ReadRAMAddress(address, count, sender))

  // decode
  process.receive(receiver, 10)
  |> result.unwrap(or: imported.bitstring_copy(<<0:8>>, count / 8))
}

pub fn write_ram(state: State, address: Int, value: BitString) -> State {
  state.system
  |> process.send(messages.WriteRAMAddress(address, value))
  state
}

pub fn fetch(state: State, count: Int) -> #(State, BitString) {
  let <<instruction_address:64>> = read_register(state, "ip")

  let data = read_ram(state, instruction_address, count)

  // next
  let next_instruction_address = instruction_address + count
  let new_state = set_register(state, "ip", <<next_instruction_address:64>>)

  // io.println(
  //   ""
  //  |> string.append(int.to_string(instruction_address))
  //  |> string.append(" : ")
  //  |> string.append(imported.bitstring_to_hex_string(data)),
  //)
  #(new_state, data)
}

pub fn r_number(n: Int) -> String {
  string.append("r", int.to_string(n))
}

pub fn read_location(state: State, command: Int, value: Int) -> BitString {
  case command {
    0x0 -> <<value:64>>
    0x1 -> read_register(state, "acc")
    0x2 -> read_register(state, r_number(value))
    0x3 -> read_ram(state, value, 64)
    0x4 -> {
      let <<addr:64>> = read_register(state, r_number(value))
      read_ram(state, addr, 64)
    }
  }
}

pub fn execute(state: State, instruction: BitString) -> State {
  let <<instruction:8, variant:bit_string>> = instruction
  case instruction {
    // NOP - 0x0000
    // 0x00 -> state
    // INC - 0x010R
    0x01 -> {
      let <<_:4, r:4>> = variant
      let <<val:64>> = read_register(state, r_number(r))
      let newval = val + 1
      set_register(state, r_number(r), <<newval:64>>)
    }
    // DEC - 0x020R
    0x02 -> {
      let <<_:4, r:4>> = variant
      let <<val:64>> = read_register(state, r_number(r))
      let newval = val - 1
      set_register(state, r_number(r), <<newval:64>>)
    }
    // AND - 0x03RR
    0x03 -> {
      let <<r1:4, r2:4>> = variant
      let <<val1:64>> = read_register(state, r_number(r1))
      let <<val2:64>> = read_register(state, r_number(r2))
      let newval = imported.and(val1, val2)
      set_register(state, "acc", <<newval:64>>)
    }
    // OR - 0x04RR
    0x04 -> {
      let <<r1:4, r2:4>> = variant
      let <<val1:64>> = read_register(state, r_number(r1))
      let <<val2:64>> = read_register(state, r_number(r2))
      let newval = imported.or(val1, val2)
      set_register(state, "acc", <<newval:64>>)
    }
    // XOR - 0x05RR
    0x05 -> {
      let <<r1:4, r2:4>> = variant
      let <<val1:64>> = read_register(state, r_number(r1))
      let <<val2:64>> = read_register(state, r_number(r2))
      let newval = imported.xor(val1, val2)
      set_register(state, "acc", <<newval:64>>)
    }
    // RSH - 0x06RR
    0x06 -> {
      let <<r1:4, r2:4>> = variant
      let <<val1:64>> = read_register(state, r_number(r1))
      let <<val2:64>> = read_register(state, r_number(r2))
      let newval = imported.shift_right(val1, val2)
      set_register(state, "acc", <<newval:64>>)
    }
    // LSH - 0x07RR
    0x07 -> {
      let <<r1:4, r2:4>> = variant
      let <<val1:64>> = read_register(state, r_number(r1))
      let <<val2:64>> = read_register(state, r_number(r2))
      let newval = imported.shift_left(val1, val2)
      set_register(state, "acc", <<newval:64>>)
    }

    // MOV - 0x10FT
    0x10 -> {
      let <<from_t:4, to_t:4>> = variant
      let #(istate, <<from_v:64, to_v:64>>) = fetch(state, 128)
      let data = read_location(istate, from_t, from_v)
      case to_t {
        0x1 -> set_register(istate, "acc", data)
        0x2 -> set_register(istate, r_number(to_v), data)
        0x3 -> write_ram(istate, to_v, data)
      }
    }
    // MOVRR - 0x11RR
    0x11 -> {
      let <<a:4, b:4>> = variant
      set_register(state, r_number(b), read_register(state, r_number(a)))
    }
    // MOVOR - 0x12LR
    0x12 -> {
      let <<lt:4, r:4>> = variant
      let #(istate, <<lv:64>>) = fetch(state, 64)
      let data = read_location(istate, lt, lv)
      set_register(istate, r_number(r), data)
    }
    // MOVRO - 0x13RL
    0x13 -> {
      let <<r:4, to_t:4>> = variant
      let #(istate, <<to_v:64>>) = fetch(state, 64)
      let data = read_register(istate, r_number(r))
      case to_t {
        0x1 -> set_register(istate, "acc", data)
        0x2 -> set_register(istate, r_number(to_v), data)
        0x3 -> write_ram(istate, to_v, data)
      }
    }
    // MOVAO - 0x140L
    0x14 -> {
      let <<_r:4, to_t:4>> = variant
      let #(istate, <<to_v:64>>) = fetch(state, 64)
      let data = read_register(istate, "acc")
      case to_t {
        0x1 -> set_register(istate, "acc", data)
        0x2 -> set_register(istate, r_number(to_v), data)
        0x3 -> write_ram(istate, to_v, data)
      }
    }
    // MOVAR - 0x150R
    0x15 -> {
      let <<_r:4, r:4>> = variant
      let data = read_register(state, "acc")
      set_register(state, r_number(r), data)
    }
    // GTH - 0x16RR
    0x16 -> {
      let <<a:4, b:4>> = variant
      let data = read_location(state, 0x4, a)
      set_register(state, r_number(b), data)
    }

    // RELP - 0x18VL
    0x18 -> {
      let <<v:4, _vt:4>> = variant
      case v {
        0x0 -> {
          let #(istate, <<offset:64>>) = fetch(state, 64)
          let <<position:64>> = read_register(istate, "sp")
          let data = read_ram(istate, position + offset, 64)
          set_register(istate, "acc", data)
        }
      }
    }

    // PSH - 0x1AVV
    0x1a -> {
      let <<mode:4, t:4>> = variant
      let #(istate, data) = case mode {
        0x0 -> {
          let #(istate, <<l:64>>) = fetch(state, 64)
          #(istate, read_location(istate, t, l))
        }
        0x1 -> #(state, read_register(state, r_number(t)))
      }
      let <<addr:64>> = read_register(istate, "sp")
      let newaddr = addr - 64
      let nstate =
        write_ram(set_register(istate, "sp", <<newaddr:64>>), addr, data)
      State(..nstate, frame_size: nstate.frame_size + 64)
    }
    // POP - 0x1FVV
    0x1f -> {
      let <<mode:4, _t:4>> = variant
      let <<stack_addr:64>> = read_register(state, "sp")
      let newaddr = stack_addr + 64
      let istate = set_register(state, "sp", <<newaddr:64>>)
      let data = read_ram(istate, newaddr, 64)
      let nstate = case mode {
        0x2 -> set_register(istate, "acc", data)
      }
      State(..nstate, frame_size: nstate.frame_size - 64)
    }

    // ADD - 0x20LL
    0x20 -> {
      let <<at:4, bt:4>> = variant
      let #(istate, <<al:64, bl:64>>) = fetch(state, 128)
      let <<av:64>> = read_location(istate, at, al)
      let <<bv:64>> = read_location(istate, bt, bl)
      let res = av + bv
      set_register(istate, "acc", <<res:64>>)
    }
    // ADDRR - 0x21RR
    0x21 -> {
      let <<r1:4, r2:4>> = variant
      let <<a:64>> = read_register(state, r_number(r1))
      let <<b:64>> = read_register(state, r_number(r2))
      let res = a + b
      set_register(state, "acc", <<res:64>>)
    }
    // SUB - 0x22LL
    0x22 -> {
      let <<at:4, bt:4>> = variant
      let #(istate, <<al:64, bl:64>>) = fetch(state, 128)
      let <<av:64>> = read_location(istate, at, al)
      let <<bv:64>> = read_location(istate, bt, bl)
      let res = av - bv
      set_register(istate, "acc", <<res:64>>)
    }

    // IJMP
    0x33 -> {
      let <<mod:4, vt:4>> = variant
      let #(istate, <<vl:64>>) = fetch(state, 64)
      let newaddr = read_location(istate, vt, vl)
      let <<value:64>> = read_register(istate, "acc")
      case mod {
        0x1 ->
          case value == 0 {
            True -> istate
            False -> set_register(istate, "ip", newaddr)
          }
      }
    }
    // JNQ - 0x35LL
    0x35 -> {
      let <<vt:4, at:4>> = variant
      let #(istate, <<vl:64, al:64>>) = fetch(state, 128)
      let <<value:64>> = read_location(istate, vt, vl)
      let newaddr = read_location(istate, at, al)
      case value == 0 {
        True -> state
        False -> set_register(istate, "ip", newaddr)
      }
    }
    // JMP - 0x390L
    0x39 -> {
      let <<_:4, vt:4>> = variant
      let #(istate, <<vl:64>>) = fetch(state, 64)
      let <<value:64>> = read_location(istate, vt, vl)
      set_register(istate, "ip", <<value:64>>)
    }

    // CAL - 0x3A0R
    0x3a -> {
      let <<_r:4, r:4>> = variant
      let <<addr:64>> = read_register(state, "sp")
      let newaddr = addr - 64 - state.registers_size
      let istate =
        write_ram(
          state,
          newaddr,
          <<state.frame_size:64, state.registers.data:bit_string>>,
        )
      let future_addr = newaddr - 64
      let nstate =
        istate
        |> set_register("fp", read_register(istate, "sp"))
        |> set_register("sp", <<future_addr:64>>)
      let <<dest:64>> = read_register(nstate, r_number(r))
      let fstate = set_register(nstate, "ip", <<dest:64>>)
      State(..fstate, frame_size: 0)
    }
    // RET - 0x3F0L
    0x3f -> {
      let <<_a:4, vt:4>> = variant
      let <<addr:64>> = read_register(state, "fp")
      let #(istate, <<vl:64>>) = fetch(state, 64)
      let <<acc:64>> = read_location(istate, vt, vl)
      let nstate = set_register(istate, "sp", <<addr:64>>)
      let <<frame_size:64, register_data:bit_string>> =
        read_ram(
          nstate,
          addr - state.registers_size - 64,
          state.registers_size + 64,
        )
      let new_frame = addr + frame_size
      let fstate =
        State(..nstate, registers: Memory(register_data))
        |> set_register("fp", <<new_frame:64>>)
        |> set_register("acc", <<acc:64>>)
      State(..fstate, frame_size: 0)
    }

    // Invalid
    _ -> {
      io.println(
        "\e[35;0HInvalid instruction:\n"
        |> string.append(
          <<instruction:16>>
          |> imported.bitstring_to_hex_string,
        ),
      )
      // to remove later
      state.system
      |> process.send(messages.Stop)
      state
    }
  }
}

pub fn handle(msg: messages.CPU, state: State) {
  case msg {
    messages.ExecutionStep -> {
      let #(istate, instruction) = fetch(state, 16)
      let fstate = execute(istate, instruction)
      //print_register_data(fstate)
      actor.Continue(fstate)
    }
  }
}

pub fn print_register_data(state: State) {
  io.println(
    state.registers.data
    |> imported.bitstring_to_list
    |> list.index_map(fn(i, e) { #(i, e) })
    |> list.chunk(fn(ie) {
      let #(i, _) = ie
      i / 8
    })
    |> list.index_map(fn(i, iel) {
      iel
      |> list.map(fn(ie) {
        let #(_, e) = ie
        e
        |> int.to_base_string(16)
        |> string.pad_left(to: 2, with: "0")
      })
      |> string.join("-")
      |> string.append(": $", _)
      |> string.append(
        string.pad_right(
          state.register_names
          |> list.at(i)
          |> result.unwrap(or: "undefined"),
          3,
          " ",
        ),
        _,
      )
    })
    |> string.join("\n")
    |> string.append("\nRegisters:\n", _),
  )
}
