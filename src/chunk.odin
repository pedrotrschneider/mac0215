package yupii

/******************************
 * BYTECODE SPECIFICATION
 *
 * Each instruction in the bytecode of the program
 * is represented by one byte (8 bits). There are two
 * types of bytes:
 *
 * - Operations: 0xxxxxxx
 * - Operands:   1xxxxxxx
 *
 * If an instructions has it's first bit equal to 0,
 * it'll be interpreted as an operation. If the first
 * bit is equal to 1, it'll be interpreted as an
 * operand. Once one operand is found, the VM will
 * keep looking ahead in the bytecode for as long as
 * there are operands in a row. Once the VM finds the
 * next operation byte, it'll aggregate all of the bytes
 * of the operands that it found along the way and execute
 * the previously found operation with the new operand.
 * For example, if the bytecode looks like this:
 *
 * 00000011 10000100 10011110 10101100 0010101
 *
 * The VM will interprete the first byte as an operation
 * (11 = 4 => DefineLocal operation). Since this operation
 * requires an operand, the following 3 bytes
 * will be interpreted as operands and their 7 bits after
 * the leading one will be concatenated from left to right
 * to get the value of the operand (000010000111100101100).
 * The DefineLocal operation will then be executed with the
 * value of the operand. Finally, the fifth byte will be
 * interpreted as an operation (10101 = 21 => Return operation)
 * and it'll be immediately executed since it doesn't require
 * any operands.
 *****************************/

import "core:fmt"
import "core:mem"
import vmem "core:mem/virtual"
import utf8 "core:unicode/utf8"

OpCode :: enum u8 {
    Constant,
    Nil,
    True,
    False,
    Pop,
    SetLocal,
    GetLocal,
    DefineGlobal,
    SetGlobal,
    GetGlobal,
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
    Jump,
    JumpIfFalse,
    Loop,
    Return,
}

Constant :: distinct int

Local :: struct {
    name: Token,
    type: ValueType,
    depth: int,
}

Chunk :: struct {
    code: [dynamic]u8,
    lines: [dynamic]int,
    constants: [dynamic]Value,
    // Todo: Move locals to the VM
    locals: [dynamic]Local,

    arena: vmem.Arena,
    allocator: mem.Allocator,
    stackArena: vmem.Arena,
    stackAllocator: mem.Allocator,
}

Chunk_Init :: proc(this: ^Chunk) {
    arenaOk: bool
    this.allocator, arenaOk = InitGrowingArenaAllocator(&this.arena)
    if !arenaOk do panic("Unable to initialize chunk's arena")

    this.code = make([dynamic]u8, this.allocator)
    this.lines = make([dynamic]int, this.allocator)
    this.constants = make([dynamic]Value, this.allocator)
    this.locals = make([dynamic]Local, this.allocator)

    stackArenaOk: bool
    this.stackAllocator, stackArenaOk = InitGrowingArenaAllocator(&this.stackArena)
    if !stackArenaOk do panic("Unable to initialize chunk's stack arena")
}

Chunk_Free :: proc(this: ^Chunk) {
    vmem.arena_destroy(&this.arena)
    vmem.arena_destroy(&this.stackArena)
}

Chunk_AddConstant :: proc(this: ^Chunk, value: Value) -> Constant {
    append(&this.constants, value)
    return Constant(len(this.constants) - 1)
}

Chunk_GetConstantValue :: proc(this: ^Chunk, constant: Constant) -> (value: Value, success: bool) {
    index := int(constant)
    if index < 0 || index >= len(this.constants) do return Value { }, false
    return this.constants[index], true
}

Chunk_Write :: proc(this: ^Chunk, instruction: u8, line: int) {
    append(&this.code, instruction)
    append(&this.lines, line)
}

Chunk_WriteOp :: proc(this: ^Chunk, op: OpCode, line: int) {
    Chunk_Write(this, u8(op), line)
}

// *************** Local Variables ***************

Chunk_AddLocal :: proc(this: ^Chunk, name: Token) -> u8 {
    append(&this.locals, Local { name, .Bool, -1 })
    return u8(len(this.locals))
}

Chunk_ResolveLocal :: proc(this: ^Chunk, name: ^Token) -> (u8, int, bool) {
    for &local, i in this.locals {
        if IdentifiersEqual(name, &local.name) {
            return u8(i), local.depth, true
        }
    }
    return 0, 0, false
}

Chunk_HasLocal :: proc(this: ^Chunk, name: ^Token, depth: int) -> bool {
    #reverse for &local in this.locals {
        if local.depth < depth do return false
        if IdentifiersEqual(name, &local.name) do return true
    }
    return false
}

Chunk_MarkLocalInitialized :: proc(this: ^Chunk, depth: int) {
    this.locals[len(this.locals) - 1].depth = depth
}

Chunk_SetLocalType :: proc(this: ^Chunk, type: ValueType) {
    this.locals[len(this.locals) - 1].type = type
}

Chunk_RemoveLocalsFromScope :: proc(this: ^Chunk, depth: int) -> (count: int) {
    for len(this.locals) > 0 && peek(&this.locals).depth > depth {
        pop(&this.locals)
        count += 1
    }
    return
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