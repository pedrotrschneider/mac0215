package main

import "core:fmt"

OpCode :: enum {
    Constant,
    Nil,
    True,
    False,
    Equal,
    Greater,
    Less,
    Add,
    Subtract,
    Multiply,
    Divide,
    Not,
    Negate,
    Return,
}

Chunk :: struct {
    code: [dynamic]u8,
    lines: [dynamic]int,
    constants: [dynamic]Value,
}

Chunk_Init :: proc(this: ^Chunk) {
    this.code = make([dynamic]u8)
    this.lines = make([dynamic]int)
    this.constants = make([dynamic]Value)
}

Chunk_Free :: proc(this: ^Chunk) {
    delete(this.code)
    delete(this.lines)
    delete(this.constants)
}

Chunk_AddConstant :: proc(this: ^Chunk, value: Value) -> int {
    resize(&this.constants, len(this.constants) + 1)
    append(&this.constants, value)
    return len(this.constants) - 1
}

Chunk_GetConstantValue :: proc(this: ^Chunk, constant: u8) -> Value {
    return this.constants[constant]
}

Chunk_Write :: proc(this: ^Chunk, byte: u8, line: int) {
    append(&this.code, byte)
    append(&this.lines, line)
}

Chunk_WriteOp :: proc(this: ^Chunk, op: OpCode, line: int) {
    Chunk_Write(this, u8(op), line)
}

Chunk_Disassemble :: proc(this: ^Chunk, name: string) {
    fmt.println("==", name, "==")

    for offset := 0; offset < len(this.code); {
        offset = DisassembleInstruction(this, offset)
    }
}