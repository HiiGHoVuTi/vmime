import vm/memory
import vm/messages
import vm/imported
import gleam/otp/actor
import gleam/otp/process
import gleam/bit_string
import gleam/result
import gleam/io
import gleam/string
import gleam/os

pub type State {
  State
}

pub fn initial() -> State {
  State
}

pub fn handle(msg: messages.RAM, state: State) {
  case msg {
    messages.Write(_, _) -> actor.Continue(state)
    messages.Read(_, _, bus) -> {
      let data = os.system_time(os.Millisecond)
      process.send(bus, <<data:64>>)
      actor.Continue(state)
    }
  }
}
