# Lambda-to-C Compiler

An educational source-to-source compiler developed for **ΠΛΗ 402 — Theory of Computation** at the **Technical University of Crete**, during the **spring semester of 2025**. It uses **Flex** for lexical analysis and **GNU Bison** for parsing, with C code generation implemented in the grammar's semantic actions.

The translator reads a program written in **Lambda**, the teaching language defined by the course (`.la` files) and produces `result.c`, which can then be compiled with GCC.

## Features

The lexer and grammar implement:

* Basic types: `integer`, `scalar`, `str`, and `bool`.
* Constants, variables, arrays, and array comprehensions.
* Arithmetic, comparison, and logical expressions.
* Assignments and compound assignments.
* `if`/`else`, range-based `for` loops, `while`, `break`, and `continue`.
* Functions with parameters and return values.
* Custom `comp` types with fields and methods, translated into C structures and function pointers.
* `@defmacro` definitions and identifier substitution in the lexer.
* Line comments beginning with `--`.

The parser also checks for previously declared custom types and ordinary function names. This is a course implementation with limited semantic checks, rather than a complete type-checking compiler.

## Files

|File|Purpose|
|-|-|
|`mylexer.l`|Flex lexer: tokens, comments, macros, and line tracking|
|`myparser.y`|Bison grammar and C-generation actions|
|`cgen.c`, `cgen.h`|String-formatting, error-reporting, and code-generation helpers|
|`lambdalib.h`|Runtime types and input/output functions for generated C|
|`Makefile`|Translator build, example compilation, and grammar diagnostics|
|`test.la`|Bookstore example with nested custom types, methods, and arrays|
|`test2.la`|Array creation and reversal example|
|`result.c`|Supplied C output for the bookstore example; also the translator's output path|
|`result2.c`|Supplied C output for the array example|

## Requirements

* Linux or a compatible environment such as WSL.
* GCC, GNU Make, GNU Bison, and Flex with its `libfl` library.
* The included `cgen.c`, `cgen.h`, and `lambdalib.h` support files, placed alongside the lexer, parser, and Makefile.

The code-generation helpers use `open\_memstream`, and some generated initializers use GNU C extensions. GCC with GNU C support is the intended compiler.

## Build and run

Build the translator:

```bash
make
```

Translate the array example, compile its generated C, and run it:

```bash
./mycomp < test2.la
gcc -std=gnu11 -o array-example.out result.c -lm
./array-example.out
```

The translator reads standard input and writes **`result.c` regardless of the input filename**. Each successful translation overwrites that file. It also prints token traces and generated code to the terminal.

The Makefile provides these shortcuts after building `mycomp`:

```bash
make test1
./test1.out

make test2
./test2.out
```

Both targets compile `result.c`; `make test2` does not regenerate `result2.c`. These are example build targets, not automated output assertions. The supplied targets omit `-lm`; add it when compiling generated programs that require the math library, such as programs using exponentiation.

To request Bison grammar diagnostics and conflict counterexamples:

```bash
make conflicts
```

