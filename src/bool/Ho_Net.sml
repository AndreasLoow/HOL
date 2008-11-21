(* =====================================================================
 * FILE          : Ho_Net.sml
 * DESCRIPTION   : Implementation of term nets, from GTT.
 *
 * AUTHOR        : Somebody in the ICL group.
 * DATE          : August 26, 1991
 * MODIFIED      : Sept 5, 1992, to use deBruijn representation
 *
 * MODIFIED	: Donald Syme, 1995, to add assumption-bound variables.
 *
 * Assumption bound variables are for storing rewrites like
 *  [x=0] |- x = 0.
 * Since "x" is free in the assumptions, this rewrite should only match
 * terms which are exactly "x" on the left.  The old termnets chose this
 * rewrite to try to rewrite every term!!
 *
 * This only becomes really important when you have contextual rewriting.
 *
 * MODIFIED    : Donald Syme, November 1995, to be keyed up to higher order
 *               matching, based on JRH's code from GTT.
 * ===================================================================== *)

structure Ho_Net :> Ho_Net =
struct


open HolKernel boolSyntax;

val ERR = mk_HOL_ERR "Ho_Net";

(*--------------------------------------------------------------------
 * Labels ascribed to head-operators of terms.
 *-------------------------------------------------------------------*)

datatype term_label
   = Vnet
   | FVnet of string * int
   | Cnet of string * string * int
   | Lnet of int
   | TCnet of int
   | TLnet of int;

fun label_cmp p =
    case p of
      (Vnet, Vnet) => EQUAL
    | (Vnet, _) => LESS
    | (_, Vnet) => GREATER
    | (FVnet f1, FVnet f2) => pair_compare (String.compare, Int.compare)
                                           (f1, f2)
    | (FVnet _, _) => LESS
    | (_, FVnet _) => GREATER
    | (Cnet (nm1,thy1,n1), Cnet(nm2,thy2,n2)) => let
      in
        case String.compare (nm1, nm2) of
          EQUAL => (case String.compare(thy1, thy2) of
                      EQUAL => Int.compare(n1, n2)
                    | x => x)
        | x => x
      end
    | (Cnet _, _) => LESS
    | (_, Cnet _) => GREATER
    | (Lnet n1, Lnet n2) => Int.compare(n1, n2)
    | (Lnet _, _) => LESS
    | (_, Lnet _) => GREATER
    | (TCnet n1, TCnet n2) => Int.compare(n1, n2)
    | (TCnet _, _) => LESS
    | (_, TCnet _) => GREATER
    | (TLnet n1, TLnet n2) => Int.compare(n1, n2)


fun stored_label (ftyvars,fvars,tm) =
  let val (oper,args) = strip_comb tm
      val args' = map (fn x => (ftyvars,fvars,x)) args
      val subtract = Lib.op_set_diff aconv
      val subtract_ty = Lib.op_set_diff aconv_ty
      val mem = Lib.op_mem aconv
  in case dest_term oper
      of CONST {Name,Thy,...} => (Cnet(Name,Thy,length args),args')
       | LAMB (Bvar,Body) => (Lnet(length args),
                              (ftyvars,subtract fvars [Bvar],Body)::args')
       | VAR (Name,_) =>
          if mem oper fvars then (FVnet(Name,length args),args') else (Vnet,[])
       | TYCOMB (Tm,Ty)      => (TCnet(length args), (ftyvars,fvars,Tm)::args')
       | TYLAMB (Tyvar,Body) => (TLnet(length args),
                                    (subtract_ty ftyvars [Tyvar],fvars,Body)::args')
       | _ => fail()
    end;

open Binarymap
fun label_for_lookup tm =
  let val (oper,args) = strip_comb tm
  in case dest_term oper
      of CONST {Name,Thy,...} => (Cnet(Name,Thy,length args),args)
       | LAMB (Bvar,Body)     => (Lnet(length args),Body::args)
       | VAR (Name,_)         => (FVnet(Name,length args),args)
       | TYCOMB (Tm,Ty)       => (TCnet(length args),Tm::args)
       | TYLAMB (Tyvar,Body)  => (TLnet(length args),Body::args)
       | _ => fail()
  end;

(* double constructor design may seem redundant but it allows us to avoid
   a value polymorphism problem, and have a simple value for empty_net.
   If you try
     val empty_net = NODE(mkDict label_cmp, [])
   then empty_net can't be fully polymorphic, thanks to the call to
   mkDict. *)
datatype 'a net = NODE of (term_label,'a net) dict * 'a list
                | EMPTY of 'a list

val empty_net = EMPTY []



fun edges (NODE(es, _)) = es
  | edges (EMPTY _) = mkDict label_cmp
fun tips (NODE(_, ts)) = ts
  | tips (EMPTY ts) = ts
fun add_tip e (NODE(es, tips)) = NODE(es, e::tips)
  | add_tip e (EMPTY tips) = EMPTY (e::tips)

fun check_edge(NODE(es, _), label) = peek(es, label)
  | check_edge(EMPTY _, label) = NONE
fun new_edge(NODE(es, ts), label, n) = NODE(insert(es, label, n), ts)
  | new_edge(EMPTY ts, label, n) = NODE(insert(mkDict label_cmp, label, n), ts)


fun net_update (elem, tms:(hol_type list * term list * term) list, net) =
   case tms of
     [] => add_tip elem net
   | tm::rtms =>
        let val (label,ntms) = stored_label tm
            val child = case check_edge(net, label) of
                          NONE => empty_net
                        | SOME n => n
            val new_child = net_update(elem,ntms @ rtms,child)
        in
          new_edge(net, label, new_child)
        end;

fun follow (tms, net) =
   case tms
    of [] => tips net
     | tm::rtms =>
        let val (label,ntms) = label_for_lookup tm
            val collection =
                case check_edge(net, label) of
                  NONE => []
                | SOME child => follow(ntms @ rtms, child)
        in
          collection @
          (case check_edge(net, Vnet) of
             NONE => []
           | SOME n' => follow(rtms,n'))
        end;

fun enter (ftyvars,fvars,tm,elem) net = net_update(elem,[(ftyvars,fvars,tm)],net);

fun lookup tm net = follow([tm],net);

fun merge_nets (n1, n2) = let
  fun add_node (lab, net, m) =
      case peek(m, lab) of
        SOME net' => insert(m, lab, merge_nets(net, net'))
      | NONE => insert(m, lab, net)
in
  NODE (foldl add_node (edges n1) (edges n2), tips n1 @ tips n2)
end


fun listItems net = let
  fun cons'(v,acc) = v::acc
  fun trav (net, acc) =
      case net of
        NODE (d,l) => let
          fun foldthis (k,v,acc) = trav(v,acc)
        in
          Binarymap.foldl foldthis (List.foldl cons' acc l) d
        end
      | EMPTY l => List.foldl cons' acc l
in
  trav(net, [])
end


end (* struct *)
