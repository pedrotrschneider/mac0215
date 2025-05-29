package yupii

import "core:mem"
import "core:slice"
import vmem "core:mem/virtual"
import utf8 "core:unicode/utf8"

Lexer :: struct {
    start, // start of the current lexeme
    current, // current character being read
    line, // current line for error reporting
    col: int, // current column for error reporting
    source: []rune,

    arena: vmem.Arena,
    allocator: mem.Allocator,
}

Lexer_Init :: proc(this: ^Lexer, source: string) {
    arenaOk: bool
    this.allocator, arenaOk = InitGrowingArenaAllocator(&this.arena)
    if !arenaOk do panic("Unable to create Lexer's arena")

    this.start = 0
    this.current = 0
    this.line = 1
    this.col = 0
    this.source = utf8.string_to_runes(source, this.allocator)
}

Lexer_Free :: proc(this: ^Lexer) {
    vmem.arena_destroy(&this.arena)
}

Lexer_PopulateParser :: proc(this: ^Lexer, parser: ^Parser, isInterpreted: bool = false) {
    eofToken: Token
    for {
        token := Lexer_NextToken(this)
        if token.type == .EOF {
            eofToken = token
            break
        }
        Parser_PushToken(parser, token)
    }

    if isInterpreted {
        Parser_PushToken(parser, Token { type = .Endl, source = utf8.string_to_runes("\n"), line = eofToken.line, col = 1 })
        Parser_PushToken(parser, Token { type = .Identifier, source = utf8.string_to_runes("main"), line = eofToken.line + 1, col = 1 })
        Parser_PushToken(parser, Token { type = .LeftParen , source = utf8.string_to_runes("("), line = eofToken.line + 1, col = 5 })
        Parser_PushToken(parser, Token { type = .RightParen , source = utf8.string_to_runes(")"), line = eofToken.line + 1, col = 6 })
        Parser_PushToken(parser, Token { type = .Endl, source = utf8.string_to_runes("\n"), line = eofToken.line + 1, col = 7 })
    }
    eofToken.line += 2
    Parser_PushToken(parser, eofToken)
}

@(private="file")
Lexer_Token :: proc(this: ^Lexer, type: TokenType) -> Token {
    return Token_Create(type, this.line, this.col, this.source[this.start:this.current])
}

@(private="file")
Lexer_ErrorToken :: proc(this: ^Lexer, message: string) -> Token {
    return Token_CreateError(message, this.line, this.col)
}

@(private="file")
Lexer_IsAtEnd :: proc(this: ^Lexer) -> bool {
    return this.current == len(this.source)
}

// Check current rune but don't consume
@(private="file")
Lexer_Peek :: proc(this: ^Lexer) -> rune {
    if Lexer_IsAtEnd(this) do return 0
    return this.source[this.current]
}

// Check next rune but don't consume
@(private="file")
Lexer_PeekNext :: proc(this: ^Lexer) -> rune {
    if Lexer_IsAtEnd(this) do return 0
    return this.source[this.current + 1]
}

// Get the current rune and advance
@(private="file")
Lexer_Advance :: proc(this: ^Lexer) -> rune {
    defer this.current += 1
    defer this.col += 1
    return this.source[this.current]
}

@(private="file")
Lexer_AdvanceLine :: proc(this: ^Lexer) {
    this.line += 1
    this.col = 0
}

@(private="file")
Lexer_SkipWhitespace :: proc(this: ^Lexer) {
    SkipComment :: proc(this: ^Lexer) {
        for Lexer_Peek(this) != '\n' && !Lexer_IsAtEnd(this) do Lexer_Advance(this)
        Lexer_Advance(this) // skip the final new line
    }

    for {
        switch Lexer_Peek(this) {
        case ' ', '\r', '\t': Lexer_Advance(this)
        case '/': {
            if Lexer_PeekNext(this) == '/' do SkipComment(this)
            else do return
        }
        case: return
        }
    }
}

// CheckKeyword
@(private="file")
Lexer_GetKeywordTokenType :: proc(this: ^Lexer, start: int, keyword: Keyword) -> TokenType {
    runes := keywords[keyword].runes
    tokenType := keywords[keyword].tokenType
    if len(this.source) < this.start + (len(runes)) do return .Identifier
    if slice.equal(this.source[this.start + start : this.start + len(runes)], runes[start:]) do return tokenType
    return .Identifier
}

// Check if the current rune is some expected rune.
// Advance only if the rune matches
@(private="file")
Lexer_Match :: proc(this: ^Lexer, expected: rune) -> bool {
    if Lexer_IsAtEnd(this) do return false
    if Lexer_Peek(this) != expected do return false
    Lexer_Advance(this)
    return true
}

@(private="file")
Lexer_ConsumeStringLiteral :: proc(this: ^Lexer) -> Token {
// Advance until the end of the string literal
    for Lexer_Peek(this) != '"' && !Lexer_IsAtEnd(this) {
        if Lexer_Peek(this) == '\n' do Lexer_AdvanceLine(this)
        else do Lexer_Advance(this)
    }
    // Validate for the closing quote
    if Lexer_IsAtEnd(this) || !Lexer_Match(this, '"') do return Lexer_ErrorToken(this, "Unterminated string literal")
    return Lexer_Token(this, .StringLiteral)
}

@(private="file")
Lexer_ConsumeRuneLiteral :: proc(this: ^Lexer) -> Token {
// Advance until the end of the rune literal
    for Lexer_Peek(this) != '\'' && !Lexer_IsAtEnd(this) do Lexer_Advance(this)
    // Validate closing quote
    if Lexer_IsAtEnd(this) || !Lexer_Match(this, '\'') do return Lexer_ErrorToken(this, "Unterminated rune literal")
    return Lexer_Token(this, .RuneLiteral)
}

@(private="file")
Lexer_ConsumeNumericLiteral :: proc(this: ^Lexer) -> Token {
// Advance until the end of the numeric literal
    for IsDigit(Lexer_Peek(this)) do Lexer_Advance(this)

    // Look for a fractional part
    if Lexer_Match(this, '.') && IsDigit(Lexer_Peek(this)) {
    // Consume the fractional part
        for IsDigit(Lexer_Peek(this)) do Lexer_Advance(this)
        return Lexer_Token(this, .FloatLiteral)
    }
    return Lexer_Token(this, .IntegerLiteral)
}

@(private="file")
Lexer_GetIdentifierType :: proc(this: ^Lexer) -> TokenType {
    switch this.source[this.start] {
    case 'a': return Lexer_GetKeywordTokenType(this, 1, .And)
    case 'd': {
        if this.current - this.start < 1 do break // Identifier is not big enough to fit any keyword
        switch this.source[this.start + 1] {
        case 'e': return Lexer_GetKeywordTokenType(this, 2, .Defer)
        case 'i': return Lexer_GetKeywordTokenType(this, 2, .Distinct)
        }
    }
    case 'e': return Lexer_GetKeywordTokenType(this, 1, .Else)
    case 'f': {
        if this.current - this.start < 1 do break
        switch this.source[this.start + 1] {
        case 'a': return Lexer_GetKeywordTokenType(this, 2, .False)
        case 'o': return Lexer_GetKeywordTokenType(this, 2, .For)
        }
    }
    case 'i': return Lexer_GetKeywordTokenType(this, 1, .If)
    case 'n': return Lexer_GetKeywordTokenType(this, 1, .Nil)
    case 'o': return Lexer_GetKeywordTokenType(this, 1, .Or)
    case 'p': {
        if this.current - this.start < 1 do break
        switch this.source[this.start + 1] {
        case 'r': {
            if this.current - this.start < 2 do break
            switch this.source[this.start + 2] {
            //            case 'i': return Lexer_GetKeywordTokenType(this, 3, .Print)
            case 'o': return Lexer_GetKeywordTokenType(this, 3, .Proc)
            }
        }
        }
    }
    case 'r': return Lexer_GetKeywordTokenType(this, 1, .Return)
    case 's': return Lexer_GetKeywordTokenType(this, 1, .Struct)
    case 't': return Lexer_GetKeywordTokenType(this, 1, .True)
    }
    return .Identifier
}

@(private="file")
Lexer_ConsumeIdentifier :: proc(this: ^Lexer) -> Token {
    for IsAlpha(Lexer_Peek(this)) || IsDigit(Lexer_Peek(this)) do Lexer_Advance(this)
    return Lexer_Token(this, Lexer_GetIdentifierType(this))
}

@(private="file")
Lexer_ConsumeEndl :: proc(this: ^Lexer) -> Token {
    defer Lexer_AdvanceLine(this)
    return Lexer_Token(this, .Endl)
}

@(private="file")
Lexer_NextToken :: proc(this: ^Lexer) -> Token {
    Lexer_SkipWhitespace(this)
    this.start = this.current

    if Lexer_IsAtEnd(this) do return Lexer_Token(this, .EOF)

    switch Lexer_Advance(this) {
    case '(': return Lexer_Token(this, .LeftParen)
    case ')': return Lexer_Token(this, .RightParen)
    case '{': return Lexer_Token(this, .LeftBrace)
    case '}': return Lexer_Token(this, .RightBrace)
    case ':': return Lexer_Token(this, Lexer_Match(this, ':') ? .ColonColon : .Colon)
    case ';': return Lexer_Token(this, .Semicolon)
    case ',': return Lexer_Token(this, .Comma)
    case '.': return Lexer_Token(this, .Dot)
    case '-': return Lexer_Token(this, Lexer_Match(this, '>') ? .ArrowRight : .Minus)
    case '+': return Lexer_Token(this, .Plus)
    case '/': return Lexer_Token(this, .Slash)
    case '*': return Lexer_Token(this, .Star)
    case '!': return Lexer_Token(this, Lexer_Match(this, '=') ? .BangEqual    : .Bang)
    case '=': return Lexer_Token(this, Lexer_Match(this, '=') ? .EqualEqual   : .Equal)
    case '>': return Lexer_Token(this, Lexer_Match(this, '=') ? .GreaterEqual : .Greater)
    case '<': return Lexer_Token(this, Lexer_Match(this, '=') ? .LessEqual    : .Less)
    case '\n': return Lexer_ConsumeEndl(this)
    case '"': return Lexer_ConsumeStringLiteral(this)
    case '\'': return Lexer_ConsumeRuneLiteral(this)
    case '0' ..= '9': return Lexer_ConsumeNumericLiteral(this)
    case 'a' ..= 'z', 'A' ..= 'Z', '_': return Lexer_ConsumeIdentifier(this)
    }

    return Lexer_ErrorToken(this, "Unexpected character")
}