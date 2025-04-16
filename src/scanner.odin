package main

import "core:slice"
import "core:unicode/utf8"

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
    // TODO: This memory needs to be freed
    this.source = utf8.string_to_runes(source)
    // TODO: Keep a copy of the original string as well for faster number conversion
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

Scanner_CheckKeyword :: proc(this: ^Scanner, start: int, keyword: []rune, type: TokenType) -> TokenType {
    if slice.equal(this.source[this.current + start:this.current + len(keyword)], keyword) do return type
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
    return Token_Create(this, .String)
}

Scanner_ConsumeNumber :: proc(this: ^Scanner) -> Token {
    for IsDigit(Scanner_Peek(this)) do Scanner_Advance(this)

    // Look for a fractional part
    if Scanner_Peek(this) == '.' && IsDigit(Scanner_PeekNext(this)) {
    // Consume the '.'
        Scanner_Advance(this)

        for IsDigit(Scanner_Peek(this)) do Scanner_Advance(this)
    }

    return Token_Create(this, .Number)
}

Scanner_GetIdentifierType :: proc(this: ^Scanner) -> TokenType {
    switch this.source[this.start] {
    case 'a': return Scanner_CheckKeyword(this, 1, { 'n', 'd' }, .And)
    case 'c': return Scanner_CheckKeyword(this, 1, { 'l', 'a', 's', 's' }, .Class)
    case 'e': return Scanner_CheckKeyword(this, 1, { 'l', 's', 'e' }, .Else)
    case 'f': {
        if this.current - this.start < 1 do break
        switch this.source[this.start + 1] {
        case 'a': return Scanner_CheckKeyword(this, 2, { 'l', 's', 'e' }, .False)
        case 'o': return Scanner_CheckKeyword(this, 2, { 'r' }, .For)
        case 'u': return Scanner_CheckKeyword(this, 2, { 'n' }, .False)
        }
    }
    case 'i': return Scanner_CheckKeyword(this, 1, { 'f' }, .If)
    case 'n': return Scanner_CheckKeyword(this, 1, { 'i', 'l' }, .Nil)
    case 'o': return Scanner_CheckKeyword(this, 1, { 'r' }, .Or)
    case 'p': return Scanner_CheckKeyword(this, 1, { 'r', 'i', 'n', 't' }, .Print)
    case 'r': return Scanner_CheckKeyword(this, 1, { 'e', 't', 't', 'u', 'r', 'n' }, .Return)
    case 's': return Scanner_CheckKeyword(this, 1, { 'u', 'p', 'e', 'r' }, .Super)
    case 't': {
        if this.current - this.start < 1 do break
        switch this.source[this.start + 1] {
        case 'h': return Scanner_CheckKeyword(this, 2, { 'i', 's' }, .This)
        case 'r': return Scanner_CheckKeyword(this, 2, { 'u', 'e' }, .True)
        }
    }
    case 'v': return Scanner_CheckKeyword(this, 1, { 'v', 'a', 'r' }, .Var)
    case 'w': return Scanner_CheckKeyword(this, 1, { 'w', 'h', 'i', 'l', 'e' }, .While)
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
    case ';': return Token_Create(this, .Semicolon)
    case ',': return Token_Create(this, .Comma)
    case '.': return Token_Create(this, .Dot)
    case '-': return Token_Create(this, .Minus)
    case '+': return Token_Create(this, .Plus)
    case '/': return Token_Create(this, .Slash)
    case '*': return Token_Create(this, .Star)
    case '!': return Token_Create(this, Scanner_Match(this, '=') ? .BangEqual    : .Bang)
    case '=': return Token_Create(this, Scanner_Match(this, '=') ? .EqualEqual   : .Equal)
    case '<': return Token_Create(this, Scanner_Match(this, '=') ? .LessEqual    : .Less)
    case '>': return Token_Create(this, Scanner_Match(this, '=') ? .GreaterEqual : .Greater)
    case '"': return Scanner_ConsumeStringLiteral(this)
    case '0' ..= '9': return Scanner_ConsumeNumber(this)
    case 'a' ..= 'z', 'A' ..= 'Z', '_':
    }

    return Token_CreateError(this, "Unexpected character")
}