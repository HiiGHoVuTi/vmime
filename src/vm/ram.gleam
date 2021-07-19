import vm/memory.{Memory}
import vm/messages
import vm/imported
import gleam/otp/actor
import gleam/otp/process
import gleam/bit_string
import gleam/result
import gleam/io
import gleam/string

pub type State {
  State(memory: Memory)
}

pub fn initial(size: Int) -> State {
  State(memory: memory.new(size))
}

pub fn handle(msg: messages.RAM, state: State) {
  case msg {
    messages.Write(position, data) -> {
      let new_memory =
        state.memory
        |> memory.put(position, data)
      io.println(
        new_memory.data
        |> imported.bitstring_to_hex_string
        |> string.append("State:\n", _),
      )
      actor.Continue(State(memory: new_memory))
    }
    messages.Read(position, length, bus) -> {
      let data =
        state.memory
        |> memory.read(position, length)
        |> result.unwrap(or: imported.bitstring_copy(<<1:8>>, length / 8))
      process.send(bus, data)
      actor.Continue(state)
    }
  }
}
