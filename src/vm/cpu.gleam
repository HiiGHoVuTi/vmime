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
  )
}

pub fn initial(system, register_names) {
  State(
    system,
    registers: memory.new(list.length(register_names) * 64),
    register_names: register_names,
    register_map: register_names
    |> list.index_map(fn(i, e) { #(e, i * 64) })
    |> map.from_list,
  )
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
  }
}

pub fn execute(state: State, instruction: BitString) -> State {
  let <<instruction:8, variant:bit_string>> = instruction
  case instruction {
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

    // ADD - 0x20LL
    0x20 -> {
      let <<a_t:4, b_t:4>> = variant
      let #(istate, <<a_l:64, b_l:64>>) = fetch(state, 128)
      let <<a_v:64>> = read_location(istate, a_t, a_l)
      let <<b_v:64>> = read_location(istate, b_t, b_l)
      let res = a_v + b_v
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
      let <<a_t:4, b_t:4>> = variant
      let #(istate, <<a_l:64, b_l:64>>) = fetch(state, 128)
      let <<a_v:64>> = read_location(istate, a_t, a_l)
      let <<b_v:64>> = read_location(istate, b_t, b_l)
      let res = a_v - b_v
      set_register(istate, "acc", <<res:64>>)
    }

    // IJMP
    0x30 -> {
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
    // JNQ - 0x32LL
    0x32 -> {
      let <<vt:4, at:4>> = variant
      let #(istate, <<vl:64, al:64>>) = fetch(state, 128)
      let <<value:64>> = read_location(istate, vt, vl)
      let newaddr = read_location(istate, at, al)
      case value == 0 {
        True -> state
        False -> set_register(istate, "ip", newaddr)
      }
    }

    // Invalid
    _ -> {
      io.println(
        "Invalid instruction:\n"
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
      actor.Continue(execute(istate, instruction))
    }
  }
}
