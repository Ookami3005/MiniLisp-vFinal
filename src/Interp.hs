module Interp where

import Desugar
import Parser
import Foreign.C (eNODEV)

data Value
  = RealV Double
  | BooleanV Bool
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

instance Show Value where
  show :: Value -> String
  show (RealV n) = show n
  show (BooleanV b)
    | b = "#t"
    | otherwise = "#f"
  show (Closure param cuerpo subenv) = "(lambda (" ++ param ++ ") " ++ show cuerpo ++ ")"

interp :: ASA -> Env -> Value
interp (Real n) env = RealV n
interp (Boolean n) env = BooleanV n
interp (Id s) env = buscaEnAmbiente s env

interp (OpUn "not" arg) env = BooleanV $ not $ arg''
  where arg' = interp arg env
        arg'' = bool $ strict arg'

interp (OpUn op arg) env = RealV $ eligeOpUn op arg''
  where arg' = interp arg env
        arg'' = num $ strict arg'

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
strict (Closure param body subenv) = Closure param body subenv
strict (Snap expr subenv) = strict $ interp expr subenv
