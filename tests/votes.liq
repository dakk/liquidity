(* Smart contract for voting. Winners of vote split the contract
   balance at the end of the voting period. *)

(** Type of storage for this contract *)
type storage = {
  voters : (address, unit) big_map; (** Used to register voters *)
  votes : (string, nat) map; (** Keep track of vote counts *)
  addresses : (string, key_hash) map; (** Addresses for payout *)
  deadline : timestamp; (** Deadline after which vote closes *)
}

(** Initial storage *)
let%init storage addresses = {
  (* Initialize vote counts to zero *)
  votes = Map.fold (fun ((name, _kh), votes) ->
      Map.add name 0p votes
    ) addresses Map;
  addresses;
  voters = BigMap ; (* No voters *)
  deadline = Current.time () + 3600 * 24 (* 1 day from now *)
}

(** Entry point for voting.
    @param choice A string corresponding to the candidate *)
let%entry vote choice storage =
  (* Only allowed while voting period is ongoing *)
  if Current.time () > storage.deadline then failwith "Voting closed";
  (* Voter must send at least 5tz to vote *)
  if Current.amount () < 5.00tz then
    failwith "Not enough money, at least 5tz to vote";
  (* Voter cannot vote twice *)
  if Map.mem (Current.sender ()) storage.voters then
    failwith ("Has already voted", Current.sender ());
  let votes = storage.votes in
  match Map.find choice votes with
  | None ->
    (* Vote must be for an existing candidate *)
    failwith ("Bad vote", choice)
  | Some x ->
    (* Increase vote count for candidate *)
    let storage = storage.votes <- Map.add choice (x + 1p) votes in
    (* Register voter *)
    let storage =
      storage.voters <- Map.add (Current.sender ()) () storage.voters in
    (* Return updated storage *)
    ([], storage)

(* Auxiliary function : returns the list of candidates with the
   maximum number of votes (there can be more than one in case of
   draw). *)
let find_winners votes =
  let winners, _max =
    Map.fold (fun ((name, nb), (winners, max)) ->
        if nb = max then
          name :: winners, max
        else if nb > max then
          [name], nb
        else winners, max
      ) votes ([], 0p) in
  winners

(** Entry point for paying winning candidates. *)
let%entry payout () storage =
  (* Only allowed once voting period is over *)
  if Current.time () <= storage.deadline then failwith "Voting ongoing";
  (* Indentify winners of vote *)
  let winners = find_winners storage.votes in
  (* Balance of contract is split equally between winners *)
  let amount = match Current.balance () / List.length winners with
    | None -> failwith "No winners"
    | Some (v, _rem) -> v in
  (* Generate transfer operations *)
  let operations = List.map (fun name ->
      let dest = match Map.find name storage.addresses with
        | None -> failwith () (* This cannot happen *)
        | Some d -> d in
      Account.transfer ~amount ~dest
    ) winners in
  (* Return list of operations. Storage is unchanged *)
  operations, storage
