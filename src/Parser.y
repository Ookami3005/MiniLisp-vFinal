{
module Parser where

import Lexer

import Data.List
}

%name parser
%tokentype { Token }
%error { parseError }

{- Definición de los tokens -}

%token

real { TokenNum $$ }
boolean { TokenBool $$ }
ident {TokenId $$}
'(' { TokenPA }
')' { TokenPC }
'[' { TokenCA }
']' { TokenCC }
'+' { TokenSuma }
'-' { TokenResta }
'*' { TokenMult }
'/' { TokenDiv }
'<' { TokenLt }
'>' { TokenGt }
'=' { TokenEq }
add1 { TokenIncr }
sub1 { TokenDecr }
sqrt { TokenSqrt }
expt { TokenPow }
not { TokenNot }
and { TokenAnd }
let { TokenLet }
let1 { TokenLetStar }
lambda { TokenLambda }
or { TokenOr }
cond { TokenCond }
if { TokenIf }
else { TokenElse }
'"' { TokenQuot }
list { TokenList }
append { TokenAppend }
listref { TokenListRef }
length { TokenLength }
letrec { TokenLetRec }
first { TokenFirst }
last { TokenLast }
reverse { TokenReverse }
map { TokenMap }
filter { TokenFilter }

%%

{- Definición de la sintaxis concreta -}

ASA : real { RealS $1 }
| boolean { BooleanS $1 }
| ident { IdS $1 }
| '"' ident '"' {CadenaS $2}
| '(' list ')' {ListS []}
| '(' list Args ')' {ListS $3}
| '(' expt ASA ASA ')' { PowS $3 $4 }
| '(' listref ASA ASA ')' { ListRefS $3 $4 }
| '(' map ASA ASA ')' { MapS $3 $4 }
| '(' filter ASA ASA ')' { FilterS $3 $4 }
| '(' OpUnario ASA ')' { OpUnS $2 $3 }
| '(' OpMult Args ')' { OpMultS $2 $3 }
| '(' let '(' Binding ')' ASA ')' { LetS $4 $6 }
| '(' let1 '(' Binding ')' ASA ')' { LetStarS $4 $6 }
| '(' letrec '(' ident ASA ')' ASA ')' { LetRecS [($4,$5)] $7 }
| '(' lambda '(' Params ')' ASA ')' { FunS $4 $6}
| '(' ASA Args ')' { AppS $2 $3 }
| '(' if ASA ASA ASA ')' { IfS $3 $4 $5 }
| '(' cond '(' Clauses ')' '(' else ASA ')' ')' {CondS $4 $8 }


OpUnario : add1 { "add1" }
| sub1 { "sub1" }
| sqrt { "sqrt" }
| not { "not" }
| first { "first" }
| last { "last" }
| reverse { "reverse" }
| length { "length" }


OpMult : '+' { "+" }
| '-' { "-" }
| '*' { "*" }
| '/' { "/" }
| '<' { "<" }
| '>' { ">" }
| '=' { "=" }
| and { "and" }
| or { "or" }
| append { "append" }

Binding : '[' ident ASA ']' { [($2,$3)] }
  | '[' ident ASA ']' Binding { ($2,$3):$5 }

Args : ASA { [$1] }
  | ASA Args { $1:$2 }

Params : ident { [$1] }
  | ident Params { $1:$2 }

Clauses : '[' ASA ASA ']' { [($2, $3)] }
  | '[' ASA ASA ']' Clauses { ($2, $3):$5 }

Cadenas : '"' ident '"' { [CadenaS $2] }
| '"' ident '"' Cadenas { (CadenaS $2):$4 }


Listas: '(' list Args ')' { [ListS $3] }
| '(' list Args ')' Listas { (ListS $3):$5 }

{

parseError :: [Token] -> a
parseError x = error "Parse error"

data SASA
  = IdS String
  | RealS Double
  | BooleanS Bool
  | CadenaS String
  | ListS [SASA]
  | OpUnS String SASA
  | PowS SASA SASA
  | ListRefS SASA SASA
  | MapS SASA SASA
  | FilterS SASA SASA
  | OpMultS String [SASA]
  | LetS [(String,SASA)] SASA
  | LetStarS [(String,SASA)] SASA
  | LetRecS [(String,SASA)] SASA
  | FunS [String] SASA
  | AppS SASA [SASA]
  | CondS [(SASA, SASA)] SASA
  | IfS SASA SASA SASA


instance Show SASA where
  show :: SASA -> String
  show (IdS s) = s
  show (RealS n) = show n
  show (BooleanS b)
    | b = "#t"
    | otherwise = "#f"
  show (OpUnS op arg) = "(" ++ op ++ " " ++ show arg ++ ")"
  show (PowS base expt) = "(expt " ++ show base ++ " " ++ show expt ++")"
  show (OpMultS op args) = "(" ++ op ++ (foldl1 (++) [' ':show arg | arg <- args]) ++ ")"
  show (LetS bind body) =  "(let (" ++ init (foldl1 (++) ["[" ++ (fst x) ++ " " ++ show (snd x) ++ "] " | x <- bind]) ++ ") " ++ show body ++ ")"
  show (LetStarS bind body) = "(let* (" ++ init (foldl1 (++) ["[" ++ (fst x) ++ " " ++ show (snd x) ++ "] " | x <- bind]) ++ ") " ++ show body ++ ")"
  show (FunS params body) = "(lambda (" ++ init (foldl1 (++) [id ++ " " | id <- params]) ++ ") " ++ show body ++ ")"
  show (AppS fun args) = "(" ++ show fun ++ foldl1 (++) [' ':show arg | arg <- args] ++ ")"
  show (CondS clauses elseExpr) = "(cond (" ++ init (foldl1 (++) ["[" ++ show (fst x) ++ " " ++ show (snd x) ++ "] " | x <- clauses]) ++ ") " ++ "(else " ++ show elseExpr ++ "))"
  show (IfS cond thenExpr elseExpr) = "(if " ++ show cond ++ " " ++ show thenExpr ++ " " ++ show elseExpr ++ ")"
  show (CadenaS cadena) = show cadena
  show (ListS list) = "(list "++ init (foldl1 (++) [show x++" " | x <- list])++")"
  show (ListRefS index list) = "(list-ref "++show index ++ " " ++ show list ++ ")"
  show (MapS lambda list) = "(map "++show lambda++" "++show list++")"
  show (FilterS lambda list) = "(filter "++show lambda++" "++show list++")"
  show (LetRecS bind body) = "(letrec (" ++ (foldl1 (++) [(fst x) ++ " " ++ show (snd x) | x <- bind]) ++ ") " ++ show body ++ ")"

}
