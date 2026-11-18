let format_float format value =
  Printf.sprintf (Scanf.format_from_string format "%f") value

let round_to_int value = int_of_float (floor (value +. 0.5))

let intcomma num =
  let num64 = Int64.of_int num in
  let sign = if Int64.compare num64 0L < 0 then "-" else "" in
  let digits =
    Int64.to_string
      (if Int64.compare num64 0L < 0 then Int64.neg num64 else num64)
  in
  let len = String.length digits in
  let first = len mod 3 in
  let parts = ref [] in
  if first > 0 then parts := String.sub digits 0 first :: !parts;
  let index = ref first in
  while !index < len do
    parts := String.sub digits !index 3 :: !parts;
    index := !index + 3
  done;
  sign ^ String.concat "," (List.rev !parts)

let ordinal num =
  let abs_num = abs num in
  let remainder_100 = abs_num mod 100 in
  let remainder_10 = abs_num mod 10 in
  let suffix =
    if remainder_100 = 11 || remainder_100 = 12 || remainder_100 = 13 then "th"
    else match remainder_10 with 1 -> "st" | 2 -> "nd" | 3 -> "rd" | _ -> "th"
  in
  string_of_int num ^ suffix

let human_pows =
  [
    (100., " googol");
    (33., " decillion");
    (30., " nonillion");
    (27., " octillion");
    (24., " septillion");
    (21., " sextillion");
    (18., " quintillion");
    (15., " quadrillion");
    (12., " trillion");
    (9., " billion");
    (6., " million");
    (0., "");
  ]

let intword ?(format = "%.1f") num =
  if num = 0. then format_float format 0.
  else
    let base_pow = floor (log10 (abs_float num)) in
    let base_pow, suffix =
      List.find (fun (base, _) -> base_pow >= base) human_pows
    in
    let value = num /. (10. ** base_pow) in
    format_float format value ^ suffix

let numap =
  [
    (0, "");
    (1, "one");
    (2, "two");
    (3, "three");
    (4, "four");
    (5, "five");
    (6, "six");
    (7, "seven");
    (8, "eight");
    (9, "nine");
    (10, "ten");
    (11, "eleven");
    (12, "twelve");
    (13, "thirteen");
    (14, "fourteen");
    (15, "fifteen");
    (16, "sixteen");
    (17, "seventeen");
    (18, "eighteen");
    (19, "nineteen");
    (20, "twenty");
    (30, "thirty");
    (40, "forty");
    (50, "fifty");
    (60, "sixty");
    (70, "seventy");
    (80, "eighty");
    (90, "ninety");
  ]

let word_for n = List.assoc n numap

let rec numberword num =
  let divisible_by num divisor = num mod divisor = 0 in
  match num with
  | 0 -> "zero"
  | n when n < 0 -> "minus " ^ numberword (-n)
  | n when n >= 1_000_000 ->
      if divisible_by n 1_000_000 then numberword (n / 1_000_000) ^ " million"
      else
        numberword (n / 1_000_000) ^ " million " ^ numberword (n mod 1_000_000)
  | n when n >= 1_000 ->
      if divisible_by n 1_000 then numberword (n / 1_000) ^ " thousand"
      else numberword (n / 1_000) ^ " thousand " ^ numberword (n mod 1_000)
  | n when n >= 100 ->
      if divisible_by n 100 then word_for (n / 100) ^ " hundred"
      else word_for (n / 100) ^ " hundred and " ^ numberword (n mod 100)
  | n when n < 20 -> word_for n
  | n when divisible_by n 10 -> word_for n
  | n -> word_for (n / 10 * 10) ^ "-" ^ word_for (n mod 10)

let decimal_sizes = [| "B"; "KB"; "MB"; "GB"; "TB"; "PB"; "EB"; "ZB"; "YB" |]

let binary_sizes =
  [| "B"; "KiB"; "MiB"; "GiB"; "TiB"; "PiB"; "EiB"; "ZiB"; "YiB" |]

let filesize ?(binary = false) ?(format = "%.1f") bytes =
  if Int64.equal bytes 0L then "0"
  else
    let units = if binary then binary_sizes else decimal_sizes in
    let base = if binary then 1024. else 1000. in
    let bytes_float = Int64.to_float bytes in
    let logn = round_to_int (log bytes_float) / round_to_int (log base) in
    let base_pow = min logn (Array.length units - 1) in
    let value = bytes_float /. (base ** float_of_int base_pow) in
    format_float format value ^ units.(base_pow)

let truncate ?(suffix = "...") string length =
  if String.length string <= length then string
  else
    let prefix_len = max 0 (length - String.length suffix) in
    String.sub string 0 prefix_len ^ suffix

let ends_with string suffix =
  let string_len = String.length string in
  let suffix_len = String.length suffix in
  string_len >= suffix_len
  && String.sub string (string_len - suffix_len) suffix_len = suffix

let plural_exceptions =
  [
    ("ox", "oxen");
    ("child", "children");
    ("man", "men");
    ("woman", "women");
    ("foot", "feet");
    ("tooth", "teeth");
    ("goose", "geese");
    ("mouse", "mice");
    ("person", "people");
    ("louse", "lice");
    ("chef", "chefs");
    ("cliff", "cliffs");
    ("ref", "refs");
    ("roof", "roofs");
    ("chief", "chiefs");
    ("negro", "negroes");
    ("flamingo", "flamingoes");
    ("hero", "heroes");
    ("mango", "mangoes");
    ("mosquito", "mosquitoes");
    ("potato", "potatoes");
    ("tomato", "tomatoes");
    ("tornado", "tornadoes");
    ("torpedo", "torpedoes");
    ("tuxedo", "tuxedoes");
    ("volcano", "volcanoes");
    ("zero", "zeroes");
    ("echo", "echoes");
    ("banjo", "banjoes");
    ("cactus", "cactuses");
    ("bison", "bison");
    ("buffalo", "buffalo");
    ("deer", "deer");
    ("duck", "duck");
    ("fish", "fish");
    ("moose", "moose");
    ("pike", "pike");
    ("sheep", "sheep");
    ("salmon", "salmon");
    ("trout", "trout");
    ("swine", "swine");
    ("plankton", "plankton");
    ("squid", "squid");
    ("millenium", "millennia");
  ]

let pluralize_noun_exceptions = ref plural_exceptions
let is_vowel = function 'a' | 'e' | 'i' | 'o' | 'u' -> true | _ -> false

let builtin_pluralize_noun_rules =
  [
    ( (fun noun ->
        ends_with noun "y"
        && String.length noun > 1
        && not (is_vowel noun.[String.length noun - 2])),
      fun noun -> String.sub noun 0 (String.length noun - 1) ^ "ies" );
    ( (fun noun -> List.exists (ends_with noun) [ "ss"; "x"; "z"; "ch"; "sh" ]),
      fun noun -> noun ^ "es" );
    ( (fun noun -> ends_with noun "fe"),
      fun noun -> String.sub noun 0 (String.length noun - 2) ^ "ves" );
    ( (fun noun -> ends_with noun "f" && not (ends_with noun "ff")),
      fun noun -> String.sub noun 0 (String.length noun - 1) ^ "ves" );
    ((fun _noun -> true), fun noun -> noun ^ "s");
  ]

let pluralize_noun_rules = ref []

let add_pluralize_noun_rule ?description:_ condition result =
  pluralize_noun_rules := !pluralize_noun_rules @ [ (condition, result) ]

let add_pluralize_noun_exceptions ?description:_ exceptions =
  pluralize_noun_exceptions := exceptions @ !pluralize_noun_exceptions

let pluralize_noun count noun =
  if count < 0 then invalid_arg "pluralize_noun count must be non-negative"
  else if count = 1 then noun
  else
    match List.assoc_opt noun !pluralize_noun_exceptions with
    | Some plural -> plural
    | None ->
        let rules = !pluralize_noun_rules @ builtin_pluralize_noun_rules in
        let _, result =
          List.find (fun (condition, _) -> condition noun) rules
        in
        result noun

let take n list =
  let rec loop acc n = function
    | _ when n <= 0 -> List.rev acc
    | [] -> List.rev acc
    | x :: xs -> loop (x :: acc) (n - 1) xs
  in
  loop [] n list

let oxford ?(maximum_display = 4) ?truncate_noun
    ?(number_format = string_of_int) coll =
  let len = List.length coll in
  match coll with
  | [] -> ""
  | [ item ] -> item
  | [ first; second ] when len <= maximum_display -> first ^ " and " ^ second
  | _ when len <= maximum_display ->
      let before_last = take (len - 1) coll in
      let last_item = List.nth coll (len - 1) in
      String.concat ", " before_last ^ ", and " ^ last_item
  | _ ->
      let display = take maximum_display coll in
      let remaining = len - maximum_display in
      let remaining_text = number_format remaining in
      let last_item =
        match truncate_noun with
        | None | Some "" ->
            remaining_text ^ " " ^ pluralize_noun remaining "other"
        | Some noun ->
            remaining_text ^ " other " ^ pluralize_noun remaining noun
      in
      let comma = if maximum_display = 1 then "" else "," in
      String.concat ", " display ^ comma ^ " and " ^ last_item

let default_list_format terms = String.concat ", " terms
let space_list_format strings = String.concat " " strings
let one_minute_in_seconds = 60L
let one_hour_in_seconds = 3600L
let one_day_in_seconds = 86400L
let one_week_in_seconds = 604800L
let one_month_in_seconds = 2419200L
let one_year_in_seconds = 31449600L
let one_decade_in_seconds = 314496000L
let one_century_in_seconds = 3144960000L
let one_millennia_in_seconds = 31449600000L

let abs_int64_delta first second =
  if Int64.compare first second >= 0 then Int64.sub first second
  else Int64.sub second first

let plural_count_int64 amount = if Int64.equal amount 1L then 1 else 2

let format_delta_str amount time_unit suffix prefix future_time =
  let amount_text = Int64.to_string amount in
  if future_time then
    prefix ^ " " ^ amount_text ^ " "
    ^ pluralize_noun (plural_count_int64 amount) time_unit
  else
    amount_text ^ " "
    ^ pluralize_noun (plural_count_int64 amount) time_unit
    ^ " " ^ suffix

let datetime ~now ?(suffix = "ago") ?(prefix = "in") then_time =
  let future_time = Int64.compare then_time now > 0 in
  let delta_seconds = abs_int64_delta now then_time in
  let delta_in_seconds = delta_seconds in
  let delta_in_minutes = Int64.div delta_seconds one_minute_in_seconds in
  let delta_in_hours = Int64.div delta_seconds one_hour_in_seconds in
  let delta_in_days = Int64.div delta_seconds one_day_in_seconds in
  let delta_in_weeks = Int64.div delta_seconds one_week_in_seconds in
  let delta_in_months = Int64.div delta_seconds one_month_in_seconds in
  let delta_in_years = Int64.div delta_seconds one_year_in_seconds in
  let delta_in_decades = Int64.div delta_seconds one_decade_in_seconds in
  let delta_in_centuries = Int64.div delta_seconds one_century_in_seconds in
  let delta_in_millennia = Int64.div delta_seconds one_millennia_in_seconds in
  if Int64.compare delta_in_millennia 0L > 0 then
    format_delta_str delta_in_millennia "millenium" suffix prefix future_time
  else if Int64.compare delta_in_centuries 0L > 0 then
    format_delta_str delta_in_centuries "century" suffix prefix future_time
  else if Int64.compare delta_in_decades 0L > 0 then
    format_delta_str delta_in_decades "decade" suffix prefix future_time
  else if Int64.compare delta_in_years 0L > 0 then
    format_delta_str delta_in_years "year" suffix prefix future_time
  else if Int64.compare delta_in_months 0L > 0 then
    format_delta_str delta_in_months "month" suffix prefix future_time
  else if Int64.compare delta_in_weeks 0L > 0 then
    format_delta_str delta_in_weeks "week" suffix prefix future_time
  else if Int64.compare delta_in_days 0L > 0 then
    format_delta_str delta_in_days "day" suffix prefix future_time
  else if Int64.compare delta_in_hours 0L > 0 then
    format_delta_str delta_in_hours "hour" suffix prefix future_time
  else if Int64.compare delta_in_minutes 0L > 0 then
    format_delta_str delta_in_minutes "minute" suffix prefix future_time
  else if Int64.compare delta_in_seconds 0L > 0 then
    format_delta_str delta_in_seconds "second" suffix prefix future_time
  else if future_time then prefix ^ " a moment"
  else "a moment " ^ suffix

