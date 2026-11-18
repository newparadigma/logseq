module H = Humanize

let failures = ref []

let check name expected actual =
  if expected <> actual then
    failures :=
      Printf.sprintf "%s: expected %S, got %S" name expected actual :: !failures

let run name cases f =
  List.iteri
    (fun i (input, expected) ->
      check (Printf.sprintf "%s[%d]" name i) expected (f input))
    cases

let () =
  run "intcomma"
    [
      (100, "100");
      (1000, "1,000");
      (10123, "10,123");
      (10311, "10,311");
      (1000000, "1,000,000");
      (-100, "-100");
      (-10123, "-10,123");
      (-10311, "-10,311");
      (-1000000, "-1,000,000");
    ]
    H.intcomma;

  run "ordinal"
    [
      (1, "1st");
      (2, "2nd");
      (3, "3rd");
      (4, "4th");
      (11, "11th");
      (12, "12th");
      (13, "13th");
      (101, "101st");
      (102, "102nd");
      (103, "103rd");
      (111, "111th");
    ]
    H.ordinal;

  List.iteri
    (fun i (input, format, expected) ->
      let actual =
        match format with
        | None -> H.intword input
        | Some format -> H.intword ~format input
      in
      check (Printf.sprintf "intword[%d]" i) expected actual)
    [
      (100., None, "100.0");
      (1_000_000., None, "1.0 million");
      (1_200_000., None, "1.2 million");
      (1_290_000., None, "1.3 million");
      (1_000_000_000., None, "1.0 billion");
      (2_000_000_000., None, "2.0 billion");
      (6_000_000_000_000., None, "6.0 trillion");
      (1_300_000_000_000_000., None, "1.3 quadrillion");
      (3.5e21, None, "3.5 sextillion");
      (8.1e33, None, "8.1 decillion");
      (1_230_000., Some "%.2f", "1.23 million");
      (1e101, None, "10.0 googol");
    ];

  run "numberword"
    [
      (0, "zero");
      (7, "seven");
      (12, "twelve");
      (40, "forty");
      (94, "ninety-four");
      (100, "one hundred");
      (51, "fifty-one");
      (234, "two hundred and thirty-four");
      (1000, "one thousand");
      (3567, "three thousand five hundred and sixty-seven");
      (44120, "forty-four thousand one hundred and twenty");
      (25223, "twenty-five thousand two hundred and twenty-three");
      (5223, "five thousand two hundred and twenty-three");
      (1000000, "one million");
      ( 23237897,
        "twenty-three million two hundred and thirty-seven thousand eight \
         hundred and ninety-seven" );
    ]
    H.numberword;

  List.iteri
    (fun i (input, binary, format, expected) ->
      let actual =
        match (binary, format) with
        | false, None -> H.filesize input
        | true, None -> H.filesize ~binary:true input
        | false, Some format -> H.filesize ~format input
        | true, Some format -> H.filesize ~binary:true ~format input
      in
      check (Printf.sprintf "filesize[%d]" i) expected actual)
    [
      (0L, false, None, "0");
      (300L, false, None, "300.0B");
      (3000L, false, None, "3.0KB");
      (3_000_000L, false, None, "3.0MB");
      (3_005_000L, false, Some "%.3f", "3.005MB");
      (3_000_000_000L, false, None, "3.0GB");
      (3_000_000_000_000L, false, None, "3.0TB");
      (3000L, true, None, "2.9KiB");
      (3_000_000L, true, None, "2.9MiB");
      (Int64.max_int, false, None, "9.2EB");
      (Int64.max_int, true, None, "8.0EiB");
    ];

  check "truncate default length" "abcdefghijklm..."
    (H.truncate "abcdefghijklmnopqrstuvwxyz" 16);
  check "truncate custom suffix" "abcd...kidding"
    (H.truncate ~suffix:"...kidding" "abcdefghijklmnopqrstuvwxyz" 14);
  check "truncate short" "asdfghjkl" (H.truncate "asdfghjkl" 100);

  List.iteri
    (fun i (count, noun, expected) ->
      check
        (Printf.sprintf "pluralize_noun[%d]" i)
        expected
        (H.pluralize_noun count noun))
    [
      (1, "kiss", "kiss");
      (0, "kiss", "kisses");
      (2, "robot", "robots");
      (2, "ox", "oxen");
      (2, "moose", "moose");
      (2, "dish", "dishes");
      (2, "witch", "witches");
      (2, "boy", "boys");
      (2, "party", "parties");
      (2, "life", "lives");
      (2, "thief", "thieves");
      (2, "chief", "chiefs");
      (2, "roof", "roofs");
      (2, "hero", "heroes");
      (2, "cactus", "cactuses");
    ];
  H.add_pluralize_noun_exceptions [ ("die", "dice") ];
  check "pluralize_noun custom exception singular" "die"
    (H.pluralize_noun 1 "die");
  check "pluralize_noun custom exception plural" "dice"
    (H.pluralize_noun 2 "die");
  H.add_pluralize_noun_rule
    (fun noun ->
      String.length noun >= 2
      && String.sub noun (String.length noun - 2) 2 = "us")
    (fun noun -> String.sub noun 0 (String.length noun - 2) ^ "i");
  check "pluralize_noun custom rule" "fungi" (H.pluralize_noun 2 "fungus");

  let items =
    [ "apple"; "orange"; "banana"; "pear"; "pineapple"; "strawberry" ]
  in
  check "oxford empty" "" (H.oxford []);
  check "oxford one" "apple" (H.oxford [ "apple" ]);
  check "oxford two" "apple and orange" (H.oxford [ "apple"; "orange" ]);
  check "oxford three" "apple, orange, and banana"
    (H.oxford [ "apple"; "orange"; "banana" ]);
  check "oxford four" "apple, orange, banana, and pear"
    (H.oxford [ "apple"; "orange"; "banana"; "pear" ]);
  check "oxford truncated default" "apple, orange, banana, pear, and 2 others"
    (H.oxford items);
  check "oxford max two" "apple, orange, and 4 others"
    (H.oxford ~maximum_display:2 items);
  check "oxford max one" "apple and 5 others"
    (H.oxford ~maximum_display:1 items);
  check "oxford custom noun" "apple, orange, banana, pear, and 2 other fruits"
    (H.oxford ~truncate_noun:"fruit" items);
  check "oxford custom number" "apple, orange, and four others"
    (H.oxford ~maximum_display:2 ~number_format:H.numberword items);

  check "duration subsecond" "less than a second" (H.duration 999L);
  check "duration one second" "one second" (H.duration 1000L);
  check "duration compound" "three hours, five seconds"
    (H.duration 10_805_000L);
  check "duration custom short" "just now"
    (H.duration ~short_text:"just now" 999L);
  check "duration numeric" "3 hours, 5 seconds"
    (H.duration ~number_format:string_of_int 10_805_000L);
  check "duration oxford" "5 days, 21 hours, 53 minutes, and 25 seconds"
    (H.duration ~number_format:string_of_int ~list_format:H.oxford
       510_805_000L);
  check "duration beyond 31-bit int" "one year"
    (H.duration 31_536_000_000L);

  let now = 1_000_000L in
  let add_seconds seconds timestamp =
    Int64.add timestamp (Int64.of_int seconds)
  in
  let sub_seconds seconds timestamp =
    Int64.sub timestamp (Int64.of_int seconds)
  in
  check "datetime now" "a moment ago" (H.datetime ~now now);
  check "datetime past seconds" "10 seconds ago"
    (H.datetime ~now (sub_seconds 10 now));
  check "datetime future seconds" "in 10 seconds"
    (H.datetime ~now (add_seconds 10 now));
  check "datetime past minutes" "10 minutes ago"
    (H.datetime ~now (sub_seconds 600 now));
  check "datetime future hours" "in 10 hours"
    (H.datetime ~now (add_seconds (10 * 3600) now));
  check "datetime past days" "5 days ago"
    (H.datetime ~now (sub_seconds (5 * 86400) now));
  check "datetime future weeks" "in 3 weeks"
    (H.datetime ~now (add_seconds (3 * 7 * 86400) now));
  check "datetime past years" "3 years ago"
    (H.datetime ~now (sub_seconds (3 * 52 * 7 * 86400) now));
  check "datetime custom suffix" "10 minutes in the glorious past"
    (H.datetime ~now ~suffix:"in the glorious past" (sub_seconds 600 now));
  check "datetime custom prefix" "forward, into our bright future 1 year"
    (H.datetime ~now ~prefix:"forward, into our bright future"
       (add_seconds (52 * 7 * 86400) now));

  check "relative_datetime default" "in two hours, two minutes"
    (H.relative_datetime ~now (add_seconds ((2 * 3600) + (2 * 60) + 3) now));
  check "relative_datetime past" "two hours, two minutes ago"
    (H.relative_datetime
       ~now:(add_seconds ((2 * 3600) + (2 * 60) + 3) now)
       now);
  check "relative_datetime consecutive" "in two days"
    (H.relative_datetime ~now (add_seconds (2 * 86400) now));
  check "relative_datetime brief" "2h 2m ago"
    (H.relative_datetime
       ~now:(add_seconds ((2 * 3600) + (2 * 60)) now)
       ~brief:true ~list_format:H.space_list_format now);
  check "relative_datetime short" "a tick ago"
    (H.relative_datetime ~now ~short_text:"a tick" now);

  match List.rev !failures with
  | [] -> ()
  | failures ->
      List.iter prerr_endline failures;
      exit 1
