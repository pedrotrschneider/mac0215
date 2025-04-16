package main

import "core:fmt"

DEBUG_PRINT_CODE :: #config(DEBUG_PRINT_CODE, false)
DEBUG_TRACE_EXECUTION :: #config(DEBUG_TRACE_EXECUTION, false)
EXECUTE_TEST_CASE :: #config(EXECUTE_TEST_CASE, false)

OP_NAME := [OpCode]string {
    .Constant = "OP_CONSTANT",
    .Add = "OP_ADD",
    .Subtract = "OP_SUBTRACT",
    .Multiply = "OP_MULTIPLY",
    .Divide = "OP_DIVIDE",
    .Negate = "OP_NEGATE",
    .Return = "OP_RETURN",
}

DisassembleInstruction :: proc(chunk: ^Chunk, offset: int) -> int {
    fmt.printf("%04d ", offset)
    if offset > 0 && chunk.lines[offset] == chunk.lines[offset - 1] {
        fmt.printf("   | ")
    } else {
        fmt.printf("%4d ", chunk.lines[offset])
    }

    op := OpCode(chunk.code[offset])
    switch op {
    case .Constant:
        return ConstantInstruction(op, chunk, offset)
    case .Add, .Subtract, .Multiply, .Divide, .Negate, .Return:
        return SimpleInstruction(op, offset)
    case:
        fmt.println("[ERROR] Unknown opcode:", int(op))
        return offset + 1
    }
    return -1
}

SimpleInstruction :: proc(op: OpCode, offset: int) -> int {
    fmt.println(OP_NAME[op])
    return offset + 1
}

ConstantInstruction :: proc(op: OpCode, chunk: ^Chunk, offset: int) -> int {
    constant := chunk.code[offset + 1]
    fmt.printf("%-16s %4d \'", OP_NAME[op], constant)
    Value_Print(Chunk_GetConstantValue(chunk, constant))
    fmt.println("\'")
    return offset + 2
}