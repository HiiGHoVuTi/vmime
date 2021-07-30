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

pub fn preloaded_program(size: Int, path: String) -> State {
  assert Ok(program) = imported.read_binfile(path)
  let mem =
    memory.new(size)
    |> memory.put(0, program)
  State(memory: mem)
}

pub fn handle(msg: messages.RAM, state: State) {
  case msg {
    messages.Write(position, data) -> {
      let new_memory =
        state.memory
        |> memory.put(position, data)
      actor.Continue(State(memory: new_memory))
    }
    messages.Read(position, length, bus) -> {
      let data =
        state.memory
        |> memory.read(position, length)
        |> result.unwrap(or: <<0:size(length)>>)
      process.send(bus, data)
      actor.Continue(state)
    }
  }
}
