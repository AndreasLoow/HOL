open arithmeticTheory HolKernel boolLib Parse

fun tprint s = print (StringCvt.padRight #" " 60 s)

fun fail() = (print "FAILED\n"; OS.Process.exit OS.Process.failure)

val _ = tprint "Testing that I can parse num$0"
val _ = (Parse.Term`num$0`; print "OK\n")
        handle HOL_ERR _ => fail()

val _ = tprint "Testing that I can't parse num$1"
val _ = (Parse.Term`num$1`; fail()) handle HOL_ERR _ => print "OK\n";


val _ = tprint "Testing that bool$0 fails"
val _ = (Parse.Term`bool$0`; fail()) handle HOL_ERR _ => print "OK\n"

val _ = tprint "Testing that num$01 fails"
val _ = (Parse.Term`num$01`; fail()) handle HOL_ERR _ => print "OK\n"

val _ = let
  val _ = tprint "Anthony's pattern-overloading bug"
  val b2n_def = new_definition("b2n_def", ``b2n b = if b then 1 else 0``)
  val _ = overload_on ("foo", ``\(x:num#'a),(y:num#'b). b2n (FST x = FST y)``)
  val res = trace ("PP.catch_withpp_err", 0) term_to_string ``foo(x,y)``
            handle Fail _ => ""
in
  if res <> "" then print "OK\n" else fail()
end
