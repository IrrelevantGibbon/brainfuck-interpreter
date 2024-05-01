package interpreter

import "core:c/libc"
import "core:fmt"


Node :: struct {
	value: u8,
	next:  ^Node,
	prev:  ^Node,
}

Loop :: Node
Data :: Node

Context :: struct {
	loop: ^Loop,
	data: ^Data,
	idx:  u32,
}

Token :: struct {
	idx:  u32,
	type: TokenType,
	tag:  u32,
}

TokenType :: enum {
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
	token:       TokenType,
	position:    int,
	description: string,
}

NoError :: Error{ErrorType.NONE, nil, 0, ""}

STACK_SIZE_MAX :: 100


parser :: proc(str: []u8) {
	tokens, err := tokenizer(str)
	defer delete(tokens)

	if err.type != ErrorType.NONE {
		printError(err)
		return
	}

	execute(&tokens)
	free_all(context.temp_allocator)
}

tokenizer :: proc(str: []u8) -> ([dynamic]Token, Error) {
	tokens := make([dynamic]Token, len(str))

	openBraces := make([dynamic]int, 0)
	defer delete(openBraces)

	pad_idx := 0

	for char, index in str {
		token := matchToken(char)
		tag_idx: u32

		#partial switch token {
		case TokenType.UNKNOWN_TOKEN:
			{}
		case TokenType.OPEN_LOOP:
			append(&openBraces, index - pad_idx)
		case TokenType.CLOSE_LOOP:
			{
				tag_idx := &tag_idx
				e, openBrace := pop_safe(&openBraces)
				tag_idx^ = u32(e)
				if !openBrace {
					return tokens,
						Error{ErrorType.NO_OPEN_LOOP, TokenType.CLOSE_LOOP, index, "No Open loop"}
				}
			}
		}
		if b32(tag_idx) {
			tokens[tag_idx].tag = u32(index - pad_idx)
			tokens[index - pad_idx] = Token{u32(index - pad_idx), token, tag_idx}
		} else {
			tokens[index - pad_idx] = Token{u32(index - pad_idx), token, 0}
		}
	}

	if len(openBraces) > 0 {
		return tokens,
			Error {
				ErrorType.NO_CLOSING_LOOP,
				TokenType.OPEN_LOOP,
				pop(&openBraces),
				"No Closing loop",
			}
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
	for ctx.idx < u32(len(tokens)) {
		instructions(tokens[ctx.idx], &ctx)
	}
}

instructions :: proc(token: Token, ctx: ^Context) {
	ctx := ctx

	ctx.idx += 1
	#partial switch token.type {
	case TokenType.INCREMENT_POINTER:
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
	case TokenType.DECREMENT_POINTER:
		{
			if ctx.data.prev == nil {
				return
			}
			ctx.data = ctx.data.prev
		}
	case TokenType.INCREMENT_VALUE:
		{
			ctx.data.value += 1
		}
	case TokenType.DECREMENT_VALUE:
		{
			ctx.data.value -= 1
		}
	case TokenType.OUTPUT:
		{
			fmt.printf("%c", ctx.data.value)
		}
	case TokenType.OPEN_LOOP:
		{
			if ctx.data.value != 0 {
				current_loop := ctx.loop
				node := new(Node)
				node^ = Node{u8(ctx.idx - 1), nil, ctx.loop}
				current_loop = node
				ctx.loop = current_loop
			} else {
				ctx.idx = token.tag + 1
			}
		}
	case TokenType.CLOSE_LOOP:
		{
			if ctx.data.value == 0 {
				if ctx.loop.prev == nil {
					free(ctx.loop)
					ctx.loop = nil
				} else {
					old_loop := ctx.loop
					ctx.loop = ctx.loop.prev
					free(old_loop)
				}
			} else {
				ctx.idx = u32(ctx.loop.value + 1)
			}
		}
	case TokenType.INPUT:
		{
			char: i32 = libc.getchar()
			ctx.data.value += u8(char)
		}
	}
}


matchToken :: proc(char: u8) -> TokenType {
	switch char {
	case '>':
		return TokenType.INCREMENT_POINTER
	case '<':
		return TokenType.DECREMENT_POINTER
	case '+':
		return TokenType.INCREMENT_VALUE
	case '-':
		return TokenType.DECREMENT_VALUE
	case '.':
		return TokenType.OUTPUT
	case ',':
		return TokenType.INPUT
	case '[':
		return TokenType.OPEN_LOOP
	case ']':
		return TokenType.CLOSE_LOOP
	case:
		return TokenType.UNKNOWN_TOKEN
	}
}

printError :: proc(error: Error) {
	fmt.printfln(
		"-- Error -- \nFounded Token : %d\nAt position : %d\nDescription : %s\n-----------",
		error.position,
		error.token,
		error.description,
	)
}
