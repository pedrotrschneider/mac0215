package main

import "core:fmt"
import "core:os"

Parser :: struct {
    current, previous: Token,
    had_error, panic_mode: bool,
}

Parser_Init :: proc(this: ^Parser) {
    this.had_error = false
    this.panic_mode = false
}

Parser_ErrorAt :: proc(this: ^Parser, token: ^Token, message: string) {
    if this.panic_mode do return
    this.panic_mode = true
    fmt.fprintf(os.stderr, "[line %d] Error", token.line)

    if token.type == .EOF do fmt.fprint(os.stderr, " at end")
    else if token.type == .Error do fmt.print()
    else do fmt.fprint(os.stderr, " at", token.source[token.start:token.start + token.length])

    fmt.fprintln(os.stderr, ":", message)
    this.had_error = true
}

Parser_ErrorAtCurrent :: proc(this: ^Parser, message: string) {
    Parser_ErrorAt(this, &this.current, message)
}

Parser_Error :: proc(this: ^Parser, message: string) {
    Parser_ErrorAt(this, &this.previous, message)
}