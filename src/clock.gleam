import gleam/io
import gleam/list
import gleam/int
import gleam/otp/actor
import gleam/otp/process

pub type Message {
  TimeUpdate(dt: Int)
  AddNotify(actor: process.Sender(Message))
  AddSelf(actor: process.Sender(Message))
}

pub type State {
  State(
    interval: Int,
    self: Result(process.Sender(Message), Nil),
    notified: List(process.Sender(Message)),
  )
}

pub fn new(dt: Int) {
  let Ok(timer) =
    actor.start(State(interval: dt, notified: [], self: Error(Nil)), handle)
  process.send(timer, AddSelf(timer))
  timer
}

pub fn handle(msg: Message, state: State) {
  case msg {
    AddSelf(actor: self) -> actor.Continue(State(..state, self: Ok(self)))

    AddNotify(actor: newa) ->
      actor.Continue(State(..state, notified: [newa, ..state.notified]))

    TimeUpdate(..) -> {
      // other updates
      state.notified
      |> list.map(fn(actor) {
        process.send(actor, TimeUpdate(dt: state.interval))
      })
      // self update
      assert Ok(self) = state.self
      process.send_after(self, state.interval, TimeUpdate(dt: state.interval))
      actor.Continue(state)
    }
  }
}
