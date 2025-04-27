package yupii

import "core:fmt"
import "core:os"

Parser :: struct {
    current, previous: Token,
    hadError, panicMode: bool,
}

Parser_Init :: proc(this: ^Parser) {
    this.hadError = false
    this.panicMode = false
}

Parser_ErrorAt :: proc(this: ^Parser, token: ^Token, message: string) {
    if this.panicMode do return
    this.panicMode = true
    fmt.fprintf(os.stderr, "[line %d] Error", token.line)

    if token.type == .EOF do fmt.fprint(os.stderr, " at end")
    else if token.type == .Error do fmt.print()
    else {
        tokenSource, shouldFree := Token_GetSourceString(token)
        defer if shouldFree do delete(tokenSource)

        fmt.fprintf(os.stderr, " at \"%s\"", tokenSource)
    }

    fmt.fprintln(os.stderr, ":", message)
    this.hadError = true
}

Parser_ErrorAtCurrent :: proc(this: ^Parser, message: string) {
    Parser_ErrorAt(this, &this.current, message)
}

Parser_Error :: proc(this: ^Parser, message: string) {
    Parser_ErrorAt(this, &this.previous, message)
}