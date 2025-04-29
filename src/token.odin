package yupii

import fmt "core:fmt"
import utf8 "core:unicode/utf8"

TokenType :: enum {
    LeftParen, RightParen,
    LeftBrace, RightBrace,
    Comma, Dot, Minus, Plus,
    Colon, ColonColon, Semicolon, Slash, Star,
    Endl,

    Bang, BangEqual,
    Equal, EqualEqual,
    Greater, GreaterEqual,
    Less, LessEqual,
    ArrowRight,

    Identifier,
    IntegerLiteral,
    FloatLiteral,
    StringLiteral,
    RuneLiteral,

    If, Else, For, Defer,
    True, False, Nil,
    And, Or, Print,
    Proc, Struct, Distinct,
    Return,

    Error, EOF,
}

Token :: struct {
    type: TokenType,
    line, col: int,
    source: union {
        []rune,
        string,
    },
}

Token_Create :: proc(type: TokenType, line, endCol: int, runes: []rune) -> Token {
    return Token { type, line, endCol - len(runes) + 1, runes }
}

Token_CreateError :: proc(message: string, line, col: int) -> Token {
    return Token { .Error, line, col, message }
}

Token_GetErrorMessage :: proc(this: ^Token) -> (message: string, success: bool) {
    if this.type != .Error do return "", false
    return this.source.(string), true
}

Token_GetSource :: proc(this: ^Token) -> (runes: []rune, success: bool) {
    if this.type == .Error do return nil, false
    return this.source.([]rune)
}

Token_Display :: proc(this: ^Token) {
    fmt.printf("[%d:%d] ", this.line, this.col)
    fmt.print(this.type, ": ", sep="")

    #partial switch this.type {
    case .Error: {
        errorMessage, success := Token_GetErrorMessage(this)
        if !success do panic("Unable to get error message from token")
        fmt.print(errorMessage)
    }
    case .Endl: {
        fmt.print("\\n")
    }
    case .EOF: {
        fmt.print("EOF")
    }
    case: {
        tokenSource, success := Token_GetSource(this)
        if !success do panic("Unable to get source from token")
        tokenString := utf8.runes_to_string(tokenSource)
        defer delete(tokenString)
        fmt.print(tokenString)
    }
    }
}

TokenStream :: struct {
    tokens: [dynamic]Token,
    current: int,
}

TokenStream_Init :: proc(this: ^TokenStream) {
    this.current = 0
    this.tokens = make([dynamic]Token)
}

TokenStream_Free :: proc(this: ^TokenStream) {
    delete(this.tokens)
}

TokenStream_PushToken :: proc(this: ^TokenStream, token: Token) {
    append(&this.tokens, token)
}

TokenStream_IsAtEnd :: proc(this: ^TokenStream) -> bool {
    return this.current >= len(this.tokens)
}

TokenStream_Current :: proc(this: ^TokenStream) -> (^Token, bool) {
    if TokenStream_IsAtEnd(this) do return nil, false
    return &this.tokens[this.current], true
}

TokenStream_Advance :: proc(this: ^TokenStream) -> (^Token, bool) {
    if TokenStream_IsAtEnd(this) do return nil, false
    defer this.current += 1
    return &this.tokens[this.current], true
}

TokenStream_Peek :: proc(this: ^TokenStream, depth: int = 0) -> (^Token, bool) {
    if depth >= 0 && TokenStream_IsAtEnd(this) do return nil, false
    if depth < 0 && this.current == 0 do return nil, false
    if this.current + depth < 0 || this.current + depth >= len(this.tokens) do return nil, false
    return &this.tokens[this.current + depth], true
}