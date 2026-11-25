open Cli_effect.Infix

type auth_data = {
  provider : string;
  id_token : string option;
  access_token : string option;
  refresh_token : string option;
  expires_at : Js.Date.t option;
  sub : string option;
  email : Cli_primitive.email option;
  updated_at : Js.Date.t;
}

type login_result = {
  auth_path : Cli_primitive.path;
  email : Cli_primitive.email option;
  sub : string option;
  updated_at : Js.Date.t;
}

type logout_result = { auth_path : Cli_primitive.path; deleted : bool }

let default_auth_path () =
  Filename.concat
    (Filename.concat
       (Sys.getenv_opt "HOME" |> Option.value ~default:".")
       "blocklog")
    "auth.json"

let auth_path config =
  Option.value config.Cli_config.auth_path ~default:(default_auth_path ())

let rec mkdir_p path =
  if path = "" || path = Filename.dirname path || Cli_unix.file_exists path then
    ()
  else (
    mkdir_p (Filename.dirname path);
    Cli_unix.mkdir path 0o755)

let read_file = Cli_unix.read_text_file

let auth_json data =
  let object_ = Js.Dict.empty () in
  let set_string key value = Js.Dict.set object_ key (Js.Json.string value) in
  let set_int key value =
    Js.Dict.set object_ key (Js.Json.number (Int64.to_float value))
  in
  let set_opt_string key = Option.iter (set_string key) in
  let set_opt_time key =
    Option.iter (fun value -> set_int key (Time.time_to_epoch_ms value))
  in
  set_string "provider" data.provider;
  set_int "updated-at" (Time.time_to_epoch_ms data.updated_at);
  set_opt_string "id-token" data.id_token;
  set_opt_string "access-token" data.access_token;
  set_opt_string "refresh-token" data.refresh_token;
  set_opt_time "expires-at" data.expires_at;
  set_opt_string "sub" data.sub;
  set_opt_string "email" data.email;
  Js.Json.stringify (Js.Json.object_ object_) ^ "\n"

let first_string_field object_ keys =
  keys |> Vec.find_map (Json_util.string_field object_)

let first_int64_field object_ keys =
  keys |> Vec.find_map (Json_util.int64_field object_)

let parse_auth_json text =
  let object_ = Json_util.object_of_json_string text in
  let id_token =
    Option.bind object_ (fun object_ ->
        first_string_field object_ (Vec.of_array [| "id-token"; "id_token" |]))
  in
  let access_token =
    Option.bind object_ (fun object_ ->
        first_string_field object_
          (Vec.of_array [| "access-token"; "access_token" |]))
  in
  let refresh_token =
    Option.bind object_ (fun object_ ->
        first_string_field object_
          (Vec.of_array [| "refresh-token"; "refresh_token" |]))
  in
  let provider =
    Option.bind object_ (fun object_ ->
        first_string_field object_ (Vec.singleton "provider"))
  in
  match (provider, id_token, access_token, refresh_token) with
  | None, None, None, None ->
      Error (Error.make Error.Invalid_auth_file "invalid auth file")
  | _, _, _, _ ->
      let provider = Option.value provider ~default:"selfhost" in
      Ok
        {
          provider;
          id_token;
          access_token;
          refresh_token;
          expires_at =
            Option.bind object_ (fun object_ ->
                Option.map Time.time_of_epoch_ms
                  (first_int64_field object_
                     (Vec.of_array [| "expires-at"; "expires_at" |])));
          sub =
            Option.bind object_ (fun object_ ->
                first_string_field object_ (Vec.singleton "sub"));
          email =
            Option.bind object_ (fun object_ ->
                first_string_field object_ (Vec.singleton "email"));
          updated_at =
            Option.value
              (Option.bind object_ (fun object_ ->
                   Option.map Time.time_of_epoch_ms
                     (first_int64_field object_
                        (Vec.of_array [| "updated-at"; "updated_at" |]))))
              ~default:Time.epoch;
        }

let jwt_payload token =
  let parts = Vec.split_on_char '.' token in
  if Vec.length parts = 3 then
    Ok (Cli_platform.Crypto.base64url_decode (Vec.nth parts 1))
  else Error (Error.make Error.Invalid_auth_token "invalid auth token")

let claims_of_id_token id_token =
  Error.bind (jwt_payload id_token) (fun payload ->
      let object_ = Json_util.object_of_json_string payload in
      Ok
        ( Option.bind object_ (fun object_ ->
              first_string_field object_ (Vec.singleton "sub")),
          Option.bind object_ (fun object_ ->
              first_string_field object_ (Vec.singleton "email")),
          Option.bind object_ (fun object_ ->
              Option.map
                (fun exp -> Time.time_of_epoch_ms (Int64.mul exp 1_000L))
                (first_int64_field object_ (Vec.singleton "exp"))) ))

let auth_path_context path =
  Edn_util.map_vec
    (Vec.of_array [| (Edn_util.keyword "auth-path", Edn_util.string path) |])

let read_auth_file config =
  let path = auth_path config in
  Cli_effect.pure
    (if not (Cli_unix.file_exists path) then Ok None
     else
       try Error.map (fun data -> Some data) (parse_auth_json (read_file path))
       with exn ->
         Error
           (Error.make ~context:(auth_path_context path) Error.Invalid_auth_file
              (Printexc.to_string exn)))

let write_auth_file config data =
  let path = auth_path config in
  Cli_effect.pure
    (try
       mkdir_p (Filename.dirname path);
       Cli_unix.write_text_file path (auth_json data);
       (try Cli_unix.chmod path 0o600 with Cli_unix.Cli_unix_error _ -> ());
       Ok data
     with exn ->
       Error
         (Error.make ~context:(auth_path_context path)
            Error.Auth_file_write_failed (Printexc.to_string exn)))

let delete_auth_file config =
  let path = auth_path config in
  Cli_effect.pure
    (try
       if Cli_unix.file_exists path then Cli_unix.remove_tree path;
       Ok ()
     with exn ->
       Error
         (Error.make ~context:(auth_path_context path)
            Error.Auth_file_delete_failed (Printexc.to_string exn)))

let expired_auth auth =
  match auth.expires_at with
  | Some expires_at -> Time.compare_time expires_at (Time.now ()) <= 0
  | None -> true

let login_hint = "Run `logseq login --token <token>` first."

let missing_auth config message =
  Error.make ~hint:login_hint
    ~context:(auth_path_context (auth_path config))
    Error.Missing_auth message

let config_auth config =
  if
    Option.is_some config.Cli_config.id_token
    || Option.is_some config.access_token
    || Option.is_some config.refresh_token
  then
    Some
      {
        provider = "selfhost";
        id_token = config.id_token;
        access_token = config.access_token;
        refresh_token = config.refresh_token;
        expires_at = None;
        sub = None;
        email = None;
        updated_at = Time.now ();
      }
  else None

let resolve_auth config =
  match config_auth config with
  | Some auth -> Cli_effect.pure (Ok auth)
  | None -> (
      read_auth_file config >>= function
      | Error err -> Cli_effect.pure (Error err)
      | Ok None -> Cli_effect.pure (Error (missing_auth config "missing auth"))
      | Ok (Some auth) ->
          (* Sign-in tokens are never refreshed: an expired one must be replaced. *)
          if expired_auth auth then
            Cli_effect.pure (Error (missing_auth config "auth token expired"))
          else Cli_effect.pure (Ok auth))

let invalid_token message = Error.make Error.Invalid_auth_token message

let token_auth token =
  match (try claims_of_id_token token with _ -> Error (invalid_token "")) with
  | Error _ -> Error (invalid_token "invalid auth token")
  | Ok (None, _, _) -> Error (invalid_token "auth token has no sub claim")
  | Ok (_, _, None) -> Error (invalid_token "auth token has no exp claim")
  | Ok (sub, email, (Some exp as expires_at)) ->
      if Time.compare_time exp (Time.now ()) <= 0 then
        Error (invalid_token "auth token is expired")
      else
        (* The token is stored in all three slots, as the desktop app does:
           the E2EE password saved on a device is encrypted with the
           refresh token. *)
        Ok
          {
            provider = "selfhost";
            id_token = Some token;
            access_token = Some token;
            refresh_token = Some token;
            expires_at;
            sub;
            email;
            updated_at = Time.now ();
          }

let login config token =
  match token_auth token with
  | Error err -> Cli_effect.pure (Error err)
  | Ok data -> (
      write_auth_file config data >>= function
      | Error err -> Cli_effect.pure (Error err)
      | Ok data ->
          Cli_effect.pure
            (Ok
               {
                 auth_path = auth_path config;
                 email = data.email;
                 sub = data.sub;
                 updated_at = data.updated_at;
               }))

let logout config =
  let path = auth_path config in
  let existed = Cli_unix.file_exists path in
  delete_auth_file config >>= function
  | Error err -> Cli_effect.pure (Error err)
  | Ok () -> Cli_effect.pure (Ok { auth_path = path; deleted = existed })
