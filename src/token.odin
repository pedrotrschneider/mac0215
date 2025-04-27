package yupii

import utf8 "core:unicode/utf8"

TokenType :: enum {
    LeftParen, RightParen,
    LeftBrace, RightBrace,
    Comma, Dot, Minus, Plus,
    Colon, Semicolon, Slash, Star,

    Bang, BangEqual,
    Equal, EqualEqual,
    Greater, GreaterEqual,
    Less, LessEqual,
    ArrowRight,

    Identifier, TypeId,
    NumericLiteral, StringLiteral, RuneLiteral,

    If, Else, For, Defer,
    True, False, Nil,
    And, Or, Print,
    Var, Proc, Struct, Distinct,
    Return,

    Error, EOF,
}

Token :: struct {
    type: TokenType,
    start, length, line: int,
    source: union {
        []rune,
        string,
    },
}

Token_Create :: proc(scanner: ^Scanner, type: TokenType) -> Token {
    return Token { type, scanner.start, scanner.current - scanner.start, scanner.line, scanner.source }
}

Token_CreateError :: proc(scanner: ^Scanner, message: string) -> Token {
    return Token { .Error, 0, len(message), scanner.line, message }
}

Token_GetSourceString :: proc(this: ^Token) -> (source: string, shouldFree: bool) {
    _, isTokenSourceRunes := this.source.([]rune)
    if isTokenSourceRunes do source = utf8.runes_to_string(this.source.([]rune))
    else do source = this.source.(string)
    shouldFree = isTokenSourceRunes
    return
}