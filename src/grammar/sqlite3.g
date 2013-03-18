options {
  language="Cpp";
  genHashLines=false;
}

class Sqlite3Lexer extends Lexer;
options {
  k=2;
  exportVocab=sqlite3;
  caseSensitive=false;
}

tokens {
  AUTOINCREMENT="AUTOINCREMENT";
  AS="AS";
  ASC="ASC";
  CASE_T="CASE";
  CHECK="CHECK";
  CREATE="CREATE";
  COLLATE="COLLATE";
  CONFLICT="CONFLICT";
  CONSTRAINT="CONSTRAINT";
  CURRENT_TIME="CURRENT_TIME";
  CURRENT_DATE="CURRENT_DATE";
  CURRENT_TIMESTAMP="CURRENT_TIMESTAMP";
  DEFAULT="DEFAULT";
  DESC="DESC";
  ELSE_T="ELSE";
  END="END";
  ESCAPE="ESCAPE";
  GLOB="GLOB";
  KEY="KEY";
  LIKE="LIKE";
  TABLE="TABLE";
  IF_T="IF";
  IS="IS";
  NOT="NOT";
  NULL_T="NULL";
  MATCH="MATCH";
  EXISTS="EXISTS";
  ON="ON";
  PRIMARY="PRIMARY";
  REFERENCES="REFERENCES";
  REGEXP="REGEXP";
  TEMPORARY="TEMPORARY";
  TEMP="TEMP";
  THEN="THEN";
  UNIQUE="UNIQUE";
  WHEN="WHEN";

//ast

  TYPE_NAME;
  COLUMNDEF;
  COLUMNCONSTRAINT;
  TABLECONSTRAINT;
  CREATETABLE;
}

protected
DIGIT : '0'..'9' ;

protected DOT:;

ID
  :
  ('a'..'z'|'_') ('a'..'z'|'0'..'9'|'_')*
  ;

QUOTEDID
	: '`' ( ~('`') )* '`'
	| '[' ( ~(']') )*  ']'
	| '"' ( ~('"') )* '"'
	;

NUMERIC
    : ( (DIGIT)+ ( '.' (DIGIT)* )?
      | '.' { _ttype=DOT; } (DIGIT)+)
      ( 'e' (PLUS|MINUS)? (DIGIT)+ )?
	; 

SL_COMMENT
  :
  "//" (~'\n')* '\n' { _ttype = ANTLR_USE_NAMESPACE(antlr)Token::SKIP; newline(); }
  ;

ML_COMMENT
  : "/*"
  ( { LA(2)!='/' }? '*'
  | '\n' { newline(); }
  | ~('*'|'\n')
  )*
  "*/" 
  {$setType(ANTLR_USE_NAMESPACE(antlr)Token::SKIP);}
  ;

WS
  :
  ( ' '
  | '\t'
  | '\r'
  | '\n' {newline();}
  ) { _ttype = ANTLR_USE_NAMESPACE(antlr)Token::SKIP; }
  ;

STRING
  :
//  '"' ( ESC_SEQ | ~('\\'|'"') )* '"'
  '\'' ( ~('\'') )* '\''
  ;

//protected
//ESC_SEQ
//    :   '\\' ('b'|'t'|'n'|'f'|'r'|'\"'|'\''|'\\')
//    ;
    
LPAREN	:	'(';
RPAREN	:	')';
COMMA	:	',';
SEMI 	:	';';
PLUS    :   '+';
MINUS   :   '-';
STAR    :   '*';
TILDE : '~';
AMPERSAND: '&';
BITOR: '|';
OROP: "||";
EQUAL: '=';
EQUAL2: "==";
GREATER: '>';
GREATEREQUAL: ">=";
LOWER: '<';
LOWEREQUAL: "<=";
UNEQUAL: "!=";
UNEQUAL2: "<>";
BITWISELEFT: "<<";
BITWISERIGHT: ">>";

// parser

class Sqlite3Parser extends Parser;
options {
  k=2;
  buildAST = true;
}

id : ID | QUOTEDID ;

databasename
  :
  id
  ;
	
tablename
  :
  id
  ;
	
columnname
  :
  id
  ;
    
identifier
  :
  ((databasename)? DOT)? tablename
  ;

collationname
  :
  ID
  ;

signednumber
  : (PLUS | MINUS)? NUMERIC
//	{#signednumber = #([SIGNEDNUMBER, "SIGNEDNUMBER"], #signednumber);}
  ;
		
// parser part
statementlist
  :
  (statement)?
  (SEMI statement)*
  ;

statement
  :
  createtable
  ;
	
create_statements
  :
  createtable
  ;
	
