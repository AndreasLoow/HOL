(*---------------------------------------------------------------------------

    A cute introductory proof example, extracted from 

         "A quick overview of PVS and HOL"

    by Laurent Thery. Presented at
     
         "Types summer school'99: Theory and practice of formal proofs"
                Giens, France, August 30 - September 10, 1999

    Overhead slides from the talk can be found at

         http://www-sop.inria.fr/types-project/lnotes/types99-lnotes.html

   The Claim.
   -----------

     With coins of 3 and 5 euros, we can make any amount 
     greater or equal to 8.

   Proof. 
  -------
      By induction.

      Base case. We take one coin of 3 and one coin of 5 to make 8.

      Step case. We know that we can do "n" and we want to prove we 
          can make "n+1". We have two cases:

           1. If there is a coin of 5 used to make n, we remove it 
              and add two coins of 3. We have removed 5 and added 2*3 = 6,
              which is n+1.

           2. There is no coin of 5 used to make n. Then n is made only 
              from coins of 3, and is greater than 8, so we have at
              least 3 coins of 3. We remove these 3 coins and add 2 
              coins of 5. We have removed 3*3 = 9 and added 2*5 = 10, 
              which is n+1.

 ---------------------------------------------------------------------------*)
              

app load ["bossLib", "Q"]; open bossLib;
infix &&
infix 8 by;


(*---------------------------------------------------------------------------
    Specialize the simplifier to know a bit about arithmetic.
 ---------------------------------------------------------------------------*)

val ARW_TAC =
 let open arithmeticTheory
 in
   RW_TAC (arith_ss && [ADD_CLAUSES,MULT_CLAUSES])
 end;


(*---------------------------------------------------------------------------
     Set the goal. Note how some work is needed to translate 
     the informal statement into logic.
 ---------------------------------------------------------------------------*)

g`!i. ?j k. i+8 = 3*j + 5*k`;

(*---------------------------------------------------------------------------
     Induct on i and then simplify.
 ---------------------------------------------------------------------------*)

e (Induct THEN ARW_TAC[]);

(*---------------------------------------------------------------------------
      This leaves two goals. The first is easy to show.
 ---------------------------------------------------------------------------*)

(* Goal 1 *)

e (MAP_EVERY Q.EXISTS_TAC [`1`, `1`] THEN DECIDE_TAC);

(*---------------------------------------------------------------------------
      Now consider cases on the number of coins of value 5.
 ---------------------------------------------------------------------------*)

(* Goal 2 *)

e (Cases_on `k` THEN ARW_TAC []);

(*---------------------------------------------------------------------------
      Case: no coins of value 5. Now consider the number (j) of coins 
      of value 3. "j" has to be 3 or greater. Knowing this, the 
      existential witnesses are easy to supply.
 ---------------------------------------------------------------------------*)

(* Goal 2.1 *)

e (`2<j` by DECIDE_TAC);
e (MAP_EVERY Q.EXISTS_TAC [`j-3`, `2`]);
e DECIDE_TAC;

(*---------------------------------------------------------------------------
      Case: at least one coin of value 5.
 ---------------------------------------------------------------------------*)
(* Goal 2.2*)

e (MAP_EVERY Q.EXISTS_TAC [`j+2`, `n`] THEN DECIDE_TAC);


(*---------------------------------------------------------------------------
     All the above sewn up into one tactic application.
 ---------------------------------------------------------------------------*)

val eight_three_five = prove(Term `!i. ?j k. i+8 = 3*j + 5*k`,
 Induct THEN ARW_TAC[] 
 THENL
  [MAP_EVERY Q.EXISTS_TAC [`1`, `1`] THEN DECIDE_TAC,
   Cases_on `k` THEN ARW_TAC [] 
   THENL
     [`2<j` by DECIDE_TAC
        THEN MAP_EVERY Q.EXISTS_TAC [`j-3`, `2`] THEN DECIDE_TAC,
      MAP_EVERY Q.EXISTS_TAC [`j+2`, `n`] THEN DECIDE_TAC
     ]
  ]);

(*---------------------------------------------------------------------------
     The semantics of THEN allow a more compact version.
 ---------------------------------------------------------------------------*)

val eight_three_five = prove(Term `!i. ?j k. i+8 = 3*j + 5*k`,
 Induct THEN ARW_TAC[] 
 THENL [MAP_EVERY Q.EXISTS_TAC [`1`, `1`],
        Cases_on `k` THEN ARW_TAC [] 
        THENL [`2<j` by DECIDE_TAC THEN 
               MAP_EVERY Q.EXISTS_TAC [`j-3`, `2`],
               MAP_EVERY Q.EXISTS_TAC [`j+2`, `n`]]]
 THEN DECIDE_TAC);
