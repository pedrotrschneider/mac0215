package main

import "core:fmt"
import "core:os"

VM :: struct {
    chunk: ^Chunk,
    ip: int, // instruction pointer
    stack: [dynamic]Value,
}

VMInterpretResult :: enum {
    Ok,
    CompileError,
    RuntimeError,
}

VM_Init :: proc(this: ^VM) {
    this.stack = make([dynamic]Value)
}

VM_Free :: proc(this: ^VM) {
    delete(this.stack)
}

VM_StackPush :: proc(this: ^VM, value: Value) {
    append(&this.stack, value)
}

VM_StackPop :: proc(this: ^VM) -> Value {
    return pop(&this.stack)
}

VM_Run :: proc(this: ^VM) -> VMInterpretResult {
    ReadByte :: proc(this: ^VM) -> u8 {
        defer this.ip += 1
        return this.chunk.code[this.ip]
    }

    ReadOp :: proc(this: ^VM) -> OpCode {
        return OpCode(ReadByte(this))
    }

    ReadConstant :: proc(this: ^VM) -> Value {
        return Chunk_GetConstantValue(this.chunk, ReadByte(this))
    }

    BinaryOp :: proc(this: ^VM, op: OpCode) {
        b := VM_StackPop(this)
        a := VM_StackPop(this)
        #partial switch op {
        case .Add: VM_StackPush(this, a + b)
        case .Subtract: VM_StackPush(this, a - b)
        case .Multiply: VM_StackPush(this, a * b)
        case .Divide: VM_StackPush(this, a / b)
        case: panic("[ERROR] Invalid Operation: Not a binary operation")
        }
    }

    when DEBUG_TRACE_EXECUTION {
        fmt.println("== Tracing Execution ==")
    }

    for {
        when DEBUG_TRACE_EXECUTION {
            fmt.print("STACK   | ")
            for value in this.stack {
                fmt.print("[")
                Value_Print(value)
                fmt.print("]")
            }
            fmt.println()

            DisassembleInstruction(this.chunk, this.ip)
        }

        op := ReadOp(this)
        switch op {
        case .Constant: VM_StackPush(this, ReadConstant(this))
        case .Add, .Subtract, .Multiply, .Divide: BinaryOp(this, op)
        case .Negate: VM_StackPush(this, -VM_StackPop(this))
        case .Return: {
            fmt.println(VM_StackPop(this))
            return .Ok
        }
        case:
            return .CompileError
        }
    }

    return .Ok
}

VM_Interpret :: proc(this: ^VM, source: string) -> VMInterpretResult {
    chunk: Chunk
    Chunk_Init(&chunk)
    defer Chunk_Free(&chunk)

    compiler: Compiler
    if !Compiler_Compile(&compiler, source, &chunk) do return .CompileError

    this.chunk = &chunk
    this.ip = 0

    VM_Run(this)

    return .Ok
}

VM_REPL :: proc(this: ^VM) {
    when !EXECUTE_TEST_CASE {
        for {
             fmt.print("> ")

             buffer: [1024]byte
             n, err := os.read(os.stdin, buffer[:])
             if err != nil {
                 panic("[ERROR] Failed to read from stdin")
             }
             line := string(buffer[:n])
             VM_Interpret(this, line)
        }
    } else {
        VM_Interpret(this, "(1 + 2")
    }
}

VM_RunFile :: proc(this: ^VM, file: string) {
    source, err := os.read_entire_file(file)
    if err {
        fmt.fprintln(os.stderr, "[ERROR] Failed to read source file", file)
        os.exit(74)
    }
    result := VM_Interpret(this, string(source))
    switch result {
    case .Ok: fmt.println("Successfully executed file", file)
    case .CompileError: os.exit(65)
    case .RuntimeError: os.exit(70)
    }
}