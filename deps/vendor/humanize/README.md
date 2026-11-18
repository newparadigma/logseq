# humanize

An OCaml library inspired by [clj-commons/humanize](https://github.com/clj-commons/humanize) for producing human-readable strings for numbers, file sizes, English lists, plural nouns, durations, and relative timestamps.

## Features

- `intcomma` adds thousands separators.
- `ordinal` formats numbers such as `1st`, `2nd`, and `111th`.
- `intword` formats large numbers such as `1.2 million`.
- `numberword` converts integers to English words.
- `filesize` formats decimal or binary byte sizes.
- `truncate` shortens text with a suffix.
- `oxford` formats English lists with optional truncation.
- `pluralize_noun` handles common English plural rules and runtime exceptions.
- `duration`, `datetime`, and `relative_datetime` format elapsed time.

`datetime` and `relative_datetime` accept `int64` timestamps in seconds and
require `~now` explicitly. The core library avoids `unix` and `Sys`
dependencies so it can be built for both native OCaml and Melange.
`duration` accepts an `int64` millisecond count.

## Example

```ocaml
let () =
  print_endline (Humanize.intcomma 1000000);
  print_endline (Humanize.numberword 3567);
  print_endline (Humanize.filesize ~binary:true 3000000L);
  print_endline
    (Humanize.oxford ~truncate_noun:"fruit"
       [ "apple"; "orange"; "banana"; "pear"; "pineapple" ])
```

Output:

```text
1,000,000
three thousand five hundred and sixty-seven
2.9MiB
apple, orange, banana, pear, and 1 other fruit
```

## CLI

The package also includes a small demo executable:

```sh
dune exec humanize -- intcomma 1000000
dune exec humanize -- filesize --binary 3000000
```

## Development

```sh
dune test
dune build @install @melange
```
