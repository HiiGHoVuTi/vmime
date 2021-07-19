import gleam/int
import gleam/string
import gleam/list
import gleam/bit_string
import gleam/float

pub external fn bitstring_copy(subject: BitString, n: Int) -> BitString =
  "binary" "copy"

pub external fn bitstring_to_list(subject: BitString) -> List(Int) =
  "binary" "bin_to_list"

pub external fn rand_uniform(n: Int) -> Int =
  "rand" "uniform"

pub fn int_to_hex_string(n: Int) -> String {
  string.append("0x", int.to_base_string(n, 16))
}

pub fn bitstring_to_hex_string(subject: BitString) -> String {
  subject
  |> bitstring_to_list
  |> list.map(int.to_base_string(_, 16))
  |> list.map(string.pad_left(_, to: 2, with: "0"))
  |> string.join("-")
  |> string.append("$", _)
}

pub fn bitstring_to_word_string(subject: BitString) -> List(String) {
  subject
  |> bitstring_to_list
  |> list.index_map(fn(i, e) { #(i, e) })
  |> list.chunk(fn(ie) {
    let #(i, _) = ie
    i / 8
  })
  |> list.map(fn(iel) {
    "$"
    |> string.append(
      iel
      |> list.map(fn(ie) {
        let #(_, n) = ie
        int.to_base_string(n, 16)
        |> string.pad_left(to: 2, with: "0")
      })
      |> string.join(with: ""),
    )
  })
}
