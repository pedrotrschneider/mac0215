#+private
package yupii

import fmt "core:fmt"
import "core:os"
import utf8 "core:unicode/utf8"

Parser :: struct {
    tokens: [dynamic]Token,
    current, previous: int,
    hadError, panicMode: bool,
}

Parser_Init :: proc(this: ^Parser) {
    this.tokens = make([dynamic]Token)
    this.current = 0
    this.previous = 0
    this.hadError = false
    this.panicMode = false
}

Parser_Free :: proc(this: ^Parser) {
    delete(this.tokens)
}

Parser_Swap :: proc(this: ^Parser) {
    this.previous = max(0, this.current)
}

Parser_Previous :: proc(this: ^Parser) -> Token {
    return this.tokens[this.previous]
}

Parser_Current :: proc(this: ^Parser) -> Token {
    return this.tokens[this.current]
}

Parser_PushToken :: proc(this: ^Parser, token: Token) {
    append(&this.tokens, token)
}

Parser_Advance :: proc(this: ^Parser) -> Token {
    defer IncrementCurrent(this)
    return this.tokens[this.current]
}

Parser_Peek :: proc(this: ^Parser, depth: int) -> Token {
    return this.tokens[this.current + depth]
}

Parser_RemainingTokens :: proc(this: ^Parser) -> int {
    return len(this.tokens) - this.current
}

Parser_IsAtEnd :: proc(this: ^Parser) -> bool {
    return this.current >= len(this.tokens)
}

Parser_ErrorAt :: proc(this: ^Parser, token: ^Token, message: string) {
    // We ignore all following errors if an error has been found
    if this.panicMode do return

    this.panicMode = true
    fmt.fprintf(os.stderr, "[%d:%d] Error", token.line, token.col)

    if token.type == .EOF do fmt.fprintf(os.stderr, " at end")
    else if token.type == .Error {
        errorMessage, success := Token_GetErrorMessage(token)
        if !success do panic("Unable to get error message from token")
        fmt.print(errorMessage)
    } else {
        tokenSource, success := Token_GetSource(token)
        if !success do panic("Unable to get source from token")
        tokenString := utf8.runes_to_string(tokenSource)
        defer delete(tokenString)
        fmt.fprintf(os.stderr, " at \"%s\"", tokenString)
    }

    fmt.fprintln(os.stderr, ":", message)
    this.hadError = true
}

Parser_ErrorAtCurrent :: proc(this: ^Parser, message: string) {
    current := Parser_Current(this)
    Parser_ErrorAt(this, &current, message)
}

Parser_Error :: proc(this: ^Parser, message: string) {
    previous := Parser_Previous(this)
    Parser_ErrorAt(this, &previous, message)
}

@(private)
IncrementCurrent :: proc(this: ^Parser) {
    this.current = min(len(this.tokens) - 1, this.current + 1)
}