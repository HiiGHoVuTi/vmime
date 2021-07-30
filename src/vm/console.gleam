import vm/messages
import vm/imported
import vm/memory.{Memory}
import gleam/otp/actor
import gleam/otp/process
import gleam/bit_string
import gleam/result
import gleam/io
import gleam/int
import gleam/string
import gleam/string_builder

pub external type OkErlangYouReAnnoying

pub external fn writeb(
  value: string_builder.StringBuilder,
) -> OkErlangYouReAnnoying =
  "io" "put_chars"

pub external fn write(value: String) -> OkErlangYouReAnnoying =
  "io" "put_chars"

pub type State {
  State(width: Int, height: Int, memory: Memory, count: Int)
}

pub fn initial(w: Int, h: Int) -> State {
  io.print("\e[2J")
  State(w, h, memory: memory.new(w * h * 8), count: 0)
}

pub fn move_to(state: State, address: Int) {
  let x = address % state.width
  let y = address / state.height
  writeb(string_builder.from_strings([
    "\e[",
    int.to_string(y + 1),
    ";",
    int.to_string(x * 2 + 1),
    "H",
  ]))
  // maybe later
  // let z = x + y
  // case z % 2 == 0 {
  //   True -> io.print("\e[0m")
  //   False -> io.print("\e[1m")
  // }
}

pub fn handle(msg: messages.RAM, state: State) {
  case msg {
    messages.Write(position, data) -> {
      let new_memory =
        state.memory
        |> memory.put(position, data)
      write("\e[1;1H")
      // write text
      let to_be_printed =
        new_memory.data
        |> bit_string.to_string()
        |> result.unwrap(or: "helo")
        |> string.to_graphemes
        |> string.join(with: " ")
      write(to_be_printed)
      // io.debug(new_memory.data)
      actor.Continue(State(..state, memory: new_memory))
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
