(** Human-readable strings for numbers, file sizes, lists, nouns, and relative
    time spans. *)

val intcomma : int -> string
(** Format an integer with comma separators every three digits. *)

val ordinal : int -> string
(** Format an integer as an ordinal, for example [1st] or [102nd]. *)

val intword : ?format:string -> float -> string
(** Format a large number with a named magnitude, for example [1.2 million]. *)

val numberword : int -> string
(** Convert a non-negative integer to English words. *)

val filesize : ?binary:bool -> ?format:string -> int64 -> string
(** Format a byte count using decimal units by default, or binary units when
    [binary] is true. *)

val truncate : ?suffix:string -> string -> int -> string
(** Truncate a string to the requested total length, including the suffix. *)

val pluralize_noun : int -> string -> string
(** Return the singular noun when count is [1], otherwise return its plural. *)

val add_pluralize_noun_rule :
  ?description:string -> (string -> bool) -> (string -> string) -> unit
(** Add a runtime pluralization rule. Custom rules run before the built-in
    fallback rule. *)

val add_pluralize_noun_exceptions :
  ?description:string -> (string * string) list -> unit
(** Add runtime pluralization exceptions as [(singular, plural)] pairs. *)

val oxford :
  ?maximum_display:int ->
  ?truncate_noun:string ->
  ?number_format:(int -> string) ->
  string list ->
  string
(** Format a list with English list punctuation and optional truncation. *)

val space_list_format : string list -> string
(** Join strings with a single space. *)

val duration :
  ?number_format:(int -> string) ->
  ?list_format:(string list -> string) ->
  ?short_text:string ->
  int64 ->
  string
(** Format a duration in milliseconds as years, months, weeks, days, hours,
    minutes, and seconds. *)

val datetime : now:int64 -> ?suffix:string -> ?prefix:string -> int64 -> string
(** Format a timestamp in seconds relative to [now]. *)

val relative_datetime :
  now:int64 ->
  ?suffix:string ->
  ?prefix:string ->
  ?number_format:(int -> string) ->
  ?max_terms:int ->
  ?short_text:string ->
  ?list_format:(string list -> string) ->
  ?brief:bool ->
  int64 ->
  string
(** Format a timestamp as a truncated relative duration. *)
