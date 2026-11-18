let read_file path =
  let channel = open_in path in
  Fun.protect
    ~finally:(fun () -> close_in channel)
    (fun () -> really_input_string channel (in_channel_length channel))

let contains haystack needle =
  let haystack_len = String.length haystack in
  let needle_len = String.length needle in
  let rec loop index =
    index + needle_len <= haystack_len
    && (String.sub haystack index needle_len = needle || loop (index + 1))
  in
  needle_len = 0 || loop 0

let check_absent path needle =
  let content = read_file path in
  if contains content needle then (
    prerr_endline (Printf.sprintf "%s must not contain %S" path needle);
    exit 1)

let () =
  match Array.to_list Sys.argv with
  | [ _; dune_file; implementation ] ->
      check_absent dune_file "unix";
      check_absent implementation "Unix.";
      check_absent implementation "Sys."
  | _ ->
      prerr_endline
        "Usage: test_no_unix_dependency <lib/dune> <lib/humanize.ml>";
      exit 2
