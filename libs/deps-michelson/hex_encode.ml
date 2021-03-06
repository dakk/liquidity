
(* From OCaml's stdlib. See [Digest.to_hex] *)
let gen_encode length get s =
  let n = length s in
  let result = Bytes.create (n*2) in
  for i = 0 to n-1 do
    Bytes.blit_string (Printf.sprintf "%02x" (get s i)) 0 result (2*i) 2;
  done;
  Bytes.unsafe_to_string result

let hex_of_bytes = gen_encode MBytes.length MBytes.get_uint8
let hex_encode = gen_encode String.length (fun s i -> int_of_char s.[i])

(* From OCaml's stdlib. See [Digest.from_hex]. *)
let gen_decode create set h =
  let n = String.length h in
  if n mod 2 <> 0 then
    Printf.kprintf invalid_arg "hex_decode: %S" h;
  let digit c =
    match c with
    | '0'..'9' -> int_of_char c - int_of_char '0'
    | 'A'..'F' -> int_of_char c - int_of_char 'A' + 10
    | 'a'..'f' -> int_of_char c - int_of_char 'a' + 10
    | c -> Printf.kprintf invalid_arg "hex_decode [%c] in %S" c h
  in
  let byte i = digit h.[i] lsl 4 + digit h.[i+1] in
  let result = create (n / 2) in
  for i = 0 to n/2 - 1 do
    set result i (byte (2 * i));
  done;
  result

let hex_decode s =
  gen_decode Bytes.create (fun s i c -> Bytes.set s i (char_of_int c)) s |>
  Bytes.unsafe_to_string

let bytes_of_hex s =
  gen_decode MBytes.create MBytes.set_int8 s
