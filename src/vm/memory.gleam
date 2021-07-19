import gleam/bit_string
import gleam/bit_builder
import vm/imported

pub type Memory {
  Memory(data: BitString)
}

pub fn new(size: Int) -> Memory {
  Memory(data: imported.bitstring_copy(<<0:8>>, size / 8))
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
  let position = position / 8 % bit_string.byte_size(memory.data)
  let length = length / 8

  bit_string.part(memory.data, position, length)
}
