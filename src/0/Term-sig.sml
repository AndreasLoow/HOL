(* ===================================================================== *)
(* FILE          : Term.sig                                              *)
(* DESCRIPTION   : Simply typed lambda terms.                            *)
(*                                                                       *)
(* AUTHOR        : (c) Konrad Slind, University of Calgary               *)
(* DATE          : August 26, 1991                                       *)
(* Modified      : September 22, 1997, Ken Larsen                        *)
(* Modified      : 1999, Bruno Barras, for explicit substitutions.       *)
(* Modified      : July 2000, Konrad Slind                               *)
(* ===================================================================== *)

signature Term =
sig

  eqtype term
  type hol_type     = Type.hol_type
  type ('a,'b)subst = ('a,'b)Lib.subst

  val empty_tmset   : term HOLset.set

  val type_of       : term -> hol_type
  val free_vars     : term -> term list
  val free_vars_lr  : term -> term list
  val FVL           : term list -> term HOLset.set
  val free_in       : term -> term -> bool
  val all_vars      : term -> term list
  val free_varsl    : term list -> term list
  val all_varsl     : term list -> term list
  val type_vars_in_term : term -> hol_type list
  val tyvar_occurs  : hol_type -> term -> bool
  val var_occurs    : term -> term -> bool
  val existsFV      : (string * hol_type -> bool) -> term -> bool
  val existsTYV     : (hol_type -> bool) -> term -> bool

  val genvar        : hol_type -> term
  val genvars       : hol_type -> int -> term list
  val variant       : term list -> term -> term
  val prim_variant  : term list -> term -> term

  val mk_var        : string * hol_type -> term
  val mk_primed_var : string * hol_type -> term
  val decls         : string -> term list
  val all_consts    : unit -> term list
  val mk_const      : string * hol_type -> term
  val prim_mk_const : {Thy:string, Name:string} -> term
  val mk_thy_const  : {Thy:string, Name:string, Ty:hol_type} -> term
  val list_mk_comb  : term * term list -> term
  val mk_comb       : term * term -> term
  val mk_abs        : term * term -> term
  val dest_var      : term -> string * hol_type
  val dest_const    : term -> string * hol_type
  val dest_thy_const: term -> {Thy:string, Name:string, Ty:hol_type}
  val dest_comb     : term -> term * term
  val dest_abs      : term -> term * term
  val is_var        : term -> bool
  val is_genvar     : term -> bool
  val is_const      : term -> bool
  val is_comb       : term -> bool
  val is_abs        : term -> bool
  val rator         : term -> term
  val rand          : term -> term
  val bvar          : term -> term
  val body          : term -> term

  val same_const    : term -> term -> bool
  val aconv         : term -> term -> bool
  val beta_conv     : term -> term
  val eta_conv      : term -> term
  val subst         : (term,term) subst -> term -> term
  val inst          : (hol_type,hol_type) subst -> term -> term

  val raw_match     : hol_type list -> term HOLset.set -> term -> term
                       -> (term,term)subst
                           * ((hol_type,hol_type)subst * hol_type list)
                       -> (term,term)subst
                            * ((hol_type,hol_type)subst * hol_type list)
  val match_term    : term -> term
                        -> (term,term)subst * (hol_type,hol_type)subst
  val match_terml   : hol_type list -> term HOLset.set -> term -> term
                        -> (term,term)subst * (hol_type,hol_type)subst
  val norm_subst    : (hol_type,hol_type)subst
                        -> (term,term)subst -> (term,term)subst

  val compare       : term * term -> order
end;