let duration_periods =
  [
    (31_536_000_000L, "year");
    (2_678_400_000L, "month");
    (604_800_000L, "week");
    (86_400_000L, "day");
    (3_600_000L, "hour");
    (60_000L, "minute");
    (1000L, "second");
  ]

let duration_terms duration_ms all =
  let rec loop remainder terms = function
    | [] -> List.rev terms
    | (period_ms, period_name) :: more_periods ->
        if Int64.compare remainder period_ms < 0 then
          loop remainder (if all then None :: terms else terms) more_periods
        else
          let period_count = Int64.div remainder period_ms in
          let next_remainder = Int64.rem remainder period_ms in
          loop next_remainder
            (Some (period_count, period_name) :: terms)
            more_periods
  in
  loop duration_ms [] duration_periods

let default_name_format count name =
  " " ^ pluralize_noun (plural_count_int64 count) name

let combine_terms terms name_format number_format list_format =
  terms
  |> List.map (fun (period_count, period_name) ->
      number_format period_count ^ name_format period_count period_name)
  |> list_format

let format_count_int64 number_format count =
  if Int64.compare count (Int64.of_int max_int) <= 0 then
    number_format (Int64.to_int count)
  else Int64.to_string count

let duration ?(number_format = numberword) ?(list_format = default_list_format)
    ?(short_text = "less than a second") duration_ms =
  let terms = duration_terms duration_ms false in
  match List.filter_map Fun.id terms with
  | [] -> short_text
  | terms ->
      combine_terms terms default_name_format
        (format_count_int64 number_format)
        list_format

let relative_datetime ~now ?(suffix = "ago") ?(prefix = "in")
    ?(number_format = numberword) ?(max_terms = 2) ?(short_text = "a moment")
    ?(list_format = default_list_format) ?(brief = false) then_time =
  let future_time = Int64.compare then_time now > 0 in
  let delta_ms = Int64.mul (abs_int64_delta now then_time) 1000L in
  let rec drop_empty = function None :: xs -> drop_empty xs | xs -> xs in
  let rec take_consecutive acc = function
    | Some term :: xs -> take_consecutive (term :: acc) xs
    | _ -> List.rev acc
  in
  let rec take_max acc remaining = function
    | _ when remaining <= 0 -> List.rev acc
    | [] -> List.rev acc
    | x :: xs -> take_max (x :: acc) (remaining - 1) xs
  in
  let terms =
    duration_terms delta_ms true
    |> drop_empty |> take_consecutive [] |> take_max [] max_terms
  in
  let combined =
    match terms with
    | [] -> short_text
    | terms ->
        let name_format _count name =
          if brief then String.sub name 0 1 else default_name_format _count name
        in
        let number_format =
          if brief then Int64.to_string else format_count_int64 number_format
        in
        combine_terms terms name_format number_format list_format
  in
  if future_time then prefix ^ " " ^ combined else combined ^ " " ^ suffix
