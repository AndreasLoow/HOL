structure HolKernel =
struct

  open Feedback Globals Lib Kind Type Term Thm Theory Definition


(*---------------------------------------------------------------------------
     Miscellaneous other stuff that builds on top of kernel facilities.
 ---------------------------------------------------------------------------*)

infixr ==>;  infixr -->;  infix |->;

val ERR = mk_HOL_ERR "HolKernel";

(*---------------------------------------------------------------------------
          General term operations
 ---------------------------------------------------------------------------*)

fun dest_monop c e M =
 let val (c1,N) = with_exn dest_comb M e
 in if same_const c c1 then N else raise e end

local fun dest tm =
       let val (Rator,N) = dest_comb tm
           val (c,M) = dest_comb Rator
       in (c,(M,N)) end
in
fun dest_binop c e tm =
   let val (c1,pair) = with_exn dest tm e
   in if same_const c c1 then pair else raise e end
end

fun dest_triop p e M =
  let val (f,z) = with_exn dest_comb M e
      val (x,y) = dest_binop p e f
  in (x,y,z)
  end;

local fun dest M = let val (c,Rand) = dest_comb M in (c,dest_abs Rand) end
in
fun dest_binder c e M =
  let val (c1,p) = with_exn dest M e
  in if same_const c c1 then p else raise e end
end

local fun dest M = let val (c,Rand) = dest_comb M in (c,dest_tyabs Rand) end
in
fun dest_tybinder c e M =
  let val (c1,p) = with_exn dest M e
  in if same_const c c1 then p else raise e end
end


local fun dest M =
       let val (Rator,Rand) = dest_comb M in (dest_thy_const Rator,Rand) end
in
fun sdest_monop (name,thy) e M =
 let val ({Name,Thy,...},Rand) = with_exn dest M e
 in if Name=name andalso Thy=thy then Rand else raise e
 end;
end

local fun dest tm =
       let val (Rator,N) = dest_comb tm
           val (c,M) = dest_comb Rator
       in (dest_thy_const c,(M,N))
       end
in
fun sdest_binop (name,thy) e tm =
   let val ({Name,Thy,...},pair) = with_exn dest tm e
   in if Name=name andalso Thy=thy then pair else raise e
   end
end;

local fun dest M =
       let val (c, Rand) = dest_comb M
       in (dest_thy_const c,dest_abs Rand)
       end
in
fun sdest_binder (name,thy) e M =
  let val ({Name,Thy,...}, p) = with_exn dest M e
  in if Name=name andalso Thy=thy then p else raise e
  end
end;

local fun dest M =
       let val (c, Rand) = dest_comb M
       in (dest_thy_const c,dest_tyabs Rand)
       end
in
fun sdest_tybinder (name,thy) e M =
  let val ({Name,Thy,...}, p) = with_exn dest M e
  in if Name=name andalso Thy=thy then p else raise e
  end
end;

fun single x = [x];

(* Breaks term down until binop no longer occurs at top level in result list *)

fun strip_binop dest =
 let fun strip A [] = rev A
       | strip A (h::t) =
          case dest h
           of NONE => strip (h::A) t
            | SOME(c1,c2) => strip A (c1::c2::t)
 in strip [] o single
 end;

(* For right-associative binary operators. Tail recursive. *)

fun spine_binop dest =
 let fun strip A tm =
       case dest tm
         of NONE => rev (tm::A)
          | SOME (l,r) => strip (l::A) r
 in strip []
 end;

(* for left-associative binary operators.  Tail recursive *)
fun lspine_binop dest = let
  fun strip A tm =
      case dest tm of
        NONE => tm :: A
      | SOME (l,r) => strip (r::A) l
in
  strip []
end;

(* For right-associative binary operators. Tail recursive. *)

fun list_mk_rbinop _ [] = raise ERR "list_mk_rbinop" "empty list"
  | list_mk_rbinop mk_binop alist =
       let val (h::t) = List.rev alist
       in rev_itlist mk_binop t h
       end;

(* For left-associative binary operators. Tail recursive. *)

fun list_mk_lbinop _ [] = raise ERR "list_mk_lbinop" "empty list"
  | list_mk_lbinop mk_binop (h::t) = rev_itlist (C mk_binop) t h;

fun mk_binder c f (p as (Bvar,_)) =
   mk_comb(Term.inst[alpha |-> type_of Bvar] c, mk_abs p)
   handle HOL_ERR {message,...} => raise ERR f message;

