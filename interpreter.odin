package interpreter

import "core:fmt"


MAX_RECURSION :: 10

State :: enum {
	TOKENNIZE,
	PARSE,
}

Interpreter :: struct {
	state: State,
	error: Error,
}

Token :: enum {
	INCREMENT_POINTER,
	DECREMENT_POINTER,
	INCREMENT_VALUE,
	DECREMENT_VALUE,
	PRINT_ASCII_VALUE,
	INPUT,
	OPEN_LOOP,
	CLOSE_LOOP,
	UNKNOWN_TOKEN,
}

ErrorType :: enum {
	INT_OVERFLOW,
	NO_CLOSING_LOOP,
	INFINITE_RECURSION,
	UNKNOW_TOKEN,
	NONE,
}


Error :: struct {
	type:        ErrorType,
	token:       Token,
	position:    int,
	description: string,
}

initInterpreter :: proc() -> Interpreter {
	return
}


interprete :: proc(str: []u8) {
	tokens, err := tokenizer(str)
	if err != Error.NONE {
		print_error(err)
		return
	}
}

tokenizer :: proc(str: []u8) -> ([dynamic]Token, Error) {
	tokens: [dynamic]Token
	reserve(&tokens, len(str))
	for char, index in str {
		token := matchToken(char)
		if token == Token.UNKNOWN_TOKEN {
			return tokens, Error.UNKNOW_TOKEN
		}
		append(&tokens, matchToken(char))
	}
	shrink(&tokens)
	return tokens, Error.NONE
}

parse :: proc(tokens: []Token) {

}


matchToken :: proc(char: u8) -> Token {
	switch char {
	case '<':
		return Token.INCREMENT_POINTER
	case '>':
		return Token.DECREMENT_POINTER
	case '+':
		return Token.INCREMENT_VALUE
	case '-':
		return Token.DECREMENT_VALUE
	case '.':
		return Token.PRINT_ASCII_VALUE
	case ',':
		return Token.INPUT
	case '[':
		return Token.OPEN_LOOP
	case ']':
		return Token.CLOSE_LOOP
	case:
		return Token.UNKNOWN_TOKEN
	}
}

print_error :: proc(error: Error) {
	fmt.printfln(
		"Error : Founded Token : %d\nAt position : %d\nDescription : %s",
		error.position,
		error.token,
		error.description,
	)
}
