module Lexer where

import Data.Char

-- Definición de tipo de dato Token
data Token
  = TokenNum {numero :: Double}
  | TokenBool {boolean :: Bool}
  | TokenId {ident :: String}
  | TokenPA -- Parentesis que abre
  | TokenPC -- Parentesis que cierra
  | TokenCA -- Corchete que abre
  | TokenCC -- Corchete que cierra
  | TokenSuma
  | TokenResta
  | TokenMult
  | TokenDiv
  | TokenIncr
  | TokenDecr
  | TokenSqrt
  | TokenPow
  | TokenLt
  | TokenGt
  | TokenEq
  | TokenNot
  | TokenOr
  | TokenAnd
  | TokenLet
  | TokenLetStar
  | TokenLambda
  | TokenIf
  | TokenCond
  | TokenElse
  -- Nuevos
  | TokenList
  | TokenQuot
  | TokenAppend
  | TokenAppendList
  | TokenListRef
  | TokenLength
  | TokenLetRec
  | TokenFirst
  | TokenLast
  | TokenReverse
  | TokenMap
  | TokenFilter

-- Definición de instancia Show
instance Show Token where
  show :: Token -> String
  show (TokenNum n) = show n
  show (TokenBool True) = "#t"
  show (TokenBool False) = "#f"
  show (TokenId a) = a
  show TokenPA = "("
  show TokenPC = ")"
  show TokenCA = "["
  show TokenCC = "]"
  show TokenQuot = "\""
  show TokenSuma = "+"
  show TokenResta = "-"
  show TokenMult = "*"
  show TokenDiv = "/"
  show TokenLt = "<"
  show TokenGt = ">"
  show TokenEq = "="
  show TokenIncr = "add1"
  show TokenDecr = "sub1"
  show TokenSqrt = "sqrt"
  show TokenPow = "expt"
  show TokenNot = "not"
  show TokenAnd = "and"
  show TokenOr = "or"
  show TokenLet = "let"
  show TokenLetStar = "let*"
  show TokenLambda = "lambda"
  show TokenCond = "cond"
  show TokenIf = "if"
  show TokenElse = "else"
  show TokenList = "list"
  show TokenAppend = "append"
  show TokenAppendList = "append-list"
  show TokenListRef = "list-ref"
  show TokenLength = "length"
  show TokenLetRec = "letrec"
  show TokenFirst = "first"
  show TokenLast = "last"
  show TokenReverse = "reverse"
  show TokenMap = "map"
  show TokenFilter = "filter"


-- Función auxiliar que verifica que un número tenga los simbolos adecuados
esNumeroPunto :: Char -> Bool
esNumeroPunto c = isDigit c || elem c ['.', 'e', '-']

{-
- ###############################################
- Definición del Analizador léxico de Minilisp v3
- ###############################################
-}

lexer :: String -> [Token]

-- Cadena vacía
lexer [] = []

--
-- Distinción del simbolo '-' como signo de un número negativo o como el operador resta
--
lexer ('-' : x : xs)
  | isDigit x = separaNumero (x : xs)
  | otherwise = TokenResta : lexer (x : xs)
  where
    separaNumero :: String -> [Token]
    separaNumero texto =
      let (num, resto) = span esNumeroPunto texto
       in TokenNum (-(read num :: Double)) : lexer resto

-- Símbolos que representan operaciones
lexer (' ' : xs) = lexer xs
lexer ('(' : xs) = TokenPA : lexer xs
lexer (')' : xs) = TokenPC : lexer xs
lexer ('[' : xs) = TokenCA : lexer xs
lexer (']' : xs) = TokenCC : lexer xs
lexer ('+' : xs) = TokenSuma : lexer xs
lexer ('*' : xs) = TokenMult : lexer xs
lexer ('/' : xs) = TokenDiv : lexer xs
lexer ('<' : xs) = TokenLt : lexer xs
lexer ('>' : xs) = TokenGt : lexer xs
lexer ('=' : xs) = TokenEq : lexer xs
lexer ('"' : xs) = TokenQuot : lexer xs

-- Booleanos
lexer ('#' : y : xs)
  | y == 't' = TokenBool True : lexer xs
  | y == 'f' = TokenBool False : lexer xs

--
-- Números positivos
--
lexer expr@(x : xs)
  | isDigit x = separaNumero expr
  where
    separaNumero :: String -> [Token]
    separaNumero texto =
      let (num, resto) = span esNumeroPunto texto
       in TokenNum (read num :: Double) : lexer resto

-- Palabras que representan operaciones
lexer ('a' : 'd' : 'd' : '1' : xs) = TokenIncr : lexer xs
lexer ('a':'p':'p':'e':'n':'d':'-':'l':'i':'s':'t':xs) = TokenAppendList : lexer xs
lexer ('a':'p':'p':'e':'n':'d':xs) = TokenAppend : lexer xs
lexer ('c':'o':'n':'d':xs) = TokenCond : lexer xs
lexer ('e':'l':'s':'e':xs) = TokenElse : lexer xs
lexer ('e' : 'x' : 'p' : 't' : xs) = TokenPow : lexer xs
lexer ('f':'i':'l':'t':'e':'r':xs) = TokenFilter : lexer xs
lexer ('f':'i':'r':'s':'t':xs) = TokenFirst : lexer xs
lexer ('i':'f':xs) = TokenIf : lexer xs
lexer ('l':'i':'s':'t':'-':'r':'e':'f':xs) = TokenListRef : lexer xs
lexer ('l':'i':'s':'t':xs) = TokenList : lexer xs
lexer ('s' : x : y : z : xs)
  | word == "ub1" = TokenDecr : lexer xs
  | word == "qrt" = TokenSqrt : lexer xs
  where
    word = [x, y, z]

lexer ('m':'a':'p':xs) = TokenMap : lexer xs
lexer ('n' : 'o' : 't' : xs) = TokenNot : lexer xs
lexer ('a' : 'n' : 'd' : xs) = TokenAnd : lexer xs
lexer ('o' : 'r' : xs) = TokenOr : lexer xs

lexer ('l':'a':'s':'t':xs) = TokenLast : lexer xs


lexer ('l':'e':'n':'g':'t':'h':xs) = TokenLength : lexer xs

--
-- Expresiones Let
--
lexer ('l':'e':'t':'r':'e':'c':xs) = TokenLetRec : lexer xs
lexer ('l' : 'e' : 't' : '*' : xs) = TokenLetStar : lexer xs
lexer ('l' : 'e' : 't' : xs) = TokenLet : lexer xs



--
-- Funciones lambda
--
lexer ('l':'a':'m':'b':'d':'a' : xs) = TokenLambda : lexer xs

lexer ('r':'e':'v':'e':'r':'s':'e':xs) = TokenReverse : lexer xs

-- Identificadores:
--
-- Como el id puede tener cualquier cosa lo que hacemos aquí es recibir en lexer algo, una cadena, y ver si
-- en let (donde llaman a los id) y ver hasta donde es el identificador, para convertilos en tokens validos.
-- - Daliz
--
lexer (x : xs)
  | isAlpha x =
      let (identificador, resto) = span esParteDeIdentificador (x : xs)
       in TokenId identificador : lexer resto
  where
    -- Función auxiliar. Además de aceptar como identificador cualquier letra, o cadena, tambien acepta como id simbolos especiales
    esParteDeIdentificador c = isAlphaNum c || elem c ['-', '_', '?', '!']


--
-- Lexema no definido
--
lexer other = error "Hay un error sintáctico en tu programa"
