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

pub fn execute(state: State, instruction: BitString) -> State {
  let <<instruction:8, variant:bit_string>> = instruction
  case instruction {
    0x10 -> {
      // MOV - 0x10FT
      let <<from_t:4, to_t:4>> = variant
      let #(istate, <<from_v:64, to_v:64>>) = fetch(state, 128)
      let data = case from_t {
        0x0 -> <<from_v:64>>
        0x1 -> read_register(istate, "acc")
        0x2 -> read_register(istate, string.append("r", int.to_string(from_v)))
        0x3 -> read_ram(istate, from_v, 64)
      }
      case to_t {
        0x1 -> set_register(istate, "acc", data)
        0x2 ->
          set_register(istate, string.append("r", int.to_string(to_v)), data)
        0x3 -> write_ram(istate, to_v, data)
      }
    }
    // ADD - 0x20AB
    0x20 -> {
      let <<a_t:4, b_t:4>> = variant
      let #(istate, <<a_l:64, b_l:64>>) = fetch(state, 128)
      let <<a_v:64>> = case a_t {
        0x0 -> <<a_l:64>>
        0x1 -> read_register(istate, "acc")
        0x2 -> read_register(istate, string.append("r", int.to_string(a_l)))
        0x3 -> read_ram(istate, a_l, 64)
      }
      let <<b_v:64>> = case b_t {
        0x0 -> <<b_l:64>>
        0x1 -> read_register(istate, "acc")
        0x2 -> read_register(istate, string.append("r", int.to_string(b_l)))
        0x3 -> read_ram(istate, b_l, 64)
      }
      let res = a_v + b_v
      set_register(istate, "acc", <<res:64>>)
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
