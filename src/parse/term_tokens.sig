local
  open monadic_parse
in
  datatype 'a term_token =
    Ident of string | Antiquote of 'a | Numeral of (string * char option)

  exception LEX_ERR of string

  val lex :
    string list -> (unit -> string list) -> ('a term_token, 'a frag) Parser

  val token_string : 'a term_token -> string
  val dest_aq : 'a term_token -> 'a
  val is_ident : 'a term_token -> bool
  val is_aq : 'a term_token -> bool

end

