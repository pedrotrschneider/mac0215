package yupii

import "core:slice"
import "core:unicode/utf8"

Keyword :: enum {
    If, Else, For, Defer,
    True, False, Nil,
    And, Or, Print,
    Var, Proc, Struct, Distinct,
    Return,
}

KeywordData :: struct {
    tokenType: TokenType,
    runes: []rune,
}

keywords : [Keyword]KeywordData = {
    .If = { .If, { 'i', 'f' } },
    .Else = { .Else, { 'e', 'l', 's', 'e' } },
    .For = { .For, { 'f', 'o', 'r' } },
    .Defer = { .Defer, { 'd', 'e', 'f', 'e', 'r' } },
    .True = { .True, { 't', 'r', 'u', 'e' } },
    .False = { .False, { 'f', 'a', 'l', 's', 'e' } },
    .Nil = { .Nil, { 'n', 'i', 'l' } },
    .And = { .And, { 'a', 'n', 'd' } },
    .Or = { .Or, { 'o', 'r' } },
    .Print = { .Print, { 'p', 'r', 'i', 'n', 't' } },
    .Var = { .Var, { 'v', 'a', 'r' } },
    .Proc = { .Proc, { 'p', 'r', 'o', 'c' } },
    .Struct = { .Struct, { 's', 't', 'r', 'u', 'c', 't' } },
    .Distinct = { .Distinct, { 'd', 'i', 's', 't', 'i', 'n', 'c', 't' } },
    .Return = { .Return, { 'r', 'e', 't', 'u', 'r', 'n' } },
}

Scanner :: struct {
    start, // begining of the current lexeme.
    current, // current character being looked at.
    line: int, // for error reporting.
    source: []rune,
}

Scanner_Init :: proc(this: ^Scanner, source: string) {
    this.start = 0
    this.current = 0
    this.line = 1
    this.source = utf8.string_to_runes(source)
}

Scanner_Free :: proc(this: ^Scanner) {
    delete(this.source)
}

Scanner_IsAtEnd :: proc(this: ^Scanner) -> bool {
    return this.current == len(this.source)
}

Scanner_Peek :: proc(this: ^Scanner) -> rune {
    if Scanner_IsAtEnd(this) do return 0
    return this.source[this.current]
}

Scanner_PeekNext :: proc(this: ^Scanner) -> rune {
    if Scanner_IsAtEnd(this) do return 0
    return this.source[this.current + 1]
}

Scanner_Advance :: proc(this: ^Scanner) -> rune {
    defer this.current += 1
    return this.source[this.current]
}

Scanner_AdvanceLine :: proc(this: ^Scanner) {
    this.line += 1
    Scanner_Advance(this)
}

Scanner_SkipComment :: proc(this: ^Scanner) {
    for Scanner_Peek(this) != '\n' && !Scanner_IsAtEnd(this) do Scanner_Advance(this)
}

Scanner_SkipWhitespace :: proc(this: ^Scanner) {
    for {
        switch Scanner_Peek(this) {
        case ' ', '\r', '\t': Scanner_Advance(this)
        case '\n': Scanner_AdvanceLine(this)
        case '/': if Scanner_PeekNext(this) == '/' do Scanner_SkipComment(this); else do return
        case: return
        }
    }
}

Scanner_CheckKeyword :: proc(this: ^Scanner, start: int, keyword: Keyword) -> TokenType {
    runes := keywords[keyword].runes
    tokenType := keywords[keyword].tokenType
    if len(this.source) < this.start + (len(runes)) do return .Identifier
    if slice.equal(this.source[this.start + start : this.start + len(runes)], runes[start:]) do return tokenType
    return .Identifier
}

Scanner_Match :: proc(this: ^Scanner, expected: rune) -> bool {
    if Scanner_IsAtEnd(this) do return false
    if Scanner_Peek(this) != expected do return false
    this.current += 1
    return true
}

Scanner_ConsumeStringLiteral :: proc(this: ^Scanner) -> Token {
    for Scanner_Peek(this) != '"' && !Scanner_IsAtEnd(this) {
        if Scanner_Peek(this) == '\n' do this.line += 1
        Scanner_Advance(this)
    }
    if Scanner_IsAtEnd(this) do return Token_CreateError(this, "Unterminated string literal")

    // Closing quote
    Scanner_Advance(this)
    return Token_Create(this, .StringLiteral)
}

Scanner_ConsumeRuneLiteral :: proc(this: ^Scanner) -> Token {
    for Scanner_Peek(this) != '\'' && !Scanner_IsAtEnd(this) {
        Scanner_Advance(this)
    }
    if Scanner_IsAtEnd(this) do return Token_CreateError(this, "Unterminated rune literal")

    // Closing quote
    Scanner_Advance(this)
    return Token_Create(this, .RuneLiteral)
}

Scanner_ConsumeNumericLiteral :: proc(this: ^Scanner) -> Token {
    for IsDigit(Scanner_Peek(this)) do Scanner_Advance(this)

    // Look for a fractional part
    if Scanner_Peek(this) == '.' && IsDigit(Scanner_PeekNext(this)) {
    // Consume the '.'
        Scanner_Advance(this)

        for IsDigit(Scanner_Peek(this)) do Scanner_Advance(this)
    }

    return Token_Create(this, .NumericLiteral)
}

Scanner_GetIdentifierType :: proc(this: ^Scanner) -> TokenType {
//    IdentifierRune :: proc(this: ^Scanner, depth: int) -> rune {
//        return this.source[this.start + depth - 1]
//    }
//
//    IsIdentifierSmall :: proc(this: ^Scanner, depth: int) -> bool {
//        return this.current - this.start < depth - 1
//    }
//
//    depth := 1
    switch this.source[this.start] {
    case 'a': return Scanner_CheckKeyword(this, 1, .And)
    case 'd': {
        if this.current - this.start < 1 do break
        switch this.source[this.start + 1] {
        case 'e': return Scanner_CheckKeyword(this, 2, .Defer)
        case 'i': return Scanner_CheckKeyword(this, 2, .Distinct)
        }
    }
    case 'e': return Scanner_CheckKeyword(this, 1, .Else)
    case 'f': {
        if this.current - this.start < 1 do break // Identifier is not big enough
        switch this.source[this.start + 1] {
        case 'a': return Scanner_CheckKeyword(this, 2, .False)
        case 'o': return Scanner_CheckKeyword(this, 2, .For)
        }
    }
    case 'i': return Scanner_CheckKeyword(this, 1, .If)
    case 'n': return Scanner_CheckKeyword(this, 1, .Nil)
    case 'o': return Scanner_CheckKeyword(this, 1, .Or)
    case 'p': {
        if this.current - this.start < 1 do break
        switch this.source[this.start + 1] {
        case 'r': {
            if this.current - this.start < 2 do break
            switch this.source[this.start + 2] {
            case 'i': return Scanner_CheckKeyword(this, 3, .Print)
            case 'o': return Scanner_CheckKeyword(this, 3, .Proc)
            }
        }
        }
    }
    case 'r': return Scanner_CheckKeyword(this, 1, .Return)
    case 's': return Scanner_CheckKeyword(this, 1, .Struct)
    case 't': return Scanner_CheckKeyword(this, 1, .True)
    case 'v': return Scanner_CheckKeyword(this, 1, .Var)
    }
    return .Identifier
}

Scanner_ConsumeIdentifier :: proc(this: ^Scanner) -> Token {
    for IsAlpha(Scanner_Peek(this)) || IsDigit(Scanner_Peek(this)) do Scanner_Advance(this)
    return Token_Create(this, Scanner_GetIdentifierType(this))
}

Scanner_ScanToken :: proc(this: ^Scanner) -> Token {
    Scanner_SkipWhitespace(this)
    this.start = this.current

    if Scanner_IsAtEnd(this) do return Token_Create(this, .EOF)

    switch Scanner_Advance(this) {
    case '(': return Token_Create(this, .LeftParen)
    case ')': return Token_Create(this, .RightParen)
    case '{': return Token_Create(this, .LeftBrace)
    case '}': return Token_Create(this, .RightBrace)
    case ':': return Token_Create(this, .Colon)
    case ';': return Token_Create(this, .Semicolon)
    case ',': return Token_Create(this, .Comma)
    case '.': return Token_Create(this, .Dot)
    case '-': return Token_Create(this, Scanner_Match(this, '>') ? .ArrowRight : .Minus)
    case '+': return Token_Create(this, .Plus)
    case '/': return Token_Create(this, .Slash)
    case '*': return Token_Create(this, .Star)
    case '!': return Token_Create(this, Scanner_Match(this, '=') ? .BangEqual    : .Bang)
    case '=': return Token_Create(this, Scanner_Match(this, '=') ? .EqualEqual   : .Equal)
    case '>': return Token_Create(this, Scanner_Match(this, '=') ? .GreaterEqual : .Greater)
    case '<': return Token_Create(this, Scanner_Match(this, '=') ? .LessEqual    : .Less)
    case '"': return Scanner_ConsumeStringLiteral(this)
    case '\'': return Scanner_ConsumeRuneLiteral(this)
    case '0' ..= '9': return Scanner_ConsumeNumericLiteral(this)
    case 'a' ..= 'z', 'A' ..= 'Z', '_': return Scanner_ConsumeIdentifier(this)
    }

    return Token_CreateError(this, "Unexpected character")
}