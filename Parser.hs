module Parser where
import Text.ParserCombinators.Parsec hiding (spaces)
import Text.Parsec.String
import Text.Parsec.Language
import Text.Parsec.Token
import Text.Parsec.Expr
import Control.Monad

data LogicalOp = And | Or | Implies | DoubleImplies deriving (Show,Read)

data CmpOp = Lt | Lte | Gt | Gte | Eq | NEq deriving (Show,Read)



data Expression = IntNode Integer
                | DoubleNode Double
                | BoolNode Bool
                | Not Expression
                | LogicalBinOp LogicalOp Expression Expression
                | CmpNode CmpOp Expression Expression
                | Id String
                | List [Expression]
                | Assign Expression Expression -- the first Expression can only be of type Id String)
                | Tuple [Expression]
                | Addition Expression Expression
                | Subtraction Expression Expression
                | Multiplication Expression Expression
                | Division Expression Expression
                | Modulus Expression Expression
                | Negation Expression deriving (Show,Read)

data Statement = PrintStatement Expression 
               | Eval Expression
    deriving (Show,Read)

-- data FunctionBody = FunctionBody Expression Expression  deriving (Show,Read) --  


lexer :: TokenParser()
lexer = makeTokenParser (haskellStyle {opStart = oneOf "+-*/%|&~=<>"
                                   , opLetter = oneOf "+-*/%|&~=<>"})


parseExpr :: Parser Expression
parseExpr = buildExpressionParser table parseTerm

-- for getting associativity right
table = [[binary "=" (Assign) AssocRight]
        ,[binary "==" (CmpNode Eq) AssocNone,binary "/=" (CmpNode NEq) AssocNone
        ,binary "<" (CmpNode Lt) AssocNone , binary "<=" (CmpNode Lte) AssocNone
        ,binary ">" (CmpNode Gt) AssocNone , binary ">=" (CmpNode Gte) AssocNone]
        ,[prefix "~" (Not)]
        ,[binary "&&"(LogicalBinOp And) AssocRight, binary "||" (LogicalBinOp Or) AssocRight
         ,binary "->" (LogicalBinOp Implies) AssocLeft , binary "<->" (LogicalBinOp DoubleImplies)  AssocLeft]
        ,[prefix "-" (Negation), prefix "+" (id) ]
        ,[binary "*" (Multiplication) AssocLeft, binary "/" (Division) AssocLeft,
         binary "%" (Modulus) AssocLeft]
        ,[binary "+" (Addition) AssocLeft, binary "-" (Subtraction) AssocLeft]]

binary name fun assoc = Infix (do{ reservedOp lexer name; return fun }) assoc
prefix  name fun      = Prefix (do{ reservedOp lexer name; return fun })
postfix name fun      = Postfix (do{ reservedOp lexer name; return fun })


parseNumber :: Parser Expression
parseNumber = do
    num <- naturalOrFloat lexer
    case num of
        Left n -> return $ IntNode n
        Right n -> return $ DoubleNode n

-- to parse the strings
-- will identify if its a BoolNode as well
parseString :: Parser Expression
parseString = do
    str <- identifier lexer
    return $ case str of
        "True" -> BoolNode True
        "False" -> BoolNode False
        otherwise -> Id str

-- this parses term 
-- expr is something like  term (operation) term
-- term can also be an expression enclosed inside parens
--
parseTerm :: Parser Expression
parseTerm = parens lexer parseExpr
            <|> parseNumber 
            <|> parseString




parseExprList :: Parser Expression
parseExprList = liftM List $ sepBy parseTerm (comma lexer) --liftM makes the List Constructor Monadic
{- this is the same as above
parseExprList = do
    arr <- sepBy parseTerm (comma lexer)
    return $ List 
-}
-- same thing as above going on in parseTuple
parseTuple :: Parser Expression
parseTuple = liftM Tuple $ sepBy parseTerm (comma lexer)


--  top level parser for Expression type
--  combines tuple parser,list parser and normal expression parser
--
parseExpression :: Parser Expression
parseExpression = do
    s <- (try $ parseExpr)
        <|> ( try $ parens lexer parseTuple)
        <|> brackets lexer parseExprList
    return s

-- parses a print statement
-- print x
-- used when you want to print the output of an evaluation
parsePrint :: Parser Statement
parsePrint = do
    reserved lexer "print"
    expr <- parseExpression
    return $ PrintStatement expr

-- parses Evaluation statement
-- it is just an expression with no keyword in front of  it
parseEvalStatement :: Parser Statement
parseEvalStatement = do
    whiteSpace lexer
    s <- parseExpression
    eof
    return $ Eval s

-- parses statement
-- Two  types
-- a print statement
-- and an eval statement which is just a statement that doesnt 
-- begin with a keyword like print or others
parseStatement :: Parser Statement
parseStatement = (try $ parsePrint)
                <|> parseEvalStatement

-- parses string and returns the expression as string
parseInput str = 
    let ret = parse parseStatement "Wrong expr" str in
        case ret of
            Left e -> show e
            Right val -> show val

-- for running interactively
readExpr = interact (unlines . (map parseInput) . lines )