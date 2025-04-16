package main

import "core:unicode/utf8"

TokenType :: enum {
// Single character tokens.
    LeftParen, RightParen,
    LeftBrace, RightBrace,
    Comma, Dot, Minus, Plus,
    Semicolon, Slash, Star,
    // One or two character tokens.
    Bang, BangEqual,
    Equal, EqualEqual,
    Greater, GreaterEqual,
    Less, LessEqual,
    // Literals
    Identifier, String, Number,
    // Keywords
    And, Class, Else, False,
    For, Fun, If, Nil, Or,
    Print, Return, Super, This,
    True, Var, While,

    Error, EOF,
}

Token :: struct {
    type: TokenType,
    start, length, line: int,
    source: []rune,
}

Token_Create :: proc(scanner: ^Scanner, type: TokenType) -> Token {
    return Token {
        type = type,
        start = scanner.start,
        length = scanner.current - scanner.start,
        line = scanner.line,
        source = scanner.source,
    }
}

Token_CreateError :: proc(scanner: ^Scanner, message: string) -> Token {
    return Token {
        type = .Error,
        start = 0,
        length = len(message),
        line = scanner.line,
        // TODO: This memory needs to be freed. Probably should have an allocator in the scanner to allocate all memory for the tokens
        source = utf8.string_to_runes(message),
    }
}