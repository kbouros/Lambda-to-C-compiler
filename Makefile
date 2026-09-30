all:
	bison -d -v -r all myparser.y
	flex mylexer.l
	gcc -o mycomp myparser.tab.c lex.yy.c cgen.c -lfl
	
test1: 
	./mycomp < test.la
	gcc -o test1.out result.c
	
test2:
	./mycomp < test2.la
	gcc -o test2.out result.c

conflicts:
	bison -d -v -r all myparser.y -Wcounterexamples