fun mk_tybinder c f (p as (Bvar,_)) =
   mk_comb(c, mk_tyabs p)
   handle HOL_ERR {message,...} => raise ERR f message;

fun list_mk_fun (dtys, rty) = List.foldr op--> rty dtys

val strip_fun =
  let val dest = total dom_rng
      fun strip acc ty =
          case dest ty
            of SOME (d,r) => strip (d::acc) r
             | NONE => (rev acc, ty)
  in strip []
  end;


val strip_comb =
 let val destc = total dest_comb
     fun strip rands M =
      case destc M
       of NONE => (M, rands)
        | SOME(Rator,Rand) => strip (Rand::rands) Rator
 in strip []
 end;

val strip_tycomb =
 let val destc = total dest_tycomb
     fun strip rands M =
      case destc M
       of NONE => (M, rands)
        | SOME(Rator,Rand) => strip (Rand::rands) Rator
 in strip []
 end;


datatype lambda
   = VAR    of string * hol_type
   | CONST  of {Name:string, Thy:string, Ty:hol_type}
   | COMB   of term * term
   | TYCOMB of term * hol_type
   | LAMB   of term * term
   | TYLAMB of hol_type * term;

fun dest_term M =
  COMB  (dest_comb M)   handle HOL_ERR _ =>
  TYCOMB(dest_tycomb M) handle HOL_ERR _ =>
  LAMB  (dest_abs M)    handle HOL_ERR _ =>
  TYLAMB(dest_tyabs M)  handle HOL_ERR _ =>
  VAR   (dest_var M)    handle HOL_ERR _ =>
  CONST (dest_thy_const M);


datatype omega_type
   = TYVAR of string * kind * int (* rank *)
   | TYCONST of {Thy:string, Tyop:string, Kind:kind, Rank:int}
   | TYAPP  of hol_type * hol_type
   | TYUNIV of hol_type * hol_type
   | TYABS  of hol_type * hol_type;

fun destruct_type Ty =
  TYAPP   (dest_app_type     Ty) handle HOL_ERR _ =>
  TYUNIV  (dest_univ_type    Ty) handle HOL_ERR _ =>
  TYABS   (dest_abs_type     Ty) handle HOL_ERR _ =>
  TYVAR   (dest_vartype_opr  Ty) handle HOL_ERR _ =>
  TYCONST (dest_thy_con_type Ty);


(*---------------------------------------------------------------------------*
 * Used to implement natural deduction style discharging of hypotheses. All  *
 * hypotheses alpha-convertible to the dischargee are removed.               *
 *---------------------------------------------------------------------------*)

fun disch(w,wl) = Lib.gather (not o Term.aconv w) wl;


(*---------------------------------------------------------------------------*
 * Search a term for a sub-term satisfying the predicate P. If application   *
 * of P raises an exception, that propagates to the caller. Therefore,       *
 * P should be a total predicate: otherwise, the caller won't know whether   *
 * the search failed because the sought-for subterm is not there, or because *
 * P failed.                                                                 *
 *---------------------------------------------------------------------------*)

fun find_term P =
 let fun find_tm tm =
      if P tm then tm else
      if is_abs tm then find_tm (body tm) else
      if is_comb tm
         then let val (Rator,Rand) = dest_comb tm
              in find_tm Rator handle HOL_ERR _ => find_tm Rand
              end
      else
      if is_tyabs tm then find_tm (snd (dest_tyabs tm)) else
      if is_tycomb tm then find_tm (fst (dest_tycomb tm))
      else raise ERR "find_term" ""
 in find_tm
 end;

(*---------------------------------------------------------------------------
 * find_terms: (term -> bool) -> term -> term list
 *
 *  Find all subterms in a term that satisfy a given predicate p.
 *
 * Added TFM 88.03.31
 *---------------------------------------------------------------------------*)

