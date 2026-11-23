type parsed = Parsed_login of { token : string option } | Parsed_logout
type action = Login of string | Logout

include Command_spec.S with type parsed := parsed and type action := action
