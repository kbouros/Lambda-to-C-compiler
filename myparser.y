%{
	#include <stdio.h>
	#include <string.h>
	#include <stdlib.h>
	#include "cgen.h"
  
	extern int yylex(void);
	extern int line_num;
	
	/* Definitions and arrays required to keep track of the functions and the complex types*/ 
	#define MAX_COMP 128
	#define MAX_COMP_TYPE_NAME 32
	#define MAX_FUNCTIONS 256
	#define MAX_FUNCTION_NAME 64
	#define MAX_COMP_FUNCTIONS 32
	#define MAX_COMP_VARS 128

	char comp_types[MAX_COMP][MAX_COMP_TYPE_NAME];
	int comp_count = 0;
	
	char functions[MAX_FUNCTIONS][MAX_FUNCTION_NAME];
	int func_count = 0;
	
	void add_comp_type(const char* comp) {
		if (comp_count >= MAX_COMP) {
			fprintf(stderr, "Too many comp types defined.\n");
			exit(1);
		}

		strncpy(comp_types[comp_count], comp, MAX_COMP_TYPE_NAME);
		comp_types[comp_count][MAX_COMP_TYPE_NAME-1] = '\0';
		comp_count++;
	}
	
	void add_function_name(const char* name) {
		if (func_count >= MAX_FUNCTIONS) {
			fprintf(stderr, "Too many functions defined.\n");
			exit(1);
		}

		strncpy(functions[func_count], name, MAX_FUNCTION_NAME);
		functions[func_count][MAX_FUNCTION_NAME-1] = '\0';
		func_count++;
	}
	
	typedef struct Comp_functions {
		char* name;
		char* declare;
		char* body;
	}Comp_functions;
	
	Comp_functions comp_func_table[MAX_COMP_FUNCTIONS];
	int comp_funcs_count = 0;
	
	// Keep track of the comp type variable inside a comp type	
	char* comp_var_table[MAX_COMP_VARS];
	int comp_var_count = 0;
	
	int inside_comp = 0;	// inside comp declaration. Methods use self->
	int dot_flag = 0;	// #id.#id Only the first one will use self->
%}

%union
{
	char* str;
}

// Terminating tokens
%token <str> TK_IDENT
%token <str> TK_CONST_INT
%token <str> TK_CONST_FLOAT
%token <str> TK_CONST_STR

// Keywords 
%token KW_INT
%token KW_SCALAR
%token KW_STR 
%token KW_BOOL 
%token KW_TRUE 
%token KW_FALSE 
%token KW_CONST 
%token KW_IF 
%token KW_ELSE 
%token KW_ENDIF 
%token KW_FOR 
%token KW_IN 
%token KW_ENDFOR 
%token KW_WHILE 
%token KW_ENDWHILE 
%token KW_BREAK 
%token KW_CONTINUE 
%token KW_DEF 
%token KW_ENDDEF 
%token KW_MAIN 
%token KW_RETURN 
%token KW_COMP
%token KW_ENDCOMP 
%token KW_OF

// Operators
%right TK_ASSIGN_OP 
%right TK_PLUS_ASSIGN_OP 
%right TK_MINUS_ASSIGN_OP 
%right TK_MULT_ASSIGN_OP 
%right TK_DIV_ASSIGN_OP 
%right TK_MOD_ASSIGN_OP 
%right TK_ARRAY_ASSIGN_OP  

%left KW_OR 
%left KW_AND 
%right KW_NOT 

%left TK_EQUAL_OP TK_NOT_EQUAL_OP 
%left TK_GREATER_OP TK_GREATER_EQUAL_OP TK_LESS_EQUAL_OP TK_LESS_OP 

%left TK_PLUS_OP TK_MINUS_OP 
%left TK_MULT_OP TK_DIV_OP TK_MOD_OP
%right TK_POW_OP

// Delimiters
%token TK_SEMICOLON 
%left TK_LEFT_PARENTHESIS 
%left TK_RIGHT_PARENTHESIS 
%token TK_COMMA 
%left TK_LEFT_BRACKET 
%left TK_RIGHT_BRACKET 
%token TK_COLON 
%left TK_DOT 
%token TK_HASH

// Non-terminating tokens
// Program format
%type <str> input
%type <str> program
%type <str> declarations
%type <str> main

// Declarations
%type <str> comp_declarations
%type <str> constant_declarations
%type <str> variable_declarations
%type <str> function_definitions

// Data types and helper tokens for declarations
%type <str> data_types
%type <str> basic_types
%type <str> comp_type
%type <str> comp_def
%type <str> comp_vars
%type <str> comp_vars_declarations
%type <str> comp_function_definitions
%type <str> comp_void_funcs
%type <str> comp_void_rest
%type <str> comp_return_funcs
%type <str> vars
%type <str> comp_variables
%type <str> basic_variables
%type <str> void_function
%type <str> void_function_rest
%type <str> return_function
%type <str> params

// Expressions
%type <str> expr
%type <str> identifier_expr
%type <str> arithmetic_expr
%type <str> relational_expr
%type <str> comp_expr
%type <str> subroutine

// Statements
%type <str> statements
%type <str> series_statements
%type <str> assign_stmt
%type <str> if_stmt
%type <str> for_stmt
%type <str> array_stmt
%type <str> simple_array
%type <str> other_array
%type <str> while_stmt
%type <str> function_stmt
%type <str> function_arg
%type <str> func_body


%start input

%%

// ******************** Program format ********************
input:  
	program
{ 
	$$ = template("%s",$1);
	if (yyerror_count == 0) {
		FILE *fp = fopen("result.c","w");
		printf("\n\t C CODE : \n\n");
		printf("\n%s\n", $1);
		printf("\n\t C CODE END\n");
		fputs("#include <stdio.h>\n",fp);
		fputs("#include <math.h>\n",fp);
		fputs(c_prologue,fp);
		fprintf(fp,"%s\n", $1);
		
		fclose(fp); 
	}	  
}
;

program:
 	declarations main { $$ = template("%s\n%s\n",$1,$2); }
;

declarations:
	comp_declarations constant_declarations variable_declarations KW_DEF function_definitions { $$ = template("%s\n%s%s\n%s\n", $1, $2, $3, $5); }
;

/* Note that we have removed KW_DEF as starting condition of main and the functions to avoid shift/reduce conflict
   between them (when getting KW_DEF we wouldnt know if the next one is a function or main). 
   Instead KW_DEF is added between variable_declarations and function_definitions and is a requirement after the end of 
   each function (this ensures the required KW_DEF of the next function or main if it was the last one)*/
main: 
	KW_MAIN TK_LEFT_PARENTHESIS TK_RIGHT_PARENTHESIS TK_COLON func_body KW_ENDDEF TK_SEMICOLON {$$ = template("int main(){\n%s\n}", $5);};


// ******************** Data types ******************************
data_types:
	basic_types { $$ = $1; }
|	comp_type
;

comp_type:
	TK_IDENT{
    // Check if there is a comp type with TK_IDENT name 
    int found = 0;

	for (int i = 0; i < comp_count; i++) {
		if (strcmp(comp_types[i], $1) == 0) {
		  found = 1;
		  $$ = $1;
		  break;
		}
	}
	if (found == 0) {
		yyerror("There is no complex type %s declared.", $1);
		exit(1);
	}
}

basic_types:
	KW_INT {$$ = template("%s", "int");}
|	KW_SCALAR {$$ = template("%s","double");}
|	KW_STR {$$ = template("%s", "StringType");} // In lambdalib. Needed instead of char* for multiline declarations
|	KW_BOOL {$$ = template("%s", "int");}
;	

// ********** Declarations (each one can also be empty) **********
// Complex declarations
comp_declarations:
	%empty { $$ = "" ;}
|	comp_declarations comp_def { $$ = template("%s%s", $1, $2); }
;

comp_def:
	KW_COMP {inside_comp = 1;} TK_IDENT TK_COLON comp_vars_declarations comp_function_definitions KW_ENDCOMP TK_SEMICOLON{
		// First add the name of the comp type to our table
		add_comp_type($3);
		// Array of strings. Each string is one function definition after the struct
		char* funcs[comp_funcs_count];
		size_t length = 0;  // length of new 1-d char array for function definitions
		size_t length2 = 0; // length of new string for ctor { function names}
		
		// Array of strings. Each string is one variable ctor assignment (i.e. .book = ctor_Book)
		size_t length3 = 0; // length of new string for ctor { comp var names}
		
		for (int i = 0; i < comp_funcs_count; i++) {
			funcs[i] = strdup(template("\n%s{\n%s}\n", comp_func_table[i].declare, comp_func_table[i].body)); 
			length += strlen(funcs[i]);
			length2 += strlen(comp_func_table[i].name);
		}
		
		for (int i = 0; i < comp_var_count; i++) { 
			length3 += strlen(comp_var_table[i]);
		}
		
		// Create final strings
		char* result = malloc(length + 1);
		char* result_names = malloc(2*length2 + 6*comp_funcs_count + length3 + comp_var_count); // include spaces, commas and assignments
		if (!result || !result_names){
			yyerror("Memory allocation error");
			exit(1);
		}
		result[0] = '\0'; 
		result_names[0] = '\0'; 
		for (int i = 0; i < comp_funcs_count; i++) {
			strcat(result, funcs[i]);
			if( i < comp_funcs_count-1){
				strcat(result_names, template(".%s = %s, ",comp_func_table[i].name, comp_func_table[i].name));
			}
			else{
				strcat(result_names, template(".%s = %s",comp_func_table[i].name, comp_func_table[i].name));
			}
		}
		for (int i = 0; i < comp_var_count; i++) { 
			if ( i == 0 && comp_funcs_count == 0){
				strcat(result_names, template("%s", comp_var_table[i]));
			}
			else{
				strcat(result_names, template(",%s", comp_var_table[i]));
			}
		}
		
		

		$$ = template("\n#define SELF struct %s *self\ntypedef struct %s {\n%s%s} %s;\n%s\nconst %s ctor_%s = { %s };\n#undef SELF\n", $3, $3, $5, $6, $3, result, $3, $3, result_names); 
		
		// free resources
		for (int i = 0; i < comp_funcs_count; i++) {
			free(funcs[i]);
			free(comp_func_table[i].name);
			free(comp_func_table[i].declare);
			free(comp_func_table[i].body);
		}
		for (int i = 0; i < comp_funcs_count; i++) {
			free(comp_var_table[i]);
		}
		free(result);
		free(result_names);
		
		// Reset inside_comp and number of functions/vars
		inside_comp = 0;
		comp_funcs_count = 0;
		comp_var_count = 0;
		
} 

// One or more identifiers seperated by comma (variables for declaration in a single line)
comp_vars:
	TK_HASH TK_IDENT {$$ = template("%s", $2); }
|	comp_vars TK_COMMA TK_HASH TK_IDENT { $$ = template("%s, %s", $1,$4);}
;
	
comp_vars_declarations:
	comp_vars_declarations comp_vars TK_COLON basic_types TK_SEMICOLON {$$ = template("%s%s %s;\n", $1, $4, $2); }
|	comp_vars TK_COLON basic_types TK_SEMICOLON {$$ = template("%s %s;\n", $3, $1); }
|	comp_vars_declarations TK_HASH TK_IDENT TK_LEFT_BRACKET TK_CONST_INT TK_RIGHT_BRACKET TK_COLON basic_types TK_SEMICOLON { $$ = template("%s%s %s[%s];\n", $1, $8, $3, $5); }
|	TK_HASH TK_IDENT TK_LEFT_BRACKET TK_CONST_INT TK_RIGHT_BRACKET TK_COLON basic_types TK_SEMICOLON { $$ = template("%s %s[%s];\n", $7, $2, $4); }
|	comp_vars_declarations comp_vars TK_COLON comp_type TK_SEMICOLON {
		comp_var_table[comp_var_count] = strdup(template(" .%s = ctor_%s", $2, $4));
		$$ = template("%s%s %s;\n", $1, $4, $2); 
		comp_var_count++;
	}
|	comp_vars TK_COLON comp_type TK_SEMICOLON {
		comp_var_table[comp_var_count] = strdup(template(" .%s = ctor_%s", $1, $3));
		$$ = template("%s %s;\n", $3, $1); 
		comp_var_count++;
	}
|	comp_vars_declarations TK_HASH TK_IDENT TK_LEFT_BRACKET TK_CONST_INT TK_RIGHT_BRACKET TK_COLON comp_type TK_SEMICOLON {
		comp_var_table[comp_var_count] = strdup(template(" .%s = {[0 ... %s - 1] = ctor_%s}", $3, $5, $8));
		$$ = template("%s%s %s[%s];\n", $1, $8, $3, $5); 
		comp_var_count++;
	}
|	TK_HASH TK_IDENT TK_LEFT_BRACKET TK_CONST_INT TK_RIGHT_BRACKET TK_COLON comp_type TK_SEMICOLON {
		comp_var_table[comp_var_count] = strdup(template(" .%s = {[0 ... %s - 1] = ctor_%s}", $2, $4, $7));
		$$ = template("%s %s[%s];\n", $7, $2, $4);
		comp_var_count++;
	}
;

comp_function_definitions:
	%empty { $$ = "" ;}
|	comp_function_definitions comp_void_funcs {$$ = template("%s%s", $1,$2);}
| 	comp_function_definitions comp_return_funcs {$$ = template("%s%s", $1,$2);}
;

comp_void_funcs:
	KW_DEF TK_IDENT TK_LEFT_PARENTHESIS params TK_RIGHT_PARENTHESIS TK_COLON comp_void_rest  {
		comp_func_table[comp_funcs_count].name = strdup($2);
		comp_func_table[comp_funcs_count].body = strdup($7);
		if (strlen($4) != 0){
			comp_func_table[comp_funcs_count].declare = strdup(template("void %s(SELF, %s)", $2, $4));
			$$ = template("void (*%s)(SELF, %s);\n", $2, $4);
		}
		else{
			comp_func_table[comp_funcs_count].declare = strdup(template("void %s(SELF)", $2));
			$$ = template("void (*%s)(SELF);\n", $2);
		}
		comp_funcs_count++;
};

comp_void_rest:
	func_body KW_ENDDEF TK_SEMICOLON {$$ = template("%s\n", $1);}
|	func_body KW_RETURN TK_SEMICOLON KW_ENDDEF TK_SEMICOLON {$$ = template("%s\n return;\n", $1);}
;

comp_return_funcs:
	KW_DEF TK_IDENT TK_LEFT_PARENTHESIS params TK_RIGHT_PARENTHESIS TK_MINUS_OP TK_GREATER_OP data_types TK_COLON func_body KW_RETURN expr TK_SEMICOLON KW_ENDDEF TK_SEMICOLON {
		comp_func_table[comp_funcs_count].name = strdup($2);
		comp_func_table[comp_funcs_count].body = strdup(template("%s\n return %s;\n",$10, $12 ));
		if (strlen($4) != 0){
			comp_func_table[comp_funcs_count].declare = strdup(template("%s %s(SELF, %s)", $8, $2, $4));
			$$ = template("%s (*%s)(SELF, %s);\n", $8, $2, $4);
		}
		else{
			comp_func_table[comp_funcs_count].declare = strdup(template("%s %s(SELF)", $8, $2));
			$$ = template("%s (*%s)(SELF);\n", $8, $2);
		}
		comp_funcs_count++;
};
	
	
	

// Constant declarations
constant_declarations:
	%empty { $$ = "" ;}
|	constant_declarations KW_CONST TK_IDENT TK_ASSIGN_OP expr TK_COLON basic_types TK_SEMICOLON {$$ = template("%sconst %s %s = %s;\n", $1, $7, $3, $5);};
;

// Variable declarations
// One or more identifiers seperated by comma (variables for declaration in a single line)
vars:
	TK_IDENT { $$ = $1; }
| 	vars TK_COMMA TK_IDENT {$$ = template("%s, %s", $1,$3);}
;

comp_variables:
	vars TK_COLON comp_type TK_SEMICOLON {$$ = template("%s %s = ctor_%s; \n", $3, $1, $3); }
;

basic_variables:
	vars TK_COLON basic_types TK_SEMICOLON {$$ = template("%s %s;\n", $3, $1); }
|	TK_IDENT TK_LEFT_BRACKET TK_CONST_INT TK_RIGHT_BRACKET TK_COLON data_types TK_SEMICOLON {$$ = template("%s %s[%s];\n", $6, $1, $3); }
;

variable_declarations:
	%empty { $$ = "" ;}
|	variable_declarations basic_variables {$$ = template("%s%s", $1, $2); }
| 	variable_declarations comp_variables {$$ = template("%s%s", $1, $2); }
;

// Function declarations
// void function that either has a return or does not
void_function:
	TK_IDENT TK_LEFT_PARENTHESIS params TK_RIGHT_PARENTHESIS TK_COLON {add_function_name(template("%s", $1)); } void_function_rest  {$$ = template("void %s(%s) {\n%s\n}\n", $1, $3, $7);} 
;

void_function_rest:
	func_body KW_ENDDEF TK_SEMICOLON KW_DEF {$$ = template("%s\n", $1);}
|	func_body KW_RETURN TK_SEMICOLON KW_ENDDEF TK_SEMICOLON KW_DEF {$$ = template("%s\n return;\n", $1);}
;


// function that has a return value
return_function:
	TK_IDENT TK_LEFT_PARENTHESIS params TK_RIGHT_PARENTHESIS TK_MINUS_OP TK_GREATER_OP data_types TK_COLON {add_function_name(template("%s", $1)); } func_body KW_RETURN expr TK_SEMICOLON KW_ENDDEF TK_SEMICOLON KW_DEF {$$ = template("%s %s(%s) {\n%s\n return %s;\n}\n", $7, $1, $3, $10, $12);}
;


function_definitions:
	%empty { $$ = "" ;}
|	function_definitions void_function {$$ = template("%s\n%s", $1,$2);}
| 	function_definitions return_function {$$ = template("%s\n%s", $1,$2);}
;

params: 
	%empty { $$ = "" ;}
|	TK_IDENT TK_COLON data_types {$$ = template("%s %s", $3, $1);}
| 	TK_IDENT TK_LEFT_BRACKET TK_RIGHT_BRACKET TK_COLON data_types {$$ = template("%s* %s", $5, $1);}
| 	params TK_COMMA TK_IDENT TK_COLON data_types {$$ = template("%s, %s %s", $1, $5, $3);}
|	params TK_COMMA TK_IDENT TK_LEFT_BRACKET TK_RIGHT_BRACKET TK_COLON data_types {$$ = template("%s,%s* %s", $1, $7, $3);}
;

// ******************** Expressions ********************
expr:
	identifier_expr { $$ = $1; }
|	TK_CONST_STR {$$ = $1;}
|	TK_CONST_INT {$$ = $1;}
| 	TK_CONST_FLOAT {$$ = $1;}
| 	arithmetic_expr { $$ = $1; }
| 	relational_expr { $$ = $1; }
| 	TK_LEFT_PARENTHESIS expr TK_RIGHT_PARENTHESIS {$$ = template("(%s)", $2);}
| 	function_stmt { $$ = $1; }
;

subroutine:
	 %empty { dot_flag = 1; }
 ;

identifier_expr:
	TK_IDENT { $$ = $1; }
| 	TK_HASH TK_IDENT { 
		if (inside_comp == 1 && dot_flag != 1 ) {$$ = template("self->%s", $2);}
		else {$$ = template("%s", $2);} }
| 	TK_HASH TK_IDENT TK_LEFT_BRACKET expr TK_RIGHT_BRACKET { 
		if (inside_comp == 1 && dot_flag != 1 ) {$$ = template("self->%s[%s]", $2, $4);}
		else {$$ = template("%s[%s]", $2, $4);} }
| 	TK_IDENT TK_LEFT_BRACKET expr TK_RIGHT_BRACKET { $$ = template("%s[%s]", $1, $3); }
| 	comp_expr { $$ = $1; };

comp_expr:
	identifier_expr TK_DOT subroutine identifier_expr { $$ = template("%s.%s", $1, $4); dot_flag = 0; }
|	identifier_expr TK_DOT subroutine TK_IDENT TK_LEFT_PARENTHESIS function_arg TK_RIGHT_PARENTHESIS { 
	if (strlen($6) != 0){
			$$ = template("%s.%s(&%s, %s)", $1, $4, $1, $6);
		}
		else{
			$$ = template("%s.%s(&%s)", $1, $4, $1);
	};
	dot_flag = 0;
};

arithmetic_expr:	
 	expr TK_POW_OP expr {$$ = template("pow(%s, %s)", $1, $3);}
| 	expr TK_MULT_OP expr {$$ = template("%s * %s",$1, $3);}
| 	expr TK_DIV_OP expr {$$ = template("%s / %s", $1, $3);}
| 	expr TK_MOD_OP expr {$$ = template("%s %% %s", $1, $3);}
| 	expr TK_PLUS_OP expr {$$ = template("%s + %s", $1, $3);}
| 	expr TK_MINUS_OP expr {$$ = template("%s - %s", $1, $3);}
| 	TK_PLUS_OP expr {$$ = template("+%s", $2);}
| 	TK_MINUS_OP expr {$$ = template("-%s", $2);};


relational_expr:
	expr TK_LESS_OP expr {$$ = template("%s < %s",$1, $3);}
| 	expr TK_LESS_EQUAL_OP expr {$$ = template("%s <= %s", $1, $3);}
| 	expr TK_GREATER_OP expr {$$ = template("%s > %s", $1, $3);}
| 	expr TK_GREATER_EQUAL_OP expr {$$ = template("%s >= %s", $1, $3);}
| 	expr TK_EQUAL_OP expr {$$ = template("%s == %s", $1, $3);}
| 	expr TK_NOT_EQUAL_OP expr {$$ = template("%s != %s", $1, $3);}
| 	KW_NOT expr {$$ = template("! %s", $2);}
| 	expr KW_AND expr {$$ = template("%s && %s", $1, $3);}
| 	expr KW_OR expr {$$ = template("%s || %s", $1, $3);}
|	KW_TRUE {$$ = template("%s", "1");}
| 	KW_FALSE {$$ = template("%s", "0");}
;

 
// ******************** Statements ********************
statements:
	assign_stmt { $$ = template("%s", $1); }
|	if_stmt { $$ = template("%s", $1); }
|	for_stmt { $$ = template("%s", $1); }
|   array_stmt { $$ = template("%s", $1); }
|   while_stmt { $$ = template("%s", $1); }
| 	KW_BREAK TK_SEMICOLON {$$ = template("break;");}
| 	KW_CONTINUE TK_SEMICOLON {$$ = template("continue;");}
| 	function_stmt TK_SEMICOLON { $$ = template("%s;", $1); }
| 	comp_expr TK_SEMICOLON { $$ = template("%s;", $1); }
;


series_statements:
	%empty { $$ = ""; }
| 	statements series_statements { $$ = template("%s\n%s", $1, $2); }
;

// Assign statements
assign_stmt:
	identifier_expr TK_ASSIGN_OP expr TK_SEMICOLON {$$ = template("%s = %s;", $1, $3);}
| 	identifier_expr TK_PLUS_ASSIGN_OP expr TK_SEMICOLON {$$ = template("%s += %s;", $1, $3);}
| 	identifier_expr TK_MINUS_ASSIGN_OP expr TK_SEMICOLON {$$ = template("%s -= %s;" , $1, $3);}
| 	identifier_expr TK_MULT_ASSIGN_OP expr TK_SEMICOLON {$$ = template("%s *= %s;", $1, $3);}
| 	identifier_expr TK_DIV_ASSIGN_OP expr TK_SEMICOLON {$$ = template("%s /= %s;", $1, $3);}
| 	identifier_expr TK_MOD_ASSIGN_OP expr TK_SEMICOLON {$$ = template("%s %= %s;", $1, $3);};

//if else statements
if_stmt:
	KW_IF TK_LEFT_PARENTHESIS expr TK_RIGHT_PARENTHESIS TK_COLON series_statements KW_ENDIF TK_SEMICOLON {$$ = template("if (%s) {\n%s\n}", $3, $6);}
| 	KW_IF TK_LEFT_PARENTHESIS expr TK_RIGHT_PARENTHESIS TK_COLON series_statements KW_ELSE TK_COLON series_statements KW_ENDIF TK_SEMICOLON {$$ = template("if (%s) {\n%s\n} else {\n%s\n}", $3, $6, $9);};


//for statements
for_stmt:
	KW_FOR TK_IDENT KW_IN TK_LEFT_BRACKET expr TK_COLON expr TK_RIGHT_BRACKET TK_COLON series_statements KW_ENDFOR TK_SEMICOLON  {$$ = template("for (int %s = %s; %s < %s; %s++) {\n%s\n}", $2, $5, $2, $7, $2, $10);}
| 	KW_FOR TK_IDENT KW_IN TK_LEFT_BRACKET expr TK_COLON expr TK_COLON expr TK_RIGHT_BRACKET TK_COLON series_statements KW_ENDFOR TK_SEMICOLON {$$ = template("for (int %s = %s; %s < %s; %s = %s + %s) {\n%s\n}", $2, $5, $2, $7, $2, $2, $9, $12);};


//array statements
array_stmt:
	simple_array { $$ = $1; }
|	other_array { $$ = $1; };


simple_array:
	TK_IDENT TK_ARRAY_ASSIGN_OP TK_LEFT_BRACKET expr KW_FOR TK_IDENT TK_COLON TK_CONST_INT TK_RIGHT_BRACKET TK_COLON data_types TK_SEMICOLON{$$ = template("%s* %s = (%s*)malloc(%s*sizeof(%s));\nfor(int %s = 0; %s < %s; ++%s) {\n %s[%s] = %s;\n}", $11, $1, $11, $8, $11, $6, $6, $8, $6, $1, $6, $4);};


other_array:
	TK_IDENT TK_ARRAY_ASSIGN_OP TK_LEFT_BRACKET expr KW_FOR TK_IDENT TK_COLON data_types KW_IN TK_IDENT KW_OF TK_CONST_INT TK_RIGHT_BRACKET TK_COLON data_types TK_SEMICOLON {  
    char* source = $4; // expr
	char* result;	   // final string
    const char* old_str = $6; // substring to be replaced in expression
    char* new_str = template("%s[%s_i]", $10, $10); // array[array_i] (new string to replace elm)
	
	size_t old_len = strlen(old_str);
    size_t new_len = strlen(new_str);

    // Count matches using a temp pointer
    int count = 0;
    char *temp = source;
    while ((temp = strstr(temp, old_str))) {
        count++;
        temp += old_len;
    }

    // If no matches then we keep the original
    if (count == 0){
		result = source;
	} 
	else{
		// Allocate new buffer since the size will be different
		result = malloc(strlen(source) + count * (new_len - old_len) + 1);
		if (!result){
			yyerror("Memory allocation error");
			exit(1);
		}

		char *ptr = result;
		char *curr = source;

		while (*curr) {
			// Found a match in current position
			if (strstr(curr, old_str) == curr) {
				strcpy(ptr, new_str);
				ptr += new_len;
				curr += old_len;
			} else {
				// Check next position
				*ptr = *curr;
				ptr++;
				curr++;
			}
		}
		*ptr = '\0';
	}
	
	$$ = template("%s* %s = (%s*)malloc(%s*sizeof(%s));\nfor(int %s_i = 0; %s_i < %s; ++%s_i) {\n%s[%s_i] = %s;\n}", $15, $1, $15, $12, $15, $10, $10, $12, $10, $1, $10, result);
	
	if ( count != 0 ){
		free(result);
	}
}
;


//while statements
while_stmt:
	KW_WHILE TK_LEFT_PARENTHESIS expr TK_RIGHT_PARENTHESIS TK_COLON series_statements KW_ENDWHILE TK_SEMICOLON{$$ = template("while (%s) {\n%s\n}", $3, $6);}
;
  
 
//function statements
function_stmt:
	TK_IDENT TK_LEFT_PARENTHESIS function_arg TK_RIGHT_PARENTHESIS {
    // Check if there is a function with TK_IDENT name 
    int found = 0;

	for (int i = 0; i < func_count; i++) {
		if (strcmp(functions[i], $1) == 0) {
		  found = 1;
		  $$ = template("%s(%s)", $1, $3);
		  break;
		}
	}
	if (found == 0) {
		yyerror("There is no function %s declared.", $1);
		exit(1);
	}
};
  

function_arg:
	%empty { $$ = "" ;}
|	expr { $$ = template("%s", $1);}
| 	function_arg TK_COMMA expr { $$ = template("%s, %s", $1, $3); }


func_body: 
	constant_declarations variable_declarations series_statements { $$ = template("%s%s%s", $1, $2, $3); }
;



%%
int main () {
	// Add lambdalib function to the table
	add_function_name("readStr");
	add_function_name("readInteger");
	add_function_name("readScalar");
	add_function_name("writeStr");
	add_function_name("writeInteger");
	add_function_name("writeScalar");
	add_function_name("write");
	
	if ( yyparse() != 0 )
		printf("Rejected!\n");
}

