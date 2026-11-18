module H = Humanize

let failures = ref []

let check name expected actual =
  if expected <> actual then
    failures :=
      Printf.sprintf "%s: expected %S, got %S" name expected actual :: !failures

let () =
  check "intcomma" "1,000,000" (H.intcomma 1_000_000);
  check "filesize binary" "2.9MiB" (H.filesize ~binary:true 3_000_000L);
  check "duration" "three hours, five seconds" (H.duration 10_805_000L);
  check "relative_datetime" "in two hours, two minutes"
    (H.relative_datetime ~now:1_000_000L 1_007_323L);
  match List.rev !failures with
  | [] -> ()
  | failures ->
      List.iter prerr_endline failures;
      exit 1
