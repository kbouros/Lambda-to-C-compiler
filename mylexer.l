%{
  #include <math.h>
  #include <stdio.h>
  #include <stdlib.h>
  #include <string.h>
  #include <ctype.h>
  #include "cgen.h"
  #include "myparser.tab.h"

/* Definitions and functions required for @defmacro functionality*/ 
  #define MAX_MACROS 200
  #define MAX_ID_LEN 64
  #define MAX_REPLACEMENT_LEN 128
  
typedef struct Macro {
    char id[MAX_ID_LEN];
    char replacement[MAX_REPLACEMENT_LEN];
}Macro;

Macro macro_table[MAX_MACROS];
int macro_count = 0;

/* Lookup macro by identifier and return its position if found and -1 otherwise */
int find_macro(const char* id) {
    for (int i = 0; i < macro_count; i++) {
        if (strcmp(macro_table[i].id, id) == 0) {
            return i;
        }
    }
    return -1;
}

/* Add macro to table */
void add_macro(const char* id, const char* replacement) {
    if (macro_count >= MAX_MACROS) {
        fprintf(stderr, "Too many macros defined.\n");
        exit(1);
    }
    /* If already in table then replace it. Otherwise append it. */
    int pos = find_macro(id);
    if(pos == -1){
        pos = macro_count;
		macro_count++;
    }

    strncpy(macro_table[pos].id, id, MAX_ID_LEN);
    strncpy(macro_table[pos].replacement, replacement, MAX_REPLACEMENT_LEN);
	macro_table[pos].replacement[MAX_REPLACEMENT_LEN - 1] = '\0';
}

  int line_num = 1;
  
%}


