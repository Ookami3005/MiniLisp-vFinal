{-# OPTIONS_GHC -Wno-overlapping-patterns #-}
module Desugar where

import Parser
import Data.Foldable (sequenceA_)
import GHC.IOArray (boundsIOArray)
import Data.Binary.Builder (append)

--
-- Definición de los ASAs desazucarados
--
data ASA
  = Id String
  | Real Double
  | Boolean Bool
  | OpUn String ASA
  | OpBin String ASA ASA
  | Fun String ASA
  | App ASA ASA
  | If ASA ASA ASA
  | List [ASA]

instance Show ASA where
  --
  -- Representación de los ASAs como cadenas
  --
  show :: ASA -> String
  show (Id s) = s
  show (Real n) = show n
  show (Boolean b)
    | b = "#t"
    | otherwise = "#f"
  show (OpUn op arg) = "(" ++ op ++ " " ++ show arg ++ ")"
  show (OpBin op arg1 arg2) = "(" ++ op ++ " " ++ show arg1 ++ " " ++ show arg2 ++ ")"
  show (Fun param body) = "(lambda (" ++ param ++ ") " ++ show body ++ ")"
  show (App fun arg) = "(" ++ show fun ++ " " ++ show arg ++ ")"
  show (If condicion verdad falsa) = "(if " ++ show condicion ++ " " ++ show verdad ++ " " ++ show falsa ++ ")"

-- ************************************
-- Desendulzante oficial de MiniLisp v3
-- ************************************
desugar :: SASA -> ASA

--
-- Desendulzado sencillo
--
desugar (IdS s) = Id s
desugar (RealS n) = Real n
desugar (BooleanS b) = Boolean b
desugar (OpUnS op arg) = OpUn op (desugar arg)
desugar (PowS base expt) = OpBin "expt" (desugar base) (desugar expt)

--
-- Desendulzado para cuando solo se recibe un argumento
--
desugar (OpMultS op [x])
  -- Para operaciones relacionales, se desendulza directamente a #t
  | op `elem` ["=",">","<"] = Boolean True
  -- Para las demás, simplemente se devuelve el operando desendulzado
  | otherwise = desugar x

--
-- Desendulzado directo a una operación binaria
--
desugar (OpMultS op [x,y]) = OpBin op (desugar x) (desugar y)

--
-- Desendulzado para operaciones multiparamétricas
--
desugar (OpMultS op args@(x:y:xs))
  -- En operaciones relacionales, realizamos una "cadena" de ands
  | op `elem` ["=",">","<"] = OpBin "and" (OpBin op (desugar x) (desugar y)) (desugar $ OpMultS op (y:xs)) 
  -- Para las demás simplemente anidamos operaciones
  | otherwise = OpBin op (desugar $ OpMultS op (init args)) (desugar $ last args)

-- ***************
-- Expresiones Let
-- ***************

--
-- Let convencional
--

desugar (LetS [(var,value)] body) = App (Fun var (desugar body)) (desugar value)

-- Para este tipo de Let primero currificamos la función y despues empezamos a anidar aplicaciones a esta.
-- ! Esto es igual a desendulzar una aplicaación de función por lo que redirigimos la recursión a una aplicación

desugar (LetS binding body) = App (desugar $ AppS funS (init args)) (desugar $ last args) -- Se anida del inicio (más anidada) al final (menos anidada)
  where args = [snd x | x <- binding] -- Argumentos de la aplicación equivalente
        funS = FunS [fst x | x <- binding] body -- Función de la aplicación equivalente (sin currificar/desendulzar)

--
-- Let*
--

desugar (LetStarS [(var,value)] body) = App (Fun var (desugar body)) (desugar value)

-- La diferencia para los Let*, es que aplicamos cada lambda a su valor y despues de eso la anidamos
desugar (LetStarS binding body) = App (Fun var (desugar $ LetStarS (tail binding) body)) (desugar value)
  where (var,value) = head binding -- Se anidan del final (más anidada) al inicio (menos anidada)

-- *********
-- Funciones
-- *********

-- Caso directo
desugar (FunS [x] body) = Fun x (desugar body)

-- Currificación
desugar (FunS (x:xs) body) = Fun x (desugar $ FunS xs body)

-- ***********************
-- Aplicaciones de Función
-- ***********************

-- Caso directo: Currificamos y aplicamos el argumento
desugar (AppS fun [arg]) = App (desugar fun) (desugar arg)

-- Anidamos aplicaciones del inicio (más anidada) al final (menos anidada)
desugar (AppS fun args) = App (desugar $ AppS fun (init args)) (desugar $ last args)

desugar (IfS cond verdad falsa) = If (desugar cond) (desugar verdad) (desugar falsa)

desugar (CondS [(cond,thenExpr)] elseExpr) = If (desugar cond) (desugar thenExpr) (desugar elseExpr)
desugar (CondS ((cond,expr):clauses) elseExpr) = If (desugar cond) (desugar expr) (desugar $ CondS clauses elseExpr)

desugar (OpUnS "first" arg) = OpUn "first" (desugar arg)

desugar (OpUnS "last" arg) = OpUn "last" (desugar arg)

desugar (OpUnS "reverse" arg) = OpUn "reverse" (desugar arg)

desugar (OpUnS "length" arg) = OpUn "length" (desugar arg)

desugar (MapS arg1 arg2) = OpBin "map" (desugar arg1) (desugar arg2)

desugar (FilterS arg1 arg2) = OpBin "filter" (desugar arg1) (desugar arg2)

desugar (ListRefS arg1 arg2) = OpBin "listref" (desugar arg1) (desugar arg2)

desugar (ListS xs) = List [desugar y | y <- xs]

desugar (OpMultS "append" [x]) = desugar x

desugar (OpMultS "append" [x, y]) = OpBin "append" (desugar x) (desugar y)

desugar (OpMultS "append" args@(x:y:xs)) =
  OpBin "append" (desugar x) (desugar $ OpMultS "append" (y:xs))
