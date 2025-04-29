package yupii

import "core:fmt"

DEBUG_PRINT_CODE :: #config(DEBUG_PRINT_CODE, false)
DEBUG_TRACE_EXECUTION :: #config(DEBUG_TRACE_EXECUTION, false)
EXECUTE_TEST_CASE :: #config(EXECUTE_TEST_CASE, false)

OP_NAME := [OpCode]string {
    .Constant = "OP_CONSTANT",
    .Nil = "OP_NIL",
    .True = "OP_TRUE",
    .False = "OP_FALSE",
    .Pop = "OP_POP",
    .SetLocal = "OP_SET_LOCAL",
    .GetLocal = "OP_GET_LOCAL",
    .DefineGlobal = "OP_DEFINE_GLOBAL",
    .SetGlobal = "OP_SET_GLOBAL",
    .GetGlobal = "OP_GET_GLOBAL",
    .Equal = "OP_EQUAL",
    .Greater = "OP_GREATER",
    .Less = "OP_LESS",
    .Add = "OP_ADD",
    .Subtract = "OP_SUBTRACT",
    .Multiply = "OP_MULTIPLY",
    .Divide = "OP_DIVIDE",
    .Not = "OP_NOT",
    .Negate = "OP_NEGATE",
    .Print = "OP_PRINT",
    .Jump = "OP_JUMP",
    .JumpIfFalse = "OP_JUMP_IF_FALSE",
    .Return = "OP_RETURN",
}

Debug_DisassembleInstruction :: proc(chunk: ^Chunk, offset: int) -> int {
    fmt.printf("%04d ", offset)
    if offset > 0 && chunk.lines[offset] == chunk.lines[offset - 1] {
        fmt.printf("   | ")
    } else {
        fmt.printf("%4d ", chunk.lines[offset])
    }

    op := OpCode(chunk.code[offset])
    switch op {
    case .Constant, .DefineGlobal, .GetGlobal, .SetGlobal: return ConstantInstruction(op, chunk, offset)
    case .Nil, .True, .False, .Equal, .Pop, .Greater, .Less, .Add, .Subtract, .Multiply, .Divide, .Not, .Negate, .Print, .Return:
        return SimpleInstruction(op, offset)
    case .GetLocal, .SetLocal: return ByteInstruction(op, chunk, offset)
    case .Jump, .JumpIfFalse: return JumpInstruction(op, 1, chunk, offset)
    case:
        fmt.println("[ERROR] Unknown opcode:", int(op))
        return offset + 1
    }
    return -1
}

@(private="file")
SimpleInstruction :: proc(op: OpCode, offset: int) -> int {
    fmt.println(OP_NAME[op])
    return offset + 1
}

@(private="file")
ConstantInstruction :: proc(op: OpCode, chunk: ^Chunk, offset: int) -> int {
    constant := Constant(chunk.code[offset + 1])
    fmt.printf("%-16s %4d \'", OP_NAME[op], constant)
    value, success := Chunk_GetConstantValue(chunk, constant)
    if !success do panic("Unable to retrieve constant value from chunk")
    Value_Print(value)
    fmt.println("\'")
    return offset + 2
}

@(private="file")
ByteInstruction :: proc(op: OpCode, chunk: ^Chunk, offset: int) -> int {
    slot := chunk.code[offset + 1]
    fmt.printfln("%-16s %4d", OP_NAME[op], slot)
    return offset + 2
}

@(private="file")
JumpInstruction :: proc(op: OpCode, sign: int, chunk: ^Chunk, offset: int) -> int {
    jump := u16(chunk.code[offset + 1] << 8)
    jump |= u16(chunk.code[offset + 2])
    fmt.printf("%-16s %4d -> %d\n", OP_NAME[op], offset, offset + 3 + sign * int(jump))
    return offset + 3
}