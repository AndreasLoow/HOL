(* ========================================================================= *)
(* MAPPING BETWEEN HOL AND FIRST-ORDER LOGIC.                                *)
(* Created by Joe Hurd, October 2001                                         *)
(* ========================================================================= *)

(*
loadPath := "../mlib" :: "../normalize" :: !loadPath;
app load
["tautLib", "mlibUseful", "mlibTerm", "mlibMatch", "mlibThm", "matchTools"];
*)

(*
*)
structure folMapping :> folMapping =
struct

open HolKernel Parse boolLib;

infix THENR ## |->;
infix --> |>

type 'a pp    = 'a mlibPrint.pp;
type term1    = mlibTerm.term;
type formula1 = mlibFormula.formula;
type thm1     = mlibThm.thm;
type vars     = term list * hol_type list;

fun assert b e = if b then () else raise e;
val pinst      = matchTools.pinst;
val INST_TY    = matchTools.INST_TY;
val PINST      = matchTools.PINST;

(* ------------------------------------------------------------------------- *)
(* Chatting and error handling.                                              *)
(* ------------------------------------------------------------------------- *)

local
  open mlibUseful extraTools;
  val module = "folMapping";
in
  fun chatting l = !trace_level >= l
  fun chat s = (trace (module^": "^s); true)
  val ERR = mk_HOL_ERR module;
  fun BUG f m = Bug (f ^ ": " ^ m);
end;

(* ------------------------------------------------------------------------- *)
(* Mapping parameters.                                                       *)
(* ------------------------------------------------------------------------- *)

type parameters =
  {higher_order : bool,       (* Application is a first-order function *)
   with_types   : bool};      (* First-order terms include HOL type info *)

val defaults =
  {higher_order = false,
   with_types   = false};

fun update_higher_order f (parm : parameters) : parameters =
  let val {higher_order, with_types} = parm
  in {higher_order = f higher_order, with_types = with_types}
  end;

fun update_with_types f (parm : parameters) : parameters =
  let val {higher_order, with_types} = parm
  in {higher_order = higher_order, with_types = f with_types}
  end;

(* ------------------------------------------------------------------------- *)
(* Helper functions.                                                         *)
(* ------------------------------------------------------------------------- *)

fun uncurry3 f (x, y, z) = f x y z;

fun zipwith f =
  let
    fun z l [] [] = l
      | z l (x :: xs) (y :: ys) = z (f x y :: l) xs ys
      | z _ _ _ = raise ERR "zipwith" "lists different lengths";
  in
    fn xs => fn ys => rev (z [] xs ys)
  end;

fun possibly f x = case total f x of SOME y => y | NONE => x;

fun dest_prefix p =
  let
    fun check s = assert (String.isPrefix p s) (ERR "dest_prefix" "")
    val size_p = size p
  in
    fn s => (check s; String.extract (s, size_p, NONE))
  end;

fun is_prefix p = can (dest_prefix p);

fun mk_prefix p s = p ^ s;

val dest_prime = dest_prefix "'";
val is_prime   = is_prefix   "'";
val mk_prime   = mk_prefix   "'";