fun find_terms P =
 let fun accum tl tm =
      let val tl' = if P tm then tm::tl else tl
      in accum tl' (body tm)
         handle HOL_ERR _ =>
          if is_comb tm
          then let val (r1,r2) = dest_comb tm
               in accum (accum tl' r1) r2
               end
          else if is_tycomb tm then accum tl' (fst (dest_tycomb tm))
          else if is_tyabs tm then accum tl' (snd (dest_tyabs tm))
          else tl'
      end
 in accum []
 end;

(* ----------------------------------------------------------------------
    find_maximal_terms[l]

    finds sub-terms within a term, but doesn't look into sub-terms that
    match the provided predicate.  The find_maximal_termsl version
    returns the terms as a list rather than a set.
   ---------------------------------------------------------------------- *)

fun find_maximal_terms P t = let
  fun recurse acc tlist =
      case tlist of
        [] => acc
      | t::ts =>
        if P t then recurse (HOLset.add(acc, t)) ts
        else
          case dest_term t of
            COMB(f,x) => recurse acc (f::x::ts)
          | TYCOMB(f,ty) => recurse acc (f::ts)
          | LAMB(v,b) => recurse acc (b::ts)
          | TYLAMB(ty,b) => recurse acc (b::ts)
          | _ => recurse acc ts
in
  recurse empty_tmset [t]
end

fun find_maximal_termsl P t = HOLset.listItems (find_maximal_terms P t)

(* ----------------------------------------------------------------------
    term_size

    Returns a term's size.  There's no logical significance to this
    number, but it can be useful.
   ---------------------------------------------------------------------- *)

fun term_size t = let
  fun recurse acc tlist =
      case tlist of
        [] => acc
      | t::ts =>
        case dest_term t of
          COMB(f, x) => recurse acc (f::x::ts)
        | TYCOMB(f, ty) => recurse (1 + acc) (f::ts)
        | LAMB(v,b)     => recurse (1 + acc) (b::ts)
        | TYLAMB(ty,b)  => recurse (1 + acc) (b::ts)
        | _ => recurse (1 + acc) ts
in
  recurse 0 [t]
end

(*---------------------------------------------------------------------------
 * Subst_occs
 * Put a new variable in tm2 at designated (and free) occurrences of redex.
 * Rebuilds the entire term.
 *---------------------------------------------------------------------------*)

local
fun splice ({redex,...}:{redex:term,residue:term}) v occs tm2 =
   let fun graft (r as {occs=[], ...}) = r
         | graft {tm, occs, count} =
          if term_eq redex tm
          then if (List.hd occs=count+1)
               then {tm=v, occs=List.tl occs, count=count+1}
               else {tm=tm, occs=occs, count=count+1}
          else if (is_comb tm)
               then let val (Rator, Rand) = dest_comb tm
                        val {tm=Rator', occs=occs', count=count'} =
                                        graft {tm=Rator,occs=occs,count=count}
                        val {tm=Rand', occs=occs'', count=count''} =
                                        graft {tm=Rand,occs=occs',count=count'}
                    in {tm=mk_comb(Rator', Rand'),
                        occs=occs'', count=count''}
                    end
               else if is_abs tm
                    then let val (Bvar,Body) = dest_abs tm
                             val {tm, count, occs} =
                                        graft{tm=Body,count=count,occs=occs}
                         in {tm=mk_abs(Bvar, tm),
                             count=count, occs=occs}
                         end
               else if (is_tycomb tm)
                    then let val (Rator, Rand) = dest_tycomb tm
                             val {tm, occs, count} =
                                        graft{tm=Rator,occs=occs,count=count}
                         in {tm=mk_tycomb(tm, Rand),
                             occs=occs, count=count}
                         end
               else if is_tyabs tm
                    then let val (Bvar,Body) = dest_tyabs tm
                             val {tm, count, occs} =
                                        graft{tm=Body,count=count,occs=occs}
                         in {tm=mk_tyabs(Bvar, tm),
                             count=count, occs=occs}
                         end
                    else {tm=tm, occs=occs, count=count}
   in #tm(graft {tm=tm2, occs=occs, count=0})
   end

fun rev_itlist3 f L1 L2 L3 base_value =
 let fun rev_it3 (a::rst1) (b::rst2) (c::rst3) base =
             rev_it3 rst1 rst2 rst3 (f a b c base)
       | rev_it3 [] [] [] base = base
       | rev_it3 _ _ _ _ = raise ERR "rev_itlist3"
                                  "not all lists have same size"
 in rev_it3 L1 L2 L3 base_value
 end

val sort = Lib.sort (Lib.curry (op <=) : int -> int -> bool)
in
fun subst_occs occ_lists tm_subst tm =
   let val occ_lists' = map sort occ_lists
       val (new_vars,theta) =
               Lib.itlist (fn {redex,residue} => fn (V,T) =>
                         let val v = genvar(type_of redex)
                         in (v::V,  (v |-> residue)::T)  end)
                      tm_subst ([],[])
       val template = rev_itlist3 splice tm_subst new_vars occ_lists' tm
   in subst theta template
   end
end;


(*---------------------------------------------------------------------------
       Higher order matching (from jrh via Michael Norrish - June 2001)
       Modified to include kind variables by Peter Homeier - September 2008
 ---------------------------------------------------------------------------*)

local
  exception NOT_FOUND
  fun find_residue red [] = raise NOT_FOUND
    | find_residue red ({redex,residue}::rest) = if red = redex then residue
                                                 else find_residue red rest
  fun find_residue_ty red [] = raise NOT_FOUND
    | find_residue_ty red ({redex,residue}::rest) = if abconv_ty red redex then residue
                                                    else find_residue_ty red rest
  fun find_residue_tm red [] = raise NOT_FOUND
    | find_residue_tm red ({redex,residue}::rest) = if aconv red redex then residue
                                                    else find_residue_tm red rest
  fun in_dom x [] = false
    | in_dom x ({redex,residue}::rest) = (x = redex) orelse in_dom x rest
  fun in_dom_ty x [] = false
    | in_dom_ty x ({redex,residue}::rest) = abconv_ty x redex orelse in_dom_ty x rest
  fun in_dom_tm x [] = false
    | in_dom_tm x ({redex,residue}::rest) = aconv x redex orelse in_dom_tm x rest
  fun safe_insert (n as {redex,residue}) l = let
    val z = find_residue redex l
  in
    if residue = z then l
    else raise ERR "safe_insert" "match"
  end handle NOT_FOUND => n::l  (* binding not there *)
  (* safe_inserta is like safe_insert but specially for terms *)
  fun safe_inserta (n as {redex,residue}) l = let
    val z = find_residue_tm redex l
  in
    if aconv residue z then l
    else raise ERR "safe_inserta" "match"
  end handle NOT_FOUND => n::l
  (* safe_insertb is like safe_insert but specially for betacounts *)
  fun safe_insertb (n as {redex,residue}) l = let
    val z = find_residue_tm redex l
  in
    if residue = z then l
    else raise ERR "safe_insertb" "match"
  end handle NOT_FOUND => n::l
  (* safe_insert_ty is like safe_insert but specially for types *)
  fun safe_insert_ty (n as {redex,residue}) l = let
    val z = find_residue_ty redex l
  in
    if abconv_ty residue z then l
    else raise ERR "safe_insert_ty" "match"
  end handle NOT_FOUND => n::l
  val mk_dummy = let
    val name = fst(dest_var(genvar Type.alpha))
  in fn ty => mk_var(name, ty)
  end


  fun term_pmatch lconsts env vtm ctm (sofar as (insts,homs)) =
    if is_var vtm then let
        val ctm' = find_residue_tm vtm env
      in
        if aconv ctm' ctm then sofar else raise ERR "term_pmatch" "variable double bind"
      end handle NOT_FOUND =>
                 if HOLset.member(lconsts, vtm) then
                   if aconv ctm vtm then sofar
                   else raise ERR "term_pmatch" "can't instantiate local constant"
                 else (safe_inserta (vtm |-> ctm) insts, homs)
    else if is_const vtm then let
        val {Thy = vthy, Name = vname, Ty = vty} = dest_thy_const vtm
        val {Thy = cthy, Name = cname, Ty = cty} = dest_thy_const ctm
      in
        if vname = cname andalso vthy = cthy then
          if abconv_ty cty vty then sofar
          else (safe_inserta (mk_dummy vty |-> mk_dummy cty) insts, homs)
        else raise ERR "term_pmatch" "constant mismatch"
      end
    else if is_abs vtm then let
        val (vv,vbod) = dest_abs vtm
        val (cv,cbod) = dest_abs ctm
        val (_, vty) = dest_var vv
        val (_, cty) = dest_var cv
        val sofar' = (safe_inserta(mk_dummy vty |-> mk_dummy cty) insts, homs)
      in
        term_pmatch lconsts ((vv |-> cv)::env) vbod cbod sofar'
      end
    else if is_tyabs vtm then let
        val (vty,vbod) = dest_tyabs vtm
        val (cty,cbod) = dest_tyabs ctm
        val vv = mk_dummy vty
        val cv = mk_dummy cty
        val sofar' = (safe_inserta(vv |-> cv) insts, homs)
      in
        term_pmatch lconsts ((vv |-> cv)::env) vbod cbod sofar'
      end
    else if is_tycomb vtm then let
        val (vtm0,vty) = dest_tycomb vtm
        val (ctm0,cty) = dest_tycomb ctm
        val vv = mk_dummy vty
        val cv = mk_dummy cty
        val sofar' = (safe_inserta(vv |-> cv) insts, homs)
      in
        term_pmatch lconsts env vtm0 ctm0 sofar'
      end
    else let
        val vhop = repeat rator vtm
      in
        if is_var vhop andalso not (HOLset.member(lconsts, vhop)) andalso
           not (in_dom_tm vhop env)
        then let
            val vty = type_of vtm
            val cty = type_of ctm
            val insts' = if abconv_ty vty cty then insts
                         else safe_inserta (mk_dummy vty |-> mk_dummy cty) insts
          in
            (insts', (env,ctm,vtm)::homs)
          end
        else let
            val (lv,rv) = dest_comb vtm
            val (lc,rc) = dest_comb ctm
            val sofar' = term_pmatch lconsts env lv lc sofar
          in
            term_pmatch lconsts env rv rc sofar'
          end
      end

val get_type_kind_rank_insts = Term.get_type_kind_rank_insts

(*
fun get_type_kind_rank_insts kdavoids tyavoids L ((tyS,tyId),(kdS,kdId),rkS) =
 itlist (fn {redex,residue} => fn Theta =>
          Type.prim_kind_match_type (snd(dest_var redex)) (type_of residue) Theta)
       L ((tyS,union tyavoids tyId),(kdS,union kdavoids kdId),rkS)
*)

fun separate_insts kdavoids tyavoids rkS kdS tyS insts = let
  val (realinsts, patterns) = partition (is_var o #redex) insts
  val betacounts =
      if null patterns then []
      else
        itlist (fn {redex = p,...} =>
                   fn sof => let
                        val (hop,args) = strip_comb p
                      in
                        safe_insertb (hop |-> length args) sof
                      end handle _ =>
                                 (HOL_WARNING "" ""
                                  "Inconsistent patterning in h.o. match";
                                  sof))
        patterns []
  val (tyins,kdins,rkin) = get_type_kind_rank_insts kdavoids tyavoids realinsts (tyS,kdS,rkS)
  val tyinsts = mapfilter (fn {redex = x, residue = t} => let
                   val x' = Type.inst_rank_kind rkin (fst kdins) x
                 in
                   if t = x' then raise ERR "separate_insts" ""
                                 else {redex = x', residue = t}
                 end) (fst tyins)
  val tyins' = (tyinsts,snd tyins)
  val tminsts = mapfilter (fn {redex = x, residue = t} => let
                   val x' = let val (xn,xty) = dest_var x
                            in
                              mk_var(xn, type_subst tyinsts
                                            (Type.inst_rank_kind rkin (fst kdins) xty))
                            end
                 in
                   if aconv t x' then raise ERR "separate_insts" ""
                                 else {redex = x', residue = t}
                 end) realinsts
in
  (betacounts, tminsts, tyins', kdins, rkin)
end

fun tyenv_in_dom x (env, idlist) = op_mem abconv_ty x idlist orelse in_dom_ty x env
fun tyenv_find_residue x (env, idlist) = if op_mem abconv_ty x idlist then x
                                         else find_residue x env
fun tyenv_safe_insert (t as {redex,residue}) (E as (env, idlist)) = let
  val existing = tyenv_find_residue redex E
in
  if abconv_ty existing residue then E else raise ERR "tyenv_safe_insert" "Type bindings clash"
end handle NOT_FOUND => if abconv_ty redex residue then (env, redex::idlist)
                        else (t::env, idlist)

fun all_aconv [] [] = true
  | all_aconv [] _ = false
  | all_aconv _ [] = false
  | all_aconv (h1::t1) (h2::t2) = aconv h1 h2 andalso all_aconv t1 t2


fun term_homatch kdavoids tyavoids lconsts rkin kdins tyins (insts, homs) = let
  (* local constants of both terms and types never change *)
  val term_homatch = term_homatch kdavoids tyavoids lconsts
in
  if null homs then insts
  else let
      val (env,ctm,vtm) = hd homs
    in
      if is_var vtm then
        if aconv ctm vtm then term_homatch rkin kdins tyins (insts, tl homs)
        else let
            (* val (newtyins,newkdins,newrkin) =
                prim_kind_match_type (snd (dest_var vtm)) (type_of ctm) (tyins,kdins,rkin) *)
            val newtyins =
                tyenv_safe_insert (snd (dest_var vtm) |-> type_of ctm) tyins
            val newinsts = (vtm |-> ctm)::insts
          in
            term_homatch rkin kdins newtyins (newinsts, tl homs)
          end
      else (* vtm not a var *) let
          val (vhop, vargs) = strip_comb vtm
          val afvs = free_varsl vargs
          val inst_fn = inst (fst tyins) o inst_rank_kind rkin (fst kdins)
        in
          (let
             val tmins =
                 map (fn a =>
                         (inst_fn a |->
                                  (find_residue_tm a env
                                   handle _ =>
                                          find_residue_tm a insts
                                   handle _ =>
                                          if HOLset.member(lconsts, a)
                                          then a
                                          else raise ERR "term_homatch" ""))) afvs
             val pats0 = map inst_fn vargs
             val pats = map (Term.subst tmins) pats0
             val vhop' = inst_fn vhop
             val ictm = list_mk_comb(vhop', pats)
             val ni = let
               val (chop,cargs) = strip_comb ctm
             in
               if all_aconv cargs pats then
                 if aconv chop vhop then insts
                 else safe_inserta (vhop |-> chop) insts
               else let
                   val ginsts = map (fn p => (p |->
                                                (if is_var p then p
                                                 else genvar(type_of p))))
                                    pats
                   val ctm' = Term.subst ginsts ctm
                   val gvs = map #residue ginsts
                   val abstm = list_mk_abs(gvs,ctm')
                   val vinsts = safe_inserta (vhop |-> abstm) insts
                   val icpair = (list_mk_comb(vhop',gvs) |-> ctm')
                 in
                   icpair::vinsts
                 end
             end
           in
             term_homatch rkin kdins tyins (ni,tl homs)
           end) handle _ => let
                         val (lc,rc) = dest_comb ctm
                         val (lv,rv) = dest_comb vtm
                         val pinsts_homs' =
                             term_pmatch lconsts env rv rc
                                         (insts, (env,lc,lv)::(tl homs))
                         val (tyins',kdins',rkin') =
                             get_type_kind_rank_insts kdavoids tyavoids
                                                 (fst pinsts_homs')
                                                 (([], []), ([], []), 0)
                       in
                         term_homatch rkin' kdins' tyins' pinsts_homs'
                       end
        end
    end
end

in

fun ho_kind_match_term0 kdavoids tyavoids lconsts vtm ctm = let
  val pinsts_homs = term_pmatch lconsts [] vtm ctm ([], [])
  val (tyins,kdins,rkin) = get_type_kind_rank_insts kdavoids tyavoids (fst pinsts_homs) (([],[]),([],[]),0)
  val insts = term_homatch kdavoids tyavoids lconsts rkin kdins tyins pinsts_homs
in
  separate_insts kdavoids tyavoids rkin kdins tyins insts
end

fun ho_match_term0 tyavoids lconsts vtm ctm = let
  val pinsts_homs = term_pmatch lconsts [] vtm ctm ([], [])
  val (tyins,kdins,rkin) = get_type_kind_rank_insts [] tyavoids (fst pinsts_homs) (([],[]),([],[]),0)
  val insts = term_homatch [] tyavoids lconsts rkin kdins tyins pinsts_homs
  val (bcs,tmins,tyins,kdins,rkin) = separate_insts [] tyavoids rkin kdins tyins insts
in
  (bcs,tmins,tyins)
end

fun ho_kind_match_term kdavoids tyavoids lconsts vtm ctm = let
  val (bcs, tmins, tyins, kdins, rkin) = ho_kind_match_term0 kdavoids tyavoids lconsts vtm ctm
in
  (tmins, #1 tyins, #1 kdins, rkin)
end handle e => raise (wrap_exn "HolKernel" "ho_kind_match_term" e)

fun ho_match_term tyavoids lconsts vtm ctm = let
  val (bcs, tmins, tyins) = ho_match_term0 tyavoids lconsts vtm ctm
in
  (tmins, #1 tyins)
end handle e => raise (wrap_exn "HolKernel" "ho_match_term" e)

end (* local *)

end
