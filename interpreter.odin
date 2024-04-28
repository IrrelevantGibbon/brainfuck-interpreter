package interpreter

import "core:fmt"

Node :: struct {
	value: int,
	next:  ^Node,
	prev:  ^Node,
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
	NO_OPEN_LOOP,
	NO_CLOSING_LOOP,
	INFINITE_RECURSION,
	UNKNOWN_TOKEN,
	NONE,
}


Error :: struct {
	type:        ErrorType,
	token:       Token,
	position:    int,
	description: string,
}

NoError :: Error{ErrorType.NONE, nil, 0, ""}


parser :: proc(str: []u8) {
	tokens, err := tokenizer(str)
	defer delete(tokens)

	if err.type != ErrorType.NONE {
		print_error(err)
		return
	}

	execute(&tokens)
}

tokenizer :: proc(str: []u8) -> ([dynamic]Token, Error) {
	tokens := make([dynamic]Token, len(str))

	openBraces := make([dynamic]int, 0)
	defer delete(openBraces)

	for char, index in str {
		token := matchToken(char)
		if token == Token.UNKNOWN_TOKEN {
			return tokens,
				Error {
					ErrorType.UNKNOWN_TOKEN,
					Token.UNKNOWN_TOKEN,
					index,
					"Unknown token has been found",
				}
		}

		if token == Token.OPEN_LOOP {
			append(&openBraces, index)
		}

		if token == Token.CLOSE_LOOP {
			_, openBrace := pop_safe(&openBraces)
			if !openBrace {
				return tokens,
					Error{ErrorType.NO_OPEN_LOOP, Token.CLOSE_LOOP, index, "No Open loop"}
			}
		}

		tokens[index] = token
	}

	if len(openBraces) > 0 {
		return tokens,
			Error{ErrorType.NO_CLOSING_LOOP, Token.OPEN_LOOP, pop(&openBraces), "No Closing loop"}
	}

	shrink(&tokens)
	return tokens, NoError
}


execute :: proc(tokens: ^[dynamic]Token) {
	node := new(Node)
	node^ = Node{0, nil, nil}

	for token in tokens {
		instructions(token, &node)
	}
}

instructions :: proc(token: Token, node: ^^Node) {
	node := node

	#partial switch token {
	case Token.INCREMENT_POINTER:
		{
			newNode := new(Node)
			newNode^ = Node{0, nil, node^}
			node^ = newNode
		}
	case Token.INCREMENT_VALUE:
		{
			node^.value += 1
		}
	case Token.DECREMENT_VALUE:
		{
			node^.value -= 1
		}
	}
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
		"-- Error -- \nFounded Token : %d\nAt position : %d\nDescription : %s\n-----------",
		error.position,
		error.token,
		error.description,
	)
}
