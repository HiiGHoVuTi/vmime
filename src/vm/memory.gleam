import gleam/bit_string
import gleam/bit_builder
import vm/imported
import gleam/io

pub type Memory {
  Memory(data: BitString)
}

pub fn new(size: Int) -> Memory {
  Memory(data: <<0:size(size)>>)
}

pub fn put(memory: Memory, position: Int, data: BitString) -> Memory {
  let position = position / 8
  assert Ok(left) = bit_string.part(memory.data, 0, position)
  assert Ok(right) =
    bit_string.part(
      memory.data,
      position + bit_string.byte_size(data),
      bit_string.byte_size(memory.data) - position - bit_string.byte_size(data),
    )
  Memory(data: <<left:bit_string, data:bit_string, right:bit_string>>)
}

pub fn read(
  memory: Memory,
  position: Int,
  length: Int,
) -> Result(BitString, Nil) {
  let len = bit_string.byte_size(memory.data)
  let position = position / 8 % len
  let length = case length {
    -1 -> len
    _ -> length / 8
  }

  bit_string.part(memory.data, position, length)
}
