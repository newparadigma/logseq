let usage () =
  prerr_endline
    "Usage:\n\
    \  humanize intcomma <int>\n\
    \  humanize ordinal <int>\n\
    \  humanize numberword <int>\n\
    \  humanize intword <float>\n\
    \  humanize filesize [--binary] <bytes>";
  exit 2

let () =
  match Array.to_list Sys.argv with
  | [ _; "intcomma"; value ] ->
      value |> int_of_string |> Humanize.intcomma |> print_endline
  | [ _; "ordinal"; value ] ->
      value |> int_of_string |> Humanize.ordinal |> print_endline
  | [ _; "numberword"; value ] ->
      value |> int_of_string |> Humanize.numberword |> print_endline
  | [ _; "intword"; value ] ->
      value |> float_of_string |> Humanize.intword |> print_endline
  | [ _; "filesize"; value ] ->
      value |> Int64.of_string |> Humanize.filesize |> print_endline
  | [ _; "filesize"; "--binary"; value ] ->
      value |> Int64.of_string
      |> Humanize.filesize ~binary:true
      |> print_endline
  | _ -> usage ()
