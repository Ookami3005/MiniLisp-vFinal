module Interp where

import Desugar
import Parser
import Foreign.C (eNODEV)

data Value
  = RealV Double
  | BooleanV Bool
  | CadenaV String
  | ListV [Value]
  | Closure String ASA Env
  | Snap ASA Env

type Env = [(String,Value)]

buscaEnAmbiente :: String -> Env -> Value
buscaEnAmbiente var [] = error "Variable libre"
buscaEnAmbiente var ((ident,value):xs)
  | var == ident = value
  | otherwise = buscaEnAmbiente var xs

eligeOpUn :: (Floating a) => String -> (a -> a)
eligeOpUn "add1" = (+1)
eligeOpUn "sub1" = (+ (-1))
eligeOpUn "sqrt" = (** (1/2))

eligeOpBin :: (Floating a) => String -> (a -> a -> a)
eligeOpBin "+" = (+)
eligeOpBin "-" = (-)
eligeOpBin "*" = (*)
eligeOpBin "/" = (/)
eligeOpBin "expt" = (**)

num :: Value -> Double
num (RealV n) = n

bool :: Value -> Bool
bool (BooleanV b) = b

str :: Value -> String
str (CadenaV cad) = cad

lst :: Value -> [Value]
lst (ListV list) = list

instance Show Value where
  show :: Value -> String
  show (RealV n) = show n
  show (CadenaV cad) = show cad
  show (ListV []) = "(list)"
  show (ListV list) = "(list "++init (foldl1 (++) [show x ++ " " | x <- list]) ++ ")"
  show (BooleanV b)
    | b = "#t"
    | otherwise = "#f"
  show (Closure param cuerpo subenv) = "(lambda (" ++ param ++ ") " ++ show cuerpo ++ ")"

interp :: ASA -> Env -> Value
interp (Real n) env = RealV n
interp (Boolean n) env = BooleanV n
interp (Cadena cad) env = CadenaV cad
interp (List list) env = ListV [interp x env| x <- list]
interp (Id s) env = buscaEnAmbiente s env

interp (OpUn "not" arg) env = BooleanV $ not $ arg''
  where arg' = interp arg env
        arg'' = bool $ strict arg'

interp (OpUn "first" (List list)) env = interp (head $ list) env
interp (OpUn "first" (Cadena cad)) env = CadenaV $ [head $ cad]

interp (OpUn "last" (List list)) env = interp (last $ list) env
interp (OpUn "last" (Cadena cad)) env = CadenaV $ [last $ cad]

interp (OpUn "reverse" (List list)) env = ListV $ reverse $ [interp x env | x <- list]
interp (OpUn "reverse" (Cadena cad)) env = CadenaV $ reverse $ cad

interp (OpUn "length" (List list)) env = RealV $ fromIntegral $ length list
interp (OpUn "length" (Cadena cad)) env = RealV $ fromIntegral $ length cad

interp (OpUn op arg) env = RealV $ eligeOpUn op arg''
  where arg' = interp arg env
        arg'' = num $ strict arg'

interp (OpBin "list-ref" index list) env = [interp x env | x <- elems] !! (round index'')
  where index'= interp index env
        index'' = num $ strict index'
        (List elems) = list

interp (OpBin "map" fun (List list)) env = ListV $ [interp (App fun x) env| x <- list]

interp (OpBin "filter" fun (List [])) env = ListV []
interp (OpBin "filter" (Boolean b) list) env
  | b = interp list env
  | otherwise = ListV []
interp (OpBin "filter" fun@(Fun param body) (List (x:xs))) env
  | bool $ interp (App fun x) env = ListV $ (interp x env):(lst $ interp (OpBin "filter" fun (List xs)) env)
  | otherwise = interp (OpBin "filter" fun (List xs)) env

interp (OpBin "append" arg1 arg2) env = CadenaV $ arg1'' ++ arg2''
  where arg1'= interp arg1 env
        arg1'' = str $ strict $ arg1'
        arg2'= interp arg2 env
        arg2'' = str $ strict $ arg2'

interp (OpBin "<" arg1 arg2) env = BooleanV $ arg1'' < arg2''
  where (arg1', arg2') = (interp arg1 env, interp arg2 env)
        (arg1'', arg2'') = (num $ strict arg1', num $ strict arg2')

interp (OpBin ">" arg1 arg2) env = BooleanV $ arg1'' > arg2''
  where (arg1', arg2') = (interp arg1 env, interp arg2 env)
        (arg1'', arg2'') = (num $ strict arg1', num $ strict arg2')

interp (OpBin "=" arg1 arg2) env = BooleanV $ arg1'' == arg2''
  where (arg1', arg2') = (interp arg1 env, interp arg2 env)
        (arg1'', arg2'') = (num $ strict arg1', num $ strict arg2')

interp (OpBin "and" arg1 arg2) env = BooleanV $ arg1'' && arg2''
  where (arg1', arg2') = (interp arg1 env, interp arg2 env)
        (arg1'', arg2'') = (bool $ strict arg1', bool $ strict arg2')

interp (OpBin "or" arg1 arg2) env = BooleanV $ arg1'' || arg2''
  where (arg1', arg2') = (interp arg1 env, interp arg2 env)
        (arg1'', arg2'') = (bool $ strict arg1', bool $ strict arg2')

interp (OpBin op arg1 arg2) env = RealV $ eligeOpBin op arg1'' arg2''
  where (arg1', arg2') = (interp arg1 env, interp arg2 env)
        (arg1'', arg2'') = (num $ strict arg1', num $ strict arg2')

interp (If cond thenExpr elseExpr) env
  | interpCond = interp thenExpr env
  | otherwise = interp elseExpr env
    where interpCond = bool $ strict $ interp cond env

interp (Fun param cuerpo) env = Closure param cuerpo env

interp (App fun arg) env = interp cuerpo ((param,Snap arg env):subenv)
  where (Closure param cuerpo subenv) = strict $ interp fun env

strict :: Value -> Value
strict (RealV n) = RealV n
strict (BooleanV b) = BooleanV b
strict (CadenaV str) = CadenaV str
strict (ListV list) = ListV list
strict (Closure param body subenv) = Closure param body subenv
strict (Snap expr subenv) = strict $ interp expr subenv
