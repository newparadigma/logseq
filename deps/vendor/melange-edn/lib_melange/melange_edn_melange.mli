include module type of Melange_edn

val of_json : Js.Json.t -> any
val of_json_string : string -> any
val to_json : any -> Js.Json.t
val to_json_string : any -> string