fun dest_const_name s =
  let val n = index (equal #".") (String.explode s)
  in (String.extract (s, 0, SOME n), String.extract (s, n + 1, NONE))
  end;
val is_const_name = can dest_const_name;
fun mk_const_name (t, c) = t ^ "." ^ c;

val type_vars_in_terms = foldl (fn (h, t) => union (type_vars_in_term h) t) [];

fun list_mk_conj' [] = T | list_mk_conj' l = list_mk_conj l;
fun list_mk_disj' [] = F | list_mk_disj' l = list_mk_disj l;

fun change_vars (tmG, tyG) (tmV, tyV) =
  let
    fun tyF v = let val g = tyG v in (g, v |-> g) end
    val (tyV', tyS) = unzip (map tyF tyV)
    fun tmF v = let val v' = inst tyS v val g = tmG v' in (g, v' |-> g) end
    val (tmV', tmS) = unzip (map tmF tmV)
  in
    ((tmV', tyV'), (tmS, tyS))
  end;

fun gen_alpha c f (varV, a) =
  let val (varW, sub) = c varV in (varW, f sub a) end;

fun gen_vfree_vars varP c a = (matchTools.vfree_vars varP (c a), a);

fun f THENR (g : rule) : rule = g o f;
fun REPEATR f : rule = repeat f;

fun terms_to_string tms =
  String.concat (map (fn x => "\n" ^ Parse.term_to_string x) tms) ^ "\n";

val hasTypeFn = mlibName.fromString ":"

fun remove_type (t as (mlibTerm.Fn (n, [tm, _]))) = if mlibName.equal n hasTypeFn then tm else t
  | remove_type tm = tm;

(* ------------------------------------------------------------------------- *)
(* "new" variables can be instantiated; everything else is a local constant. *)
(* ------------------------------------------------------------------------- *)

val FOL_PREFIX = "XXfolXX";

local
  val tag        = mk_prefix FOL_PREFIX;
  val untag      = dest_prefix FOL_PREFIX;
  val new_string = Int.toString o extraTools.new_int;
in
  val fake_new_tyvar = mk_vartype o mk_prime o tag;
  val new_tyvar      = fake_new_tyvar o new_string;
  val is_new_tyvar   = can (untag o dest_prime o dest_vartype);
  val fake_new_var   = mk_var o (tag ## I);
  val new_var        = fake_new_var o (new_string ## I) o pair ();
  val is_new_var     = can (untag o fst o dest_var);
end;

val all_new_tyvars =
  W (inst o map (fn v => v |-> new_tyvar ()) o type_vars_in_term);

val to_gen      = (genvar       o type_of,  (fn _ : hol_type => gen_tyvar ()));
val to_new      = (new_var      o type_of,  (fn _ : hol_type => new_tyvar ()));
val to_fake_new = (fake_new_var o dest_var,
                   fake_new_tyvar o dest_prime o dest_vartype);

fun new_free_vars x = gen_vfree_vars (is_new_var, is_new_tyvar) x;

val fresh_tyvars =
  let fun f ty = if is_new_tyvar ty then SOME (ty |-> new_tyvar ()) else NONE
  in List.mapPartial f o type_vars_in_terms
  end;

fun freshen_tyvars  tm  = inst (fresh_tyvars [tm]) tm;
fun freshenl_tyvars tms = map (inst (fresh_tyvars tms)) tms;

val new_match_type  = matchTools.vmatch_type  is_new_tyvar;
val new_unify_type  = matchTools.vunify_type  is_new_tyvar;
val new_unifyl_type = matchTools.vunifyl_type is_new_tyvar;
val new_match_ty    = matchTools.vmatch       (K false, is_new_tyvar);
val new_unify_ty    = matchTools.vunify       (K false, is_new_tyvar);
val new_unifyl_ty   = matchTools.vunifyl      (K false, is_new_tyvar);
val new_match       = matchTools.vmatch       (is_new_var, is_new_tyvar);
val new_match_uty   = matchTools.vmatch_uty   (is_new_var, is_new_tyvar);
val new_unify       = matchTools.vunify       (is_new_var, is_new_tyvar);
val new_unifyl      = matchTools.vunifyl      (is_new_var, is_new_tyvar);

(* ------------------------------------------------------------------------- *)
(* Operations on terms with floppy type variables.                           *)
(* ------------------------------------------------------------------------- *)

local
  fun sync tyS _    []           = tyS
    | sync tyS vars (tm :: work) =
    (case dest_term tm of VAR  (s, ty) =>
       if not (is_new_var tm) then sync tyS vars work else
         (case assoc1 s vars of NONE => sync tyS ((s, ty) :: vars) work
          | SOME (_, ty') => sync (new_unifyl_type tyS [(ty, ty')]) vars work)
     | COMB  (a, b) => sync tyS vars (a :: b :: work)
     | CONST _      => sync tyS vars work
     | LAMB  _      => raise ERR "sync_vars" "lambda");
in
  fun sync_vars tms = sync [] [] tms;
end;

local
  fun app s (a, b) = new_unifyl_type s [(a, b --> new_tyvar ())];
  fun iapp b (a, s) =
    let val s = app s (a, b) in (snd (dom_rng (type_subst s a)), s) end;
in
  fun prepare_mk_comb (a, b) = app (sync_vars [a, b]) (type_of a, type_of b)
  fun prepare_list_mk_comb (f, a) =
    snd (foldl (uncurry (iapp o type_of)) (type_of f, sync_vars (f :: a)) a);
end;

fun unify_mk_comb (a, b) =
  let val i = inst (prepare_mk_comb (a, b)) in mk_comb (i a, i b) end;

fun unify_list_mk_comb (f, a) =
  let val i = inst (prepare_list_mk_comb (f, a))
  in list_mk_comb (i f, map i a)
  end;

local val eq_tm = prim_mk_const {Thy = "min", Name = "="};
in fun unify_mk_eq (a, b) = unify_list_mk_comb (all_new_tyvars eq_tm, [a, b]);
end;

val freshen_mk_comb      = freshen_tyvars o unify_mk_comb;
val freshen_list_mk_comb = freshen_tyvars o unify_list_mk_comb;

fun cast_to ty tm = inst (new_match_type (type_of tm) ty) tm;

(* Quick testing
val a = mk_varconst "list.LENGTH"; type_of a;
val b = mk_varconst "x";           type_of b;
val c = unify_mk_comb (a, b);      type_of c;
try sync_vars [``LENGTH (x:'b list) <= 0``, ``x:'a``, ``HD x = 3``];
prepare_list_mk_comb (``LENGTH``, [``[3; 4]``]);
try unify_list_mk_comb (``COND``, new_tyvars [``HD x``, ``CONS x``, ``I``]);
*)

(* ------------------------------------------------------------------------- *)
(* Worker theorems for first-order proof translation.                        *)
(* ------------------------------------------------------------------------- *)

local
  val a = mk_var("a", bool)
  val b = mk_var("b", bool)
  val c = mk_var("c", bool)
  val nega = mk_neg a
  val a_th = ASSUME a
  val nega_th = ASSUME nega
  val acontr = EQ_MP (EQF_INTRO nega_th) a_th
in
(* !a. a ==> ~a ==> F`` *)
val HIDE_LITERAL = acontr |> DISCH nega |> DISCH a |> GEN a
(* !x. (~x ==> F) ==> x *)
val SHOW_LITERAL =
    MP (ASSUME (mk_imp(nega, F))) nega_th |> CCONTR a |> DISCH_ALL |> GEN a
       |> CONV_RULE (RENAME_VARS_CONV ["x"])
(* !a b. a \/ b ==> ~a ==> b *)
val INITIALIZE_CLAUSE =
    DISJ_CASES (ASSUME (mk_disj(a,b))) (CCONTR b acontr) (ASSUME b) |>
               DISCH nega |> DISCH_ALL |> GENL [a,b]
(* !a b. (~a ==> b) ==> (a \/ b) *)
val FINALIZE_CLAUSE =
  DISJ_CASES (SPEC a EXCLUDED_MIDDLE) (DISJ1 (ASSUME a) b)
             (MP (ASSUME (mk_imp(nega, b))) (ASSUME nega) |> DISJ2 a) |>
             DISCH_ALL |> GENL [a,b]
(* !a. a /\ ~a ==> F *)
val RESOLUTION = let
  val (a_th,nega_th) = CONJ_PAIR (ASSUME (mk_conj(a,nega)))
in
  acontr |> PROVE_HYP a_th |> PROVE_HYP nega_th |> DISCH_ALL |> GEN a
end
(* !a b c. ((a ==> (b = c)) /\ b) ==> ~a \/ c *)
val EQUAL_STEP = let
  val (imp, b_th) = CONJ_PAIR (ASSUME (mk_conj(mk_imp(a,mk_eq(b,c)), b)))
in
  DISJ_CASES (SPEC a EXCLUDED_MIDDLE)
             (EQ_MP (MP imp a_th) b_th |> DISJ2 nega)
             (DISJ1 (ASSUME nega) c) |> DISCH_ALL |> GENL [a,b,c]
end
(* !t. ~t \/ t *)
val EXCLUDED_MIDDLE' = ONCE_REWRITE_RULE [DISJ_COMM] EXCLUDED_MIDDLE
end

(* ------------------------------------------------------------------------- *)
(* Operations on HOL literals and clauses.                                   *)
(* ------------------------------------------------------------------------- *)

(*
val negative_literal = is_neg;

val positive_literal = not o negative_literal;

fun negate_literal lit =
  if positive_literal lit then mk_neg lit else dest_neg lit;

fun literal_atom lit = if positive_literal lit then lit else negate_literal lit;
*)

val clause_literals = strip_disj o snd o strip_forall;

(*
local
  fun atom ({higher_order, with_types} : parameters) p
fun lit_subterm parm p lit =
  if is_neg lit then (mk_neg o cast_to
  let
    val
*)

(* ------------------------------------------------------------------------- *)
(* Operations for accessing literals, which are kept on the assumption list. *)
(* ------------------------------------------------------------------------- *)

fun hide_literal th = UNDISCH (MP (SPEC (concl th) HIDE_LITERAL) th);

fun show_literal lit =
  let val lit' = mk_neg lit
  in DISCH lit' THENR MP (SPEC lit SHOW_LITERAL)
  end;

local
  fun REMOVE_DISJ th =
    let val (a,b) = dest_disj (concl th)
    in UNDISCH (MP (SPECL [a,b] INITIALIZE_CLAUSE) th)
    end;

  val INIT =
    CONV_RULE (REPEATC (REWR_CONV (GSYM DISJ_ASSOC)))
    THENR REPEATR REMOVE_DISJ
    THENR hide_literal;
in
  fun initialize_lits th =
    if concl th = F then ([], th) else (strip_disj (concl th), INIT th);
end;

local
  fun final_lit lit =
    let val lit' = mk_neg lit
    in fn th => MP (SPECL [lit, concl th] FINALIZE_CLAUSE) (DISCH lit' th)
    end;
in
  fun finalize_lits (lits, th) =
    case rev lits of [] => th
    | lit :: rest => foldl (uncurry final_lit) (show_literal lit th) rest;
end;

(* Quick testing
val t1 = initialize_hol_thm (([], []), ASSUME ``p \/ ~q \/ ~r \/ s``);
val t2 = initialize_hol_thm (([], []), ASSUME ``((p \/ ~q) \/ ~r) \/ s``);
try finalize_hol_thm t1;
try finalize_hol_thm t2;
*)

(* ------------------------------------------------------------------------- *)
(* varconsts lump together constants and locally constant variables.         *)
(* ------------------------------------------------------------------------- *)

fun dest_varconst tm =
  case dest_term tm of VAR (s, _) => s
  | CONST {Thy, Name, Ty = _} => mk_const_name (Thy, Name)
  | _ => raise ERR "dest_varconst" (term_to_string tm ^ " is neither");

val is_varconst = can dest_varconst;

fun mk_varconst s =
  all_new_tyvars
  (if is_const_name s then
     let val (t, n) = dest_const_name s
     in prim_mk_const {Thy = t, Name = n}
     end
   else mk_var (s, alpha));

(* ------------------------------------------------------------------------- *)
(* Translate a HOL type to FOL, and back again.                              *)
(* ------------------------------------------------------------------------- *)

fun hol_type_to_fol tyV =
  let
    fun ty_to_fol hol_ty =
      if is_vartype hol_ty then
        (if mem hol_ty tyV then mlibTerm.Var o mlibName.fromString else (fn s => mlibTerm.Fn (mlibName.fromString s, [])))
        (dest_vartype hol_ty)
      else
        let val (f, args) = dest_type hol_ty
        in mlibTerm.Fn (mlibName.fromString f, map ty_to_fol args)
        end
  in
    ty_to_fol
  end;

fun fol_type_to_hol (mlibTerm.Var v) = fake_new_tyvar (possibly dest_prime (mlibName.toString v))
  | fol_type_to_hol (mlibTerm.Fn (f, a)) =
  if not (is_prime (mlibName.toString f)) then mk_type (mlibName.toString f, map fol_type_to_hol a)
  else (assert (null a) (ERR "fol_type_to_hol" "bad prime"); mk_vartype (mlibName.toString f));

val fol_bool = hol_type_to_fol [] bool;

(* Quick testing
installPP pp_term;
val t = try hol_type_to_fol [alpha] ``:'a list -> bool # (bool + 'b) list``;
try fol_type_to_hol t;
*)

(* ------------------------------------------------------------------------- *)
(* Translate a HOL literal to FOL.                                           *)
(* ------------------------------------------------------------------------- *)

fun hol_term_to_fol (parm : parameters) (tmV, tyV) =
  let
    val {with_types, higher_order, ...} = parm
    fun tmty2fol tm =
      if not with_types then tm2fol tm
      else mlibTerm.Fn (hasTypeFn, [tm2fol tm, hol_type_to_fol tyV (type_of tm)])
    and tm2fol tm =
      if mem tm tmV then mlibTerm.Var (mlibName.fromString (fst (dest_var tm)))
      else if higher_order then
        if is_comb tm then
          let val (a, b) = dest_comb tm
          in mlibTerm.Fn (mlibName.fromString "%", [tmty2fol a, tmty2fol b])
          end
        else mlibTerm.Fn (mlibName.fromString(dest_varconst tm), [])
      else
        let
          val (f, args) = strip_comb tm
          val () = assert (not (mem f tmV)) (ERR "hol_term_to_fol" "ho term")
        in
          mlibTerm.Fn (mlibName.fromString(dest_varconst f), map tmty2fol args)
        end
  in
    tmty2fol
  end;

fun hol_atom_to_fol parm vs tm =
  mlibFormula.Atom
  (if is_eq tm then
     let val (a, b) = dest_eq tm
     in (mlibName.fromString "=", map (hol_term_to_fol parm vs) [a, b])
     end
   else if #higher_order parm then (mlibName.fromString "$", [hol_term_to_fol parm vs tm])
   else mlibTerm.destFn (remove_type (hol_term_to_fol parm vs tm)));

fun hol_literal_to_fol parm vars lit =
  if is_neg lit then mlibFormula.Not (hol_atom_to_fol parm vars (dest_neg lit))
  else hol_atom_to_fol parm vars lit;

(* ------------------------------------------------------------------------- *)
(* The HOL -> FOL user interface:                                            *)
(* translation of theorems and lists of literals.                            *)
(* ------------------------------------------------------------------------- *)

fun hol_literals_to_fol parm (vars, lits) =
  map (hol_literal_to_fol parm vars) lits;

fun hol_thm_to_fol parm (vars, th) =
  mlibThm.AXIOM (hol_literals_to_fol parm (vars, fst (initialize_lits th)));

(* Quick testing
installPP pp_formula;
try hol_literals_to_fol {higher_order = true, with_types = true}
  (([``v_b : 'b``], [``:'a``]),
   [``~P (c_a : 'a, v_b : 'b)``, ``0 <= LENGTH ([] : 'a list)``]);
try hol_literals_to_fol {higher_order = true, with_types = false}
  (([``v_b : 'b``], [``:'a``]),
   [``~P (c_a : 'a, v_b : 'b)``, ``0 <= LENGTH ([] : 'a list)``]);
try hol_literals_to_fol {higher_order = false, with_types = true}
  (([``v_b : 'b``], [``:'a``]),
   [``~P (c_a : 'a, v_b : 'b)``, ``0 <= LENGTH ([] : 'a list)``]);
try hol_literals_to_fol {higher_order = false, with_types = false}
  (([``v_b : 'b``], [``:'a``]),
   [``~P (c_a : 'a, v_b : 'b)``, ``0 <= LENGTH ([] : 'a list)``]);
*)

(* ------------------------------------------------------------------------- *)
(* Translate a FOL literal to HOL.                                           *)
(* ------------------------------------------------------------------------- *)

fun fol_term_to_hol' ({higher_order, with_types = true, ...} : parameters) =
  let
    fun tmty_to_hol (mlibTerm.Fn (n,[tm,ty])) = if mlibName.equal n hasTypeFn then tm_to_hol (fol_type_to_hol ty) tm
        else raise ERR "fol_term_to_hol" "missing type information"
      | tmty_to_hol _ = raise ERR "fol_term_to_hol" "missing type information"
    and tm_to_hol ty (mlibTerm.Var v) = fake_new_var (v, ty)
      | tm_to_hol ty (mlibTerm.Fn (fname, args)) =
      if higher_order then
        case (fname, args) of (_, []) => cast_to ty (mk_varconst fname)
        | ("%", [f, a]) => mk_comb (tmty_to_hol f, tmty_to_hol a)
        | _ => raise ERR "fol_term_to_hol" "(typed) weird higher-order term"
      else
        let
          val hol_args = map tmty_to_hol args
          val f_type   = foldr (fn (h, t) => type_of h --> t) ty hol_args
        in
          list_mk_comb (cast_to f_type (mk_varconst fname), hol_args)
        end
  in
    tmty_to_hol
  end
  | fol_term_to_hol' ({higher_order, with_types = false, ...} : parameters) =
  let
    fun tm_to_hol (mlibTerm.Var v) = fake_new_var (v, new_tyvar ())
      | tm_to_hol (mlibTerm.Fn (fname, args)) =
      if higher_order then
        case (fname, args) of (_, []) => mk_varconst fname
        | ("%", [f, a]) => freshen_mk_comb (tm_to_hol f, tm_to_hol a)
        | _ => raise ERR "fol_term_to_hol" "(typeless) weird higher-order term"
      else freshen_list_mk_comb (mk_varconst fname, map tm_to_hol args)
  in
    tm_to_hol
  end;

fun fol_term_to_hol parm fol_tm =
  if not (chatting 1) then fol_term_to_hol' parm fol_tm else
    let
      fun cmp (mlibTerm.Var v) (mlibTerm.Var w) =
        possibly dest_prime v = dest_prefix FOL_PREFIX (possibly dest_prime w)
        | cmp (mlibTerm.Fn (f, a)) (mlibTerm.Fn (g, b)) =
        f = g andalso length a = length b andalso
        List.all (uncurry cmp) (zip a b)
        | cmp _ _ = false
      val hol_tm = fol_term_to_hol' parm fol_tm
      val fol_tm' = uncurry (hol_term_to_fol parm) (new_free_vars I hol_tm)
      val () = assert (cmp fol_tm fol_tm')
        (BUG "fol_term_to_hol"
         ("not inverse:\n\noriginal fol =\n" ^ mlibTerm.term_to_string fol_tm ^
          "\n\nhol =\n" ^ term_to_string hol_tm ^
          "\n\nnew fol =\n" ^ mlibTerm.term_to_string fol_tm'))
    in
      hol_tm
    end;

local
  fun else_case parm fm =
    (cast_to bool o fol_term_to_hol parm)
    let
      val {higher_order, with_types} = parm
    in
      case (higher_order, with_types, fm) of
        (true,  _,     mlibTerm.Atom (mlibTerm.Fn ("$", [tm]))) => tm
      | (false, true,  mlibTerm.Atom tm) => mlibTerm.Fn (":", [tm, fol_bool])
      | (false, false, mlibTerm.Atom tm) => tm
      | _ => raise BUG "fol_atom_to_fol" "malformed atom"
    end;
in
fun fol_atom_to_hol parm (fm as (mlibTerm.Atom (mlibTerm.Fn (n, [x, y])))) =
  if mlibName.equal n (mlibName.fromString "=") then
    unify_mk_eq (fol_term_to_hol parm x, fol_term_to_hol parm y)
  else else_case parm fm
  | fol_atom_to_hol parm fm = else_case parm fm
end

fun fol_literal_to_hol _ mlibTerm.True = T
  | fol_literal_to_hol _ mlibTerm.False = F
  | fol_literal_to_hol parm (mlibTerm.Not a) = mk_neg (fol_literal_to_hol parm a)
  | fol_literal_to_hol parm (a as mlibTerm.Atom _) = fol_atom_to_hol parm a
  | fol_literal_to_hol _ _ = raise ERR "fol_literal_to_hol" "not a literal";

(* Quick testing
installPP pp_formula;
val parm = {higher_order = false, with_types = true};
val lits = try hol_literals_to_fol parm
  (([``v_b : 'b``], [``:'b``]),
   [``~P (c_a : 'a list, v_b : 'b)``, ``0 <= LENGTH (c_a : 'a list)``]);
val [lit1, lit2] = lits;
try (fol_literal_to_hol parm) lit1;
try (fol_literal_to_hol parm) lit2;
*)

(* ------------------------------------------------------------------------- *)
(* Translate FOL paths to HOL.                                               *)
(* ------------------------------------------------------------------------- *)

local
  fun zeroes l [] = rev l
    | zeroes l (0 :: h :: t) = zeroes (h :: l) t
    | zeroes _ _ = raise BUG "fol_path_to_hol" "couldn't strip zeroes";

  fun hp r tm [] = (r, tm)
    | hp r tm (0 :: p) = hp (r o RATOR_CONV) (rator tm) p
    | hp r tm (1 :: p) = hp (r o RAND_CONV) (rand tm) p
    | hp _ _ _ = raise BUG "fol_path_to_hol" "bad higher-order path";

  fun fp r tm [] = (r, tm)
    | fp r tm (n :: p) =
    let
      val (_, l) = strip_comb tm
      val m = (length l - 1) - n
      val r = r o funpow m RATOR_CONV o RAND_CONV
      val tm = rand (funpow m rator tm)
    in
      fp r tm p
    end;

  fun ap {higher_order, with_types} (r, tm) p =
    uncurry3 (if higher_order then hp else fp)
    ((fn (r', tm', p') => (r', tm', if with_types then zeroes [] p' else p'))
     (if is_eq tm then
        (case p of 0 :: p => (r o LAND_CONV, lhs tm, p)
         | 1 :: p => (r o RAND_CONV, rhs tm, p)
         | _ => raise BUG "fol_path_to_hol" "bad eq path")
      else
        (r, tm,
         (if higher_order then
            (case p of 0 :: p => p
             | _ => raise BUG "fol_path_to_hol" "bad higher-order path")
          else if with_types then 0 :: p
          else p))));
in
  fun fol_path_to_hol parm p tm =
    ap parm (if is_neg tm then (RAND_CONV, dest_neg tm) else (I, tm)) p;
end;

(* Quick testing
val parm = {higher_order = false, with_types = true};
mlibUseful.try (fol_path_to_hol parm) [0, 0, 1] ``~p a b c``;
*)

(* ------------------------------------------------------------------------- *)
(* Translate a FOL theorem to HOL (the tricky bit).                          *)
(* ------------------------------------------------------------------------- *)

type Axioms  = thm1 -> vars * thm;
type Pattern = vars * term list;
type Result  = vars * thm list;

fun proof_step parm prev =
  let
    open mlibTerm mlibMatch mlibThm

    fun freshen (lits, th) =
      if #with_types parm then (lits, th)
      else
        let val sub = fresh_tyvars lits
        in (map (inst sub) lits, INST_TY sub th)
        end

    fun match_lits l l' =
      (if #with_types parm then match_term else new_match_uty)
      (list_mk_disj' l) (list_mk_disj' l')

    fun step (fol_th, Axiom' _) = prev fol_th
      | step (_, Assume' fol_lit) =
      let
        val th = if positive fol_lit then EXCLUDED_MIDDLE else EXCLUDED_MIDDLE'
        val hol_atom = fol_literal_to_hol parm (literal_atom fol_lit)
      in
        initialize_lits (SPEC hol_atom th)
      end
      | step (fol_th, Inst' (_, fol_th1)) =
      let
        val (hol_lits1, hol_th1) = prev fol_th1
        val hol_lits = map (fol_literal_to_hol parm) (clause fol_th)
        val sub = match_lits hol_lits1 hol_lits
      in
        (map (pinst sub) hol_lits1, PINST sub hol_th1)
      end
      | step (_, Factor' fol_th) =
      let
        fun f uns lits [] = (new_unifyl_ty ([], []) uns, rev (map snd lits))
          | f uns lits ((fl, hl) :: rest) =
          case List.find (equal fl o fst) lits of NONE
            => f uns ((fl, hl) :: lits) rest
          | SOME (_, hl') => f ((hl, hl') :: uns) lits rest
        val (hol_lits, hol_th) = prev fol_th
        val (sub, hol_lits') = f [] [] (zip (clause fol_th) hol_lits)
      in
        (map (pinst sub) hol_lits', PINST sub hol_th)
      end
      | step (_, Resolve' (False, fol_th1, fol_th2)) =
      let
        val (hol_lits1, hol_th1) = prev fol_th1
        val (hol_lits2, _)       = prev fol_th2
      in
        (hol_lits1 @ hol_lits2, hol_th1)
      end
      | step (_, Resolve' (fol_lit, fol_th1, fol_th2)) =
      let
        fun res0 fth fl =
          let
            val (hls, hth) = prev fth
            val (a, b) = partition (equal fl o fst) (zip (clause fth) hls)
          in
            ((map snd a, map snd b), hth)
          end
        val (negate_lit, negate_lit') =
          if positive fol_lit then (boolSyntax.mk_neg, boolSyntax.dest_neg)
          else (boolSyntax.dest_neg, boolSyntax.mk_neg)
        val hol_lit = fol_literal_to_hol parm fol_lit
        val ((hol_ms1, hol_lits1), hol_th1) = res0 fol_th1 fol_lit
        val ((hol_ms2, hol_lits2), hol_th2) = res0 fol_th2 (negate fol_lit)
        val _ = chatting 2 andalso chat
          ("resolve: hol_lits1 =\n" ^ terms_to_string hol_lits1 ^
           "resolve: hol_lits2 =\n" ^ terms_to_string hol_lits2 ^
           "resolve: hol_ms1 =\n" ^ terms_to_string hol_ms1 ^
           "resolve: hol_ms2 =\n" ^ terms_to_string hol_ms2)
        val sub = new_unify_ty (hol_lit :: hol_ms1 @ map negate_lit' hol_ms2)
        val hol_lit'  = pinst sub hol_lit
        val hol_nlit' = negate_lit hol_lit'
        val hol_th1'  = show_literal hol_lit'  (PINST sub hol_th1)
        val hol_th2'  = show_literal hol_nlit' (PINST sub hol_th2)
      in
        (map (pinst sub) (hol_lits1 @ hol_lits2),
         if positive fol_lit then
           MP (SPEC hol_lit' RESOLUTION) (CONJ hol_th1' hol_th2')
         else
           MP (SPEC hol_nlit' RESOLUTION) (CONJ hol_th2' hol_th1'))
      end
      | step (_, Refl' fol_tm) =
      initialize_lits (Thm.REFL (fol_term_to_hol parm fol_tm))
      | step (_, Equality' (fol_lit, fol_p, fol_r, lr, fol_th)) =
      let
        val (hol_lits, hol_th) = prev fol_th
        val n = mlibUseful.index (equal fol_lit) (clause fol_th)
        val hol_lit =
          case n of NONE => fol_literal_to_hol parm fol_lit
          | SOME n => List.nth (hol_lits, n)
        val hol_r = fol_term_to_hol parm fol_r
        val sub = sync_vars [hol_lit, hol_r]
        val hol_lits = map (inst sub) hol_lits
        val hol_th = INST_TY sub hol_th
        val hol_lit = inst sub hol_lit
        val hol_r = inst sub hol_r
        val (PATH, hol_l) = fol_path_to_hol parm fol_p hol_lit
        val sub = (new_unify_type o map type_of) [hol_l, hol_r]
        val hol_lits = map (inst sub) hol_lits
        val hol_th = INST_TY sub hol_th
        val hol_lit = inst sub hol_lit
        val hol_r = inst sub hol_r
        val hol_l = inst sub hol_l
        val eq = boolSyntax.mk_eq (if lr then (hol_l,hol_r) else (hol_r,hol_l))
        val hol_eq_th = (if lr then I else Thm.SYM) (Thm.ASSUME eq)
        val hol_lit_th = (PATH (K hol_eq_th)) hol_lit
        val hol_lit' = (boolSyntax.rhs o concl) hol_lit_th
        val hol_lits' =
          mk_neg eq ::
          (case n of NONE => hol_lit' :: hol_lits
           | SOME n => mlibUseful.update_nth (K hol_lit') n hol_lits)
        val hol_lem = CONJ (DISCH eq hol_lit_th) (show_literal hol_lit hol_th)
        val equal_step = SPECL [eq, hol_lit, hol_lit'] EQUAL_STEP
      in
        (hol_lits', snd (initialize_lits (MP equal_step hol_lem)))
      end;
  in
    fn p => freshen (step p)
  end;

local
  val initialize_axiom =
    initialize_lits o snd o gen_alpha (change_vars to_fake_new) PINST;

  fun previous a l x =
    case assoc1 x l of SOME (_, y) => y | NONE => initialize_axiom (a x);

  fun chat_proof th =
    if not (chatting 1) then mlibThm.proof th else
      let
        val res = mlibThm.proof th
        val _ = chat ("\n\nProof:\n" ^ mlibThm.proof_to_string res ^ "\n\n")
      in
        res
      end;

  fun chat_proof_step parm prev (p as (fol_th, inf)) =
    if not (chatting 1) then proof_step parm prev p else
      let
        val _ = chat
          ("_____________________________________________________\n" ^
           "\nfol: " ^ mlibThm.thm_to_string fol_th ^ "\n" ^
           "\ninf: " ^ mlibThm.inference_to_string inf ^ "\n")
        val res = proof_step parm prev p
        val _ = chat ("\nhol: " ^ thm_to_string (finalize_lits res) ^ "\n")
      in
        res
      end;

  fun translate parm prev =
    let
      fun f p []       = finalize_lits (snd (hd p))
        | f p (x :: l) = f ((fst x, chat_proof_step parm (prev p) x) :: p) l
    in
      f
    end;

  fun match_pattern pattern ths =
    let
      val pattern  = gen_alpha (change_vars to_new) (map o pinst) pattern
      val pattern  = list_mk_conj' (snd pattern)
      val ths_foot = list_mk_conj' (map concl ths)
    in
      map (PINST (new_match_uty pattern ths_foot)) ths
    end;

  val finalize_thms =
    gen_alpha (change_vars to_gen) (map o PINST) o
    new_free_vars (list_mk_conj' o map concl);
in
  fun fol_thms_to_hol parm axioms pattern ths =
    (finalize_thms o match_pattern pattern o
     map (translate parm (previous axioms) [] o chat_proof)) ths
    handle HOL_ERR _ => raise ERR "fol_thms_to_hol" "proof translation error";
end;

end
