module Parser where
import           Control.Monad
import           Text.Parsec.Expr
import           Text.Parsec.Language
import           Text.Parsec.String
import           Text.Parsec.Token
import           Text.ParserCombinators.Parsec hiding (spaces)

data LogicalOp = And | Or | Xor | Implies | DoubleImplies deriving (Show,Read)

data CmpOp = Lt | Lte | Gt | Gte | Equal | NEqual deriving (Show,Read)



data Expression = IntNode Integer
                | DoubleNode Double
                | BoolNode Bool
                | Not Expression
                | LogicalBinOp LogicalOp Expression Expression
                | CmpNode CmpOp Expression Expression
                | Id String
                | Invoke String Expression -- function invocation. string followed by a tuple. parsed with parseFuncInvocation
                | List [Expression]
                | Assign Expression Expression -- the first Expression can only be of type Id String)
                | Tuple [Expression]
                | Addition Expression Expression
                | Subtraction Expression Expression
                | Multiplication Expression Expression
                | Division Expression Expression
                | Modulus Expression Expression
                | Power Expression Expression
                | Negation Expression deriving (Show,Read)

data Statement = PrintStatement Expression
               | Eval Expression
               | Define FunctionBody
    deriving (Show,Read)

data FunctionBody = FunctionBody String Expression [Statement] deriving (Show,Read) -- the 2nd Expression after the
-- FunctionBody constructor should technically be just a Tuple
-- Tuple [Expression] was included in Expression solely for this purpose
-- We'll take care of this sort of weird representation of FunctionBody by using only
-- the parseTuple for parsing the 1st expression

-- i dont know if this is the best way to  represent a  function
-- but this works. Change this if i find a better way
-- we just represent the function as a string followed by a tuple,
-- which is then followed by bunch of statements that are separated by
-- semicolons and wrapped around braces({ and }) and the statements are all
-- put into a list of statments and then we return the representation
-- this is used in parseDefineStatement
parseFunctionBody :: Parser FunctionBody
parseFunctionBody = do
    funcName <- identifier lexer
    args <- parens lexer parseTuple
    statements <- braces lexer $ sepEndBy parseStatement (semi lexer)
    return $ FunctionBody  funcName args statements


--------------------------------------------------------------------------------------
-- this pretty much sets up identifier grammar and some other stuff as well
-- the tokens are haskellStyle tokens
lexer :: TokenParser()
lexer = makeTokenParser (haskellStyle {opStart = oneOf "^+-*/%|&~=<>"
                                   , opLetter = oneOf "^+-*/%|&~=<>"})


-- uses the table and parseTerm function below to parse the expression
parseExpr :: Parser Expression
parseExpr = buildExpressionParser table parseTerm

-- for getting associativity right
-- parses the expression correctly with the specified operators
-- God bless the people who did this
-- Cuz it wouldve been an absolute pain
table = [[binary "=" (Assign) AssocRight]
        ,[binary "==" (CmpNode Equal) AssocNone,binary "/=" (CmpNode NEqual) AssocNone
        ,binary "<" (CmpNode Lt) AssocNone , binary "<=" (CmpNode Lte) AssocNone
        ,binary ">" (CmpNode Gt) AssocNone , binary ">=" (CmpNode Gte) AssocNone]
        ,[prefix "~" (Not)]
        ,[binary "&&"(LogicalBinOp And) AssocRight, binary "||" (LogicalBinOp Or) AssocRight
         ,binary "->" (LogicalBinOp Implies) AssocLeft , binary "<->" (LogicalBinOp DoubleImplies)  AssocLeft
         ,binary "^" (LogicalBinOp Xor) AssocRight]
        ,[prefix "-" (Negation), prefix "+" (id) ]
        ,[binary "**" (Power) AssocLeft]
        ,[binary "*" (Multiplication) AssocLeft, binary "/" (Division) AssocLeft,
         binary "%" (Modulus) AssocLeft]
        ,[binary "+" (Addition) AssocLeft, binary "-" (Subtraction) AssocLeft]]

binary name fun assoc = Infix (do{ reservedOp lexer name; return fun }) assoc
prefix  name fun      = Prefix (do{ reservedOp lexer name; return fun })
postfix name fun      = Postfix (do{ reservedOp lexer name; return fun })

-- parses a number , any type using the naturalOrFloat from parsec
parseNumber :: Parser Expression
parseNumber = do
    num <- naturalOrFloat lexer
    case num of
        Left n  -> return $ IntNode n
        Right n -> return $ DoubleNode n

-- to parse the strings
-- will identify if its a BoolNode as well
parseString :: Parser Expression
parseString = do
    str <- identifier lexer
    return $ case str of
        "True"    -> BoolNode True
        "False"   -> BoolNode False
        otherwise -> Id str

-- parses function invocation
-- parses a string
-- then a tuple
parseFuncInvocation :: Parser Expression
parseFuncInvocation = do
    funcName <- identifier lexer
    arguments <- parens lexer parseTuple
    return $ Invoke funcName arguments


-- this parses term
-- expr is something like  term (operation) term
-- term can also be an expression enclosed inside parens
-- Im leaving this only as a definition of a term
-- I couldve done parens lexer parseExpression but since i dont have array
-- operations ,such as + and all ,defined ,I chose not to include them
parseTerm :: Parser Expression
parseTerm = parens lexer parseExpr
            <|> parseNumber
            <|> (try $ parseFuncInvocation)
            <|> parseString




parseExprList :: Parser Expression
parseExprList = liftM List $ sepBy parseExpression (comma lexer) --liftM makes the List Constructor Monadic
{- this is the same as above
parseExprList = do
    arr <- sepBy parseTerm (comma lexer)
    return $ List arr
-}
-- same thing as above going on in parseTuple
parseTuple :: Parser Expression
parseTuple = liftM Tuple $ sepBy parseExpression (comma lexer)


--  top level parser for Expression type
--  combines tuple parser,list parser and normal expression parser
-- Im not parsing for a tuple in expression
-- Because i plan to use the Tuple [Expression] only for function definitions and
-- invocations
parseExpression :: Parser Expression
parseExpression = do
    s <- (try $ parseExpr)
        <|> (try $ parens lexer $ brackets lexer parseExprList)
        <|> brackets lexer parseExprList
    return s

-- parses a print statement
-- print x and something like that
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
    return $ Eval s

parseDefineStatement :: Parser Statement
parseDefineStatement = do
    reserved lexer "def"
    functionBod <- parseFunctionBody
    return $ Define functionBod


-- parses statement
-- Two  types
-- a print statement
-- and an eval statement which is just a statement that doesnt
-- begin with a keyword like print or others
parseStatement :: Parser Statement
parseStatement = (try $ parsePrint)
                <|> (try $ parseDefineStatement)
                <|> parseEvalStatement

parseInput :: String -> Statement
parseInput str =
    let ret = parse parseStatement "Error in Parsing " str in
        case ret of
            Left e   -> error $ show e
            Right st -> st

-- parses string and returns the expression as string
parseInputAsString str =
    let ret = parse parseStatement "Wrong expr" str in
        case ret of
            Left e    -> show e
            Right val -> show val

-- for running interactively
readExpr = interact (unlines . (map parseInputAsString) . lines )