ID      [a-zA-Z][0-9a-zA-Z_]*
DIGIT   [0-9]
INT ([0]|([1-9]{DIGIT}*))
FLOAT {INT}"."{DIGIT}+([eE]{INT})?
escape_characters \\[ntr\\\"]
common_characters ("."|","|" "|[a-z]|[A-Z]|[0-9]|"-"|"+"|"*"|"/"|":"|"_"|"$"|"%"|"!"|"#"|"@"|"&"|"~"|"^"|"("|")")
STRING \"({common_characters}|{escape_characters})*\"
MACRO [ \t]*@defmacro[ \t]+{ID}[ \t]+.*\n 

%%

^{MACRO} {
	char* line = strdup(yytext);
    if (!line) {
        exit(1);
    }

    char id[MAX_ID_LEN];
    char* ptr = line;
	
	/* Skip initial spaces and @defmacro*/
	while (isspace(*ptr)) ptr++;
    ptr += strlen("@defmacro");

    /* Get identifier */
    while (isspace(*ptr)) ptr++;
    int i = 0;
    while (*ptr && !isspace(*ptr) && i < MAX_ID_LEN - 1) {
        id[i++] = *ptr;
		ptr++;
    }
    id[i] = '\0';

    /* Skip spaces before replacement */
    while (isspace(*ptr)) ptr++;

    /* Remove newline and spaces at the end */
	int len = strlen(ptr);
    while (len > 0 && isspace(ptr[len - 1])) {
        ptr[len-1] = '\0';
		len--;
    }
	
    add_macro(id, ptr);
    free(line);
	++line_num;
	/* no need to return anything*/
}

"integer"   printf("Token KW_INT: \t%s\n", yytext); return KW_INT;
"scalar"    printf("Token KW_SCALAR: \t%s\n", yytext); return KW_SCALAR;
"str"       printf("Token KW_STR: \t%s\n", yytext); return KW_STR;      
"bool"      printf("Token KW_BOOL: \t%s\n", yytext); return KW_BOOL;         
"True"      printf("Token KW_TRUE: \t%s\n", yytext); return KW_TRUE;           
"False"     printf("Token KW_FALSE: \t%s\n", yytext); return KW_FALSE;
"const"     printf("Token KW_CONST: \t%s\n", yytext); return KW_CONST;
"if"        printf("Token KW_IF: \t%s\n", yytext); return KW_IF;
"else"      printf("Token KW_ELSE: \t%s\n", yytext); return KW_ELSE;
"endif"     printf("Token KW_ENDIF: \t%s\n", yytext); return KW_ENDIF;
"for"       printf("Token KW_FOR: \t%s\n", yytext); return KW_FOR;
"in"        printf("Token KW_IN: \t%s\n", yytext); return KW_IN;
"endfor"    printf("Token KW_ENDFOR: \t%s\n", yytext); return KW_ENDFOR;
"while"     printf("Token KW_WHILE: \t%s\n", yytext); return KW_WHILE;
"endwhile"  printf("Token KW_ENDWHILE: \t%s\n", yytext); return KW_ENDWHILE;
"break"     printf("Token KW_BREAK: \t%s\n", yytext); return KW_BREAK;
"continue"  printf("Token KW_CONTINUE: \t%s\n", yytext); return KW_CONTINUE;
"not"       printf("Token KW_NOT: \t%s\n", yytext); return KW_NOT;
"and"       printf("Token KW_AND: \t%s\n", yytext); return KW_AND;
"or"        printf("Token KW_OR: \t%s\n", yytext); return KW_OR;
"def"       printf("Token KW_DEF: \t%s\n", yytext); return KW_DEF;
"enddef"    printf("Token KW_ENDDEF: \t%s\n", yytext); return KW_ENDDEF;
"main"      printf("Token KW_MAIN: \t%s\n", yytext); return KW_MAIN;
"return"    printf("Token KW_RETURN: \t%s\n", yytext); return KW_RETURN;
"comp"      printf("Token KW_COMP: \t%s\n", yytext); return KW_COMP;
"endcomp"   printf("Token KW_ENDCOMP: \t%s\n", yytext); return KW_ENDCOMP;
"of"        printf("Token KW_OF: \t%s\n", yytext); return KW_OF;

{ID} {
	/* We need to check if the identifier is defined by a macro*/
	int pos = find_macro(yytext);
    if (pos != -1) {
        // Push a copy of the current buffer_state in the stack and then replace it using scan_string.
		// This is necessary if we want to switch back to the input stream after finishing with the replacement.
		yypush_buffer_state(YY_CURRENT_BUFFER);
        yy_scan_string(macro_table[pos].replacement);
    } else {
		yylval.str = strdup(yytext);
		printf("Token TK_IDENT: \t%s\n", yytext);
        return TK_IDENT;
    }
}

{INT}       {printf("Token TK_CONST_INT: \t%s\n", yytext); yylval.str = strdup(yytext); return TK_CONST_INT;}
{FLOAT}     {printf("Token TK_CONST_FLOAT: \t%s\n", yytext); yylval.str = strdup(yytext); return TK_CONST_FLOAT;}
{STRING}    {printf("Token TK_CONST_STR: \t%s\n", yytext); yylval.str = strdup(yytext); return TK_CONST_STR;}

"+"         printf("Token TK_PLUS_OP: \t%s\n", yytext); return TK_PLUS_OP;
"-"         printf("Token TK_MINUS_OP: \t%s\n", yytext); return TK_MINUS_OP;
"*"         printf("Token TK_MULT_OP: \t%s\n", yytext); return TK_MULT_OP;
"/"         printf("Token TK_DIV_OP: \t%s\n", yytext); return TK_DIV_OP;
"%"         printf("Token TK_MOD_OP: \t%s\n", yytext); return TK_MOD_OP;
"**"        printf("Token TK_POW_OP: \t%s\n", yytext); return TK_POW_OP;

"=="        printf("Token TK_EQUAL_OP: \t%s\n", yytext); return TK_EQUAL_OP;
"!="        printf("Token TK_NOT_EQUAL_OP: \t%s\n", yytext); return TK_NOT_EQUAL_OP;
"<"         printf("Token TK_LESS_OP: \t%s\n", yytext); return TK_LESS_OP;    
"<="        printf("Token TK_LESS_EQUAL_OP: \t%s\n", yytext); return TK_LESS_EQUAL_OP;
">"         printf("Token TK_GREATER_OP: \t%s\n", yytext); return TK_GREATER_OP;
">="        printf("Token TK_GREATER_EQUAL_OP: \t%s\n", yytext); return TK_GREATER_EQUAL_OP;

"="         printf("Token TK_ASSIGN_OP: \t%s\n", yytext); return TK_ASSIGN_OP;        
"+="        printf("Token TK_PLUS_ASSIGN_OP: \t%s\n", yytext); return TK_PLUS_ASSIGN_OP;
"-="        printf("Token TK_MINUS_ASSIGN_OP: \t%s\n", yytext); return TK_MINUS_ASSIGN_OP;
"*="        printf("Token TK_MULT_ASSIGN_OP: \t%s\n", yytext); return TK_MULT_ASSIGN_OP;
"/="        printf("Token TK_DIV_ASSIGN_OP: \t%s\n", yytext); return TK_DIV_ASSIGN_OP;
"%="        printf("Token TK_MOD_ASSIGN_OP: \t%s\n", yytext); return TK_MOD_ASSIGN_OP;
":="        printf("Token TK_ARRAY_ASSIGN_OP: \t%s\n", yytext); return TK_ARRAY_ASSIGN_OP;

";"         printf("Token TK_SEMICOLON: \t%s\n", yytext); return TK_SEMICOLON;
"("         printf("Token TK_LEFT_PARENTHESIS: \t%s\n", yytext); return TK_LEFT_PARENTHESIS;
")"         printf("Token TK_RIGHT_PARENTHESIS: \t%s\n", yytext); return TK_RIGHT_PARENTHESIS;
","         printf("Token TK_COMMA: \t%s\n", yytext); return TK_COMMA;
"["         printf("Token TK_LEFT_BRACKET: \t%s\n", yytext); return TK_LEFT_BRACKET;
"]"         printf("Token TK_RIGHT_BRACKET: \t%s\n", yytext); return TK_RIGHT_BRACKET;
":"         printf("Token TK_COLON: \t%s\n", yytext); return TK_COLON;
"."         printf("Token TK_DOT: \t%s\n", yytext); return TK_DOT;
"#"         printf("Token TK_HASH: \t%s\n", yytext); return TK_HASH;

"--"[^\n]*  /* eat line comments */
[ \r\t]+    /* eat whitespace */
\n 					 ++line_num;

<<EOF>> { 
	// Pop the stack and check if there is another buffer_state to read. If not return EOF.
	yypop_buffer_state();
	if ( !YY_CURRENT_BUFFER )
	{
		return EOF;
	}
}
.           { printf("Line %d Lexical Error: Unrecognized literal %s\n", line_num, yytext); }

%%


