(* 
 *   CODE FOR HOMEWORK 4
 *)

structure Evaluator = struct

  structure I = InternalRepresentation



  exception Evaluation of string

  fun evalError msg = raise Evaluation msg


  (* 
   *   Primitive operations
   *)

  fun primPlus (I.VInt a) (I.VInt b) = I.VInt (a+b)
    | primPlus _ _ = evalError "primPlus"

  fun primMinus (I.VInt a) (I.VInt b) = I.VInt (a-b)
    | primMinus _ _ = evalError "primMinus"

  fun primEq (I.VInt a) (I.VInt b) = I.VBool (a=b)
    | primEq (I.VBool a) (I.VBool b) = I.VBool (a=b)
    | primEq (I.VList a) (I.VList b) = I.VBool (checkListEqual a b)
    | primEq _ _ = I.VBool false

  and checkListEqual (a::aas) (b::bs) = if (getBool a b) then (checkListEqual aas bs)
                                          else false
    | checkListEqual [] [] = true
    | checkListEqual _ _ = false

  and getBool (I.VInt a) (I.VInt b) = (a=b)
    | getBool _ _ = false

  fun checkVBool (I.VBool a) (I.VBool b) = (a=b)
    | checkVBool _ _ = evalError "checkVBool"

  fun primLess (I.VInt a) (I.VInt b) = I.VBool (a<b)
    | primLess _ _ = I.VBool false

  fun primCons (I.VInt a) (I.VList l) = I.VList ((I.VInt a)::l)
    | primCons _ _ = evalError "primCons"

  fun primHd (I.VList (l::ls)) = l
    | primHd _ = evalError "primHd"

  fun primTl (I.VList (l::ls)) = I.VList (ls)
    | primTl _ = evalError "primTl"

  fun primInterval (I.VInt i) (I.VInt j) = if j < i then I.VList [] 
    else primCons (I.VInt i) (primInterval (primPlus (I.VInt i) (I.VInt 1)) (I.VInt j))
    | primInterval _ _ = evalError "primInterval"

  fun testMap f l = if l = [] then [] else (f (List.hd l))::(testMap f (List.tl l))

  fun lookup (name:string) [] = evalError ("failed lookup for "^name)
    | lookup name ((n,v)::env) = 
        if (n = name) then 
	  v
	else lookup name env 


  (*
   *   Evaluation functions
   * 
   *)


  fun eval _ (I.EVal v) = v
    | eval env (I.EFun (n,e)) = I.VClosure (n,e,env)
    | eval env (I.EIf (e,f,g)) = evalIf env (eval env e) f g
    | eval env (I.ELet (name,e,f)) = evalLet env name (eval env e) f
    | eval env (I.ELetFun (name,param,e,f)) = evalLetFun env name param e f
    | eval env (I.EIdent n) = lookup n env
    | eval env (I.EApp (e1,e2)) = evalApp env (eval env e1) (eval env e2)
    | eval env (I.EPrimCall1 (f,e1)) = f (eval env e1)
    | eval env (I.EPrimCall2 (f,e1,e2)) = f (eval env e1) (eval env e2)
    | eval env (I.ERecord fs) = I.VRecord (evalRecord env fs)
    | eval env (I.EField (e,s)) = evalField env (eval env e) s

  and evalRecord env ((s, e)::fs) = (s, (eval env e))::(evalRecord env fs)
    | evalRecord env [] = []

  and evalField env (I.VRecord r) s = lookup s r
    | evalField _ _ _ = evalError "evalField" 
      
  and evalApp _ (I.VClosure (n,body,env)) v = eval ((n,v)::env) body
    | evalApp _ (I.VRecClosure (f,n,body,env)) v = let
	  val new_env = [(f,I.VRecClosure (f,n,body,env)),(n,v)]@env
      in 
	  eval new_env body
      end
    | evalApp _ _ _ = evalError "cannot apply non-functional value"

  and evalIf env (I.VBool true) f g = eval env f
    | evalIf env (I.VBool false) f g = eval env g
    | evalIf _ _ _ _ = evalError "evalIf"
		       
  and evalLet env id v body = eval ((id,v)::env) body

  and evalLetFun env id param expr body = let
      val f = I.VRecClosure (id, param, expr, env)
  in
      eval ((id,f)::env) body
  end

  fun primMap (I.VClosure (n,e,env)) (I.VList l) = if (checkListEqual l []) then I.VList []
    else primCons (eval (env) (I.EApp ((I.EVal (I.VClosure (n,e,env))),(I.EVal (primHd (I.VList l)))))) (primMap (I.VClosure (n,e,env)) (primTl (I.VList l)))
    | primMap _ _ = evalError "primMap" 

  fun primFilter (I.VClosure (n,e,env)) (I.VList l) = if (checkListEqual l []) then I.VList []
    else if (checkVBool (eval (env) (I.EApp ((I.EVal (I.VClosure (n,e,env))),(I.EVal (primHd (I.VList l)))))) (I.VBool true)) 
      then primCons (primHd (I.VList l)) (primFilter (I.VClosure (n,e,env)) (primTl (I.VList l)))
        else (primFilter (I.VClosure (n,e,env)) (primTl (I.VList l)))
    | primFilter _ _ = evalError "primFilter"

  (* 
   *   Initial environment (already in a form suitable for the environment)
   *)

  val initialEnv = 
      [("add", I.VClosure ("a", 
			   I.EFun ("b", 
				   I.EPrimCall2 (primPlus,
						 I.EIdent "a",
						 I.EIdent "b")),
			   [])),
       ("sub", I.VClosure ("a", 
			   I.EFun ("b", 
				   I.EPrimCall2 (primMinus,
						 I.EIdent "a",
						 I.EIdent "b")),
			   [])),
       ("equal", I.VClosure ("a",
			  I.EFun ("b",
				  I.EPrimCall2 (primEq,
						I.EIdent "a",
						I.EIdent "b")),
			  [])),
       ("less", I.VClosure ("a",
			    I.EFun ("b",
				    I.EPrimCall2 (primLess,
						  I.EIdent "a",
						  I.EIdent "b")),
			    [])),
       ("nil", I.VList []),
       ("cons", I.VClosure ("a",
          I.EFun ("b",
            I.EPrimCall2 (primCons,
              I.EIdent "a",
              I.EIdent "b")),
          [])),
       ("hd", I.VClosure ("a", I.EPrimCall1 (primHd, I.EIdent "a"),[])),
       ("tl", I.VClosure ("a", I.EPrimCall1 (primTl, I.EIdent "a"),[])),
       ("interval", I.VClosure ("a",
          I.EFun ("b",
            I.EPrimCall2 (primInterval,
              I.EIdent "a",
              I.EIdent "b")),
          [])),
        ("map", I.VClosure ("f",
          I.EFun ("xs",
            I.EPrimCall2 (primMap,
              I.EIdent "f",
              I.EIdent "xs")),
          [])),
        ("filter", I.VClosure ("f",
          I.EFun ("xs",
            I.EPrimCall2 (primFilter,
              I.EIdent "f",
              I.EIdent "xs")),
          []))]
        
  
				 
end
