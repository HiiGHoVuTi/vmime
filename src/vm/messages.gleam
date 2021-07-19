import gleam/otp/process
import gleam/bit_string

pub type CPU {
  ExecutionStep
}

pub type System {
  ClockCycle
  AddCPU(process.Sender(CPU))
  AddRAM(process.Sender(RAM))
  ReadRAMAddress(position: Int, length: Int, bus: process.Sender(BitString))
  WriteRAMAddress(position: Int, data: BitString)
  Stop
}

pub type RAM {
  Write(position: Int, data: BitString)
  Read(position: Int, length: Int, bus: process.Sender(BitString))
}