createtable
  :
  CREATE (TEMP|TEMPORARY)? TABLE (IF_T NOT EXISTS)? tablename 
  ( LPAREN columndef (COMMA columndef)* (COMMA tableconstraint)* RPAREN
  | AS selectstmt
  )
  {#createtable = #([CREATETABLE, "CREATETABLE"], #createtable);}
  ;

columndef
  :
  columnname (type_name)? (columnconstraint)*
  {#columndef = #([COLUMNDEF, "COLUMNDEF"], #columndef);}
  ;
	
name : ID | QUOTEDID;

type_name
  :
  (name)+
  (LPAREN signednumber (COMMA signednumber)? RPAREN)?
  {#type_name = #([TYPE_NAME, "TYPE_NAME"], #type_name);}
  ;
	
columnconstraint
  :
  (CONSTRAINT name)?
  ( PRIMARY KEY (ASC|DESC)? (AUTOINCREMENT)?
  | NOT NULL_T (conflictclause)?
  | UNIQUE (conflictclause)?
  | CHECK LPAREN expr RPAREN
  | DEFAULT (signednumber | STRING | LPAREN expr RPAREN)
  | COLLATE collationname
  | foreignkeyclause)
  {#columnconstraint = #([COLUMNCONSTRAINT, "COLUMNCONSTRAINT"], #columnconstraint);}
  ;
	
tableconstraint
  :
  (CONSTRAINT name)?
  ( PRIMARY KEY LPAREN indexedcolumn (COMMA indexedcolumn)* RPAREN (conflictclause)?
  | UNIQUE LPAREN indexedcolumn (COMMA indexedcolumn)* RPAREN (conflictclause)?
  | CHECK LPAREN expr RPAREN
  | FOREIGN KEY LPAREN columnname (COMMA columnname)* RPAREN foreignkeyclause
  )
  {#tableconstraint = #([TABLECONSTRAINT, "TABLECONSTRAINT"], #tableconstraint);}
  ;
	
indexedcolumn
  : id	
  ;
	
conflictclause
  :
  ON CONFLICT
  ( ROLLBACK
  | ABORT
  | FAIL
  | IGNORE
  | REPLACE
  )
  ;
	
foreignkeyclause
  :
  REFERENCES tablename (LPAREN columnname (COMMA columnname)* RPAREN)?
  ( ON (DELETE | UPDATE)
    ( SET (NULL_T | DEFAULT)
    | CASCADE
    | RESTRICT
    | NO ACTION
    )
  | MATCH name
  )*
  ( (NOT)? DEFERRABLE (INITIALLY (DEFERRED | IMMEDIATE))? )?
  ;
	
selectstmt
  : SELECT
  ;

functionname
  : id ;

expr
  :
  subexpr ( ( binaryoperator | AND | OR) subexpr )*
//  {#expr = #([EXPR, "EXPR"],#expr);}
  ;

subexpr
  :
  (unaryoperator)?
  ( literalvalue
//  | bindparameter TODO
  | ((databasename DOT)? tablename)? columnname
  | functionname LPAREN (expr (COMMA expr)* )? RPAREN //TODO
  | CAST LPAREN expr AS type_name RPAREN
  | LPAREN expr RPAREN
  | ( (NOT)? EXISTS)? LPAREN selectstmt RPAREN
  | CASE_T (expr)? (WHEN expr THEN expr)+ (ELSE expr)? END
  | raisefunction
  )
  (suffixexpr)?
  ;

suffixexpr
  :
  ( COLLATE collationname
  | (NOT)? 
    ( (LIKE | GLOB | REGEXP | MATCH) expr (ESCAPE expr)?
    | IN ( LPAREN (selectstmt | expr (COMMA expr)* )? RPAREN | tablename)
    )
  )
  ;
	
literalvalue
  :	signednumber
  | STRING
//  | blob-literal
  | NULL_T
  | CURRENT_TIME
  | CURRENT_DATE
  | CURRENT_TIMESTAMP
  ;

raisefunction
  : RAISE LPAREN ( IGNORE | (ROLLBACK | ABORT | FAIL) COMMA STRING ) RPAREN ;

// TODO operators missing
binaryoperator
  :	
    OROP	
  | STAR | SLASH | PERCENT
  | PLUS | MINUS
  | BITWISELEFT | BITWISERIGHT | AMPERSAND | BITOR
  | LOWER | LOWEREQUAL | GREATER | GREATEREQUAL
  | EQUAL | EQUAL2 | UNEQUAL | UNEQUAL2 
  | IS (NOT)? | IN | LIKE | GLOB | MATCH | REGEXP
  ;

unaryoperator
  : MINUS | PLUS | TILDE | NOT ;
