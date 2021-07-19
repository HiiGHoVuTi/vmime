import gleam/otp/process

pub type Processes(a) =
  List(process.Sender(a))
