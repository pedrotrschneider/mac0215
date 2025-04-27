package yupii

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

VM_StackPeek :: proc(this: ^VM, distance: int) -> Value {
    return this.stack[len(this.stack) - 1 - distance]
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
        b, okB := Value_TryAsF64(VM_StackPop(this))
        a, okA := Value_TryAsF64(VM_StackPop(this))
        if !okA || !okB {
            VM_RuntimeError(this, "Operands must be f64.")
        }
        av, bv := a.value, b.value
        #partial switch op {
        case .Greater: VM_StackPush(this, Value_Bool(Chunk_AllocateBool(this.chunk, av > bv)))
        case .Less: VM_StackPush(this, Value_Bool(Chunk_AllocateBool(this.chunk, av < bv)))
        case .Add: VM_StackPush(this, Value_F64(Chunk_AllocateF64(this.chunk, av + bv)))
        case .Subtract: VM_StackPush(this, Value_F64(Chunk_AllocateF64(this.chunk, av - bv)))
        case .Multiply: VM_StackPush(this, Value_F64(Chunk_AllocateF64(this.chunk, av - bv)))
        case .Divide: VM_StackPush(this, Value_F64(Chunk_AllocateF64(this.chunk, av / bv)))
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

            Debug_DisassembleInstruction(this.chunk, this.ip)
        }


        op := ReadOp(this)
        switch op {
        case .Constant: VM_StackPush(this, ReadConstant(this))
//        case .Nil: VM_StackPush(this, Value_Nil())
        case .True: VM_StackPush(this, Value_Bool(Chunk_AllocateBool(this.chunk, true)))
        case .False: VM_StackPush(this, Value_Bool(Chunk_AllocateBool(this.chunk, false)))
        case .Equal: {
            b := VM_StackPop(this)
            a := VM_StackPop(this)
            value := Chunk_AllocateBool(this.chunk, Value_Equals(a, b))
            VM_StackPush(this, Value_Bool(value))
        }
        case .Greater, .Less, .Add, .Subtract, .Multiply, .Divide: BinaryOp(this, op)
//        case .Add: {
//            if Value_IsString(VM_StackPeek(this, 0)) && Value_IsString(VM_StackPeek(this, 0)) {
//                VM_ConcatenateObjStrings(this)
//            } else if Value_IsNumber(VM_StackPeek(this, 0)) && Value_IsNumber(VM_StackPeek(this, 0)) {
//                b := Value_AsNumber(VM_StackPop(this))
//                a := Value_AsNumber(VM_StackPop(this))
//                VM_StackPush(this, Value_Number(a + b))
//            } else {
//                VM_RuntimeError(this, "Operands must be two number os two strings")
//                return .RuntimeError
//            }
//        }
        case .Not: VM_StackPush(this, Value_Bool(Chunk_AllocateBool(this.chunk, Value_IsFalsey(VM_StackPop(this)))))
        case .Negate: {
            number, ok := Value_TryAsF64(VM_StackPeek(this, 0))
            if !ok {
                VM_RuntimeError(this, "Operand must be a number.")
                return .RuntimeError
            }
            VM_StackPush(this, Value_F64(Chunk_AllocateF64(this.chunk, -number.value)))
            VM_StackPop(this)
        }
        case .Return: {
            Value_Print(VM_StackPop(this))
            fmt.println()
            fmt.println()
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
            line := string(buffer[:n - 1])
            if len(line) > 0 do VM_Interpret(this, line)
            else do break
        }
    } else {
        VM_Interpret(this, TEST_INPUT)
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

VM_RuntimeError :: proc(this: ^VM, format: string, vargs: ..string) {
    fmt.fprintfln(os.stderr, format, vargs)

    line := this.chunk.lines[this.ip]
    fmt.fprintfln(os.stderr, "[line %d] in script", line)
}

// Warning: This procedure assumes the top two values on the stack are `ObjString`s
//VM_ConcatenateObjStrings :: proc(this: ^VM) {
//    b := Value_AsString(VM_StackPop(this))
//    a := Value_AsString(VM_StackPop(this))
//
//    newLength := len(a.runes) + len(b.runes)
//    newRunes := make([]rune, newLength)
//    copy(newRunes[:len(a.runes)], a.runes)
//    copy(newRunes[len(a.runes):], b.runes)
//    result := Obj_TakeRunesToObjString(newRunes)
//    VM_StackPush(this, Value_Obj(result))
//}