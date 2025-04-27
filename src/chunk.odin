package yupii

import "core:fmt"
import "core:mem"
import vmem "core:mem/virtual"
import utf8 "core:unicode/utf8"

OpCode :: enum {
    Constant,
    Nil,
    True,
    False,
    Pop,
    GetLocal,
    SetLocal,
    GetGlobal,
    DefineGlobal,
    SetGlobal,
    Equal,
    Greater,
    Less,
    Add,
    Subtract,
    Multiply,
    Divide,
    Not,
    Negate,
    Print,
    Return,
}

Chunk :: struct {
    code: [dynamic]u8,
    lines: [dynamic]int,
    constants: [dynamic]Value,

    chunkArena: vmem.Arena,
    chunkAllocator: mem.Allocator,
    stackArena: vmem.Arena,
    stackAllocator: mem.Allocator,
}

Chunk_Init :: proc(this: ^Chunk) {
    chunkArenaOk: bool
    this.chunkAllocator, chunkArenaOk = InitGrowingArenaAllocator(&this.chunkArena)
    if !chunkArenaOk do panic("Unable to initialize chunk's arena")

    this.code = make([dynamic]u8, this.chunkAllocator)
    this.lines = make([dynamic]int, this.chunkAllocator)
    this.constants = make([dynamic]Value, this.chunkAllocator)

    stackArenaOk: bool
    this.stackAllocator, stackArenaOk = InitGrowingArenaAllocator(&this.stackArena)
    if !stackArenaOk do panic("Unable to initialize chunk's stack arena")
}

Chunk_Free :: proc(this: ^Chunk) {
    vmem.arena_destroy(&this.chunkArena)
    vmem.arena_destroy(&this.stackArena)
}

Chunk_AddConstant :: proc(this: ^Chunk, value: Value) -> int {
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
        offset = Debug_DisassembleInstruction(this, offset)
    }
}

// *************** Allocators ***************

Chunk_AllocateBool :: proc(this: ^Chunk, value: bool) -> (boolean: ^Bool) {
    boolean = new(Bool, this.stackAllocator)
    boolean^ = Bool { value }
    return
}

Chunk_AllocateInt :: proc(this: ^Chunk, value: int) -> (integer: ^Int) {
    integer = new(Int, this.stackAllocator)
    integer^ = Int { value }
    return
}

Chunk_AllocateF64 :: proc(this: ^Chunk, value: f64) -> (float: ^F64) {
    float = new(F64, this.stackAllocator)
    float^ = F64 { value }
    return
}

Chunk_AllocateString :: proc(this: ^Chunk, value: string) -> (str: ^String) {
    str = new(String, this.stackAllocator)
    str^ = String { value }
    return
}

Chunk_AllocateStringFromRunes :: proc(this: ^Chunk, runes: []rune) -> (str: ^String) {
    str = new(String, this.stackAllocator)
    str^ = String { utf8.runes_to_string(runes, this.stackAllocator) }
    return
}

Chunk_AllocateRune :: proc(this: ^Chunk, value: rune) -> (r: ^Rune) {
    r = new(Rune, this.stackAllocator)
    r^ = Rune { value }
    return
}