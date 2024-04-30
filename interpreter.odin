package interpreter

import "core:c/libc"
import "core:fmt"


Node :: struct {
	value: int,
	next:  ^Node,
	prev:  ^Node,
}

Loop :: Node
Data :: Node

Context :: struct {
	loop: ^Loop,
	data: ^Data,
	idx:  int,
}

Token :: enum {
	INCREMENT_POINTER,
	DECREMENT_POINTER,
	INCREMENT_VALUE,
	DECREMENT_VALUE,
	OUTPUT,
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

STACK_SIZE_MAX :: 100


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
				Error{ErrorType.UNKNOWN_TOKEN, Token.UNKNOWN_TOKEN, index, "Unknown token"}
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


initNode :: proc() -> ^Node {
	node := new(Node)
	node^ = Node{0, nil, nil}
	return node
}

initContext :: proc() -> Context {
	return Context{nil, initNode(), 0}
}


execute :: proc(tokens: ^[dynamic]Token) {
	ctx := initContext()

	for ctx.idx < len(tokens) {
		instructions(tokens[ctx.idx], &ctx)
	}

	free_all(context.temp_allocator)
}

instructions :: proc(token: Token, ctx: ^Context) {
	ctx := ctx

	ctx.idx += 1
	#partial switch token {
	case Token.INCREMENT_POINTER:
		{
			if ctx.data.next == nil {
				node := new(Node)
				node^ = Node{0, nil, ctx.data}
				ctx.data.next = node
				ctx.data = node
				return
			}
			ctx.data = ctx.data.next
		}
	case Token.DECREMENT_POINTER:
		{
			if ctx.data.prev == nil {
				return
			}
			ctx.data = ctx.data.prev
		}
	case Token.INCREMENT_VALUE:
		{
			ctx.data.value += 1
		}
	case Token.DECREMENT_VALUE:
		{
			ctx.data.value -= 1
		}
	case Token.OUTPUT:
		{
			fmt.printf("%c", ctx.data.value)
		}
	case Token.OPEN_LOOP:
		{
			if ctx.data.value > 0 {
				current_loop := ctx.loop
				node := new(Node)
				node^ = Node{ctx.idx, nil, ctx.loop}
				current_loop = node
				ctx.loop = current_loop
			}
		}
	case Token.CLOSE_LOOP:
		{
			if ctx.data.value == 0 {
				if ctx.loop.prev == nil {
					free(ctx.loop)
				} else {
					old_loop := ctx.loop
					ctx.loop = ctx.loop.prev
					free(old_loop)
				}
			} else {
				ctx.idx = ctx.loop.value
			}
		}
	case Token.INPUT:
		{
			char: i32 = libc.getchar()
			ctx.data.value += int(char)
		}
	}
}


matchToken :: proc(char: u8) -> Token {
	switch char {
	case '>':
		return Token.INCREMENT_POINTER
	case '<':
		return Token.DECREMENT_POINTER
	case '+':
		return Token.INCREMENT_VALUE
	case '-':
		return Token.DECREMENT_VALUE
	case '.':
		return Token.OUTPUT
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
