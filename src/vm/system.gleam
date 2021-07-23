import vm/ram
import vm/messages
import gleam/otp/actor
import gleam/otp/process
import gleam/list
import gleam/result
import gleam/io
import gleam/int
import helpers.{Processes}
import clock

pub opaque type State {
  State(cpus: Processes(messages.CPU), rams: Processes(messages.RAM))
}

pub fn to_timer_sender(
  sender: process.Sender(messages.System),
) -> process.Sender(clock.Message) {
  process.map_sender(sender, fn(_) { messages.ClockCycle })
}

pub fn get_ram_device(state: State, query: Int) -> process.Sender(messages.RAM) {
  let <<t:4, _:4, idx:8>> = <<query:16>>
  // actually take care of types later
  case t {
    0x0 -> {
      assert Ok(ram) =
        state.rams
        |> list.at(idx)
      ram
    }
  }
}

pub fn initial(
  cpus cpus: Processes(messages.CPU),
  rams rams: Processes(messages.RAM),
) {
  State(cpus, rams)
}

pub fn handle(msg: messages.System, state: State) {
  case msg {
    messages.ClockCycle -> {
      state.cpus
      |> list.map(process.send(_, messages.ExecutionStep))
      actor.Continue(state)
    }
    messages.AddCPU(cpu) ->
      actor.Continue(State(..state, cpus: [cpu, ..state.cpus]))
    messages.AddRAM(ram) ->
      actor.Continue(State(..state, rams: [ram, ..state.rams]))
    messages.ReadRAMAddress(address, length, bus) -> {
      let <<query:16, position:48>> = <<address:64>>
      process.send(
        get_ram_device(state, query),
        messages.Read(position, length, bus),
      )
      actor.Continue(state)
    }
    messages.WriteRAMAddress(address, data) -> {
      let <<query:16, position:48>> = <<address:64>>
      process.send(get_ram_device(state, query), messages.Write(position, data))
      actor.Continue(state)
    }
    messages.Stop -> {
      // completely broken
      //let _r =
      //  state.rams
      //  |> list.map(stop(_, "Stopping RAM."))
      //let _c =
      //  state.cpus
      //  |> list.map(stop(_, "Stopping CPU."))
      let _s =
        process.self()
        |> process.send_exit("Stopping System.")
      io.print("\n\n")
      actor.Continue(state)
    }
  }
}
// fn stop(x: process.Sender(a), msg) {
//  x
//  |> process.pid
//  |> process.send_exit(msg)
//}
