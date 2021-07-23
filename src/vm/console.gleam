import vm/messages
import vm/imported
import gleam/otp/actor
import gleam/otp/process
import gleam/bit_string
import gleam/result
import gleam/io
import gleam/int
import gleam/string

pub type State {
  State(width: Int, height: Int)
}

pub fn initial(w: Int, h: Int) -> State {
  io.print("\e[2J")
  State(w, h)
}

pub fn move_to(state: State, address: Int) {
  let x = address % state.width
  let y = address / state.height
  io.print(
    ""
    |> string.append("\e[")
    |> string.append(int.to_string(y))
    |> string.append(";")
    |> string.append(int.to_string(x + 1))
    |> string.append("H"),
  )
}

pub fn handle(msg: messages.RAM, state: State) {
  case msg {
    messages.Write(position, data) -> {
      //let new_memory =
      //  state.memory
      //  |> memory.put(position, data)
      // move to position
      move_to(state, position)
      // print text data
      let <<_:56, ord:8>> = data
      assert Ok(chr) = bit_string.to_string(<<ord>>)
      io.print(chr)
      actor.Continue(state)
    }
    messages.Read(_, _, _) -> actor.Continue(state)
  }
}
