package yupii

import "core:fmt"
import "core:os"
import "core:mem"
import vmem "core:mem/virtual"

CallFrame :: struct {
    procedure: ^Procedure,
    ip: int, // instruction pointer
    slots: []Value,
}

VM :: struct {
    stack: [dynamic]Value,
    frames: [dynamic]CallFrame,
    // Todo: Globals suck. Fix them. They should work simmilarly to locals
    globals: map[string]Value,

    vmArena: vmem.Arena,
    vmAllocator: mem.Allocator,
}

VMInterpretResult :: enum {
    Ok,
    CompileError,
    RuntimeError,
}

VMTranspileResult :: enum {
    Ok,
    TranspileError,
}

VM_Init :: proc(this: ^VM) {
    vmArenaOk: bool
    this.vmAllocator, vmArenaOk = InitGrowingArenaAllocator(&this.vmArena)
    if !vmArenaOk do panic("Unable to initialize vm's arena")

    this.stack = make([dynamic]Value, this.vmAllocator)
    this.frames = make([dynamic]CallFrame, this.vmAllocator)
    this.globals = make(map[string]Value, this.vmAllocator)

    VM_DefineNative(this, "sqrt", BindingSqrt)
    VM_DefineNative(this, "println", BindingPrintLn)

    VM_DefineNative(this, "NativeTest", NativeTest)
    VM_DefineNative(this, "RlInitWindow", RlInitWindow)
    VM_DefineNative(this, "RlCloseWindow", RlCloseWindow)
    VM_DefineNative(this, "RlWindowShouldClose", RlWindowShouldClose)
    VM_DefineNative(this, "RlSetTargetFPS", RlSetTargetFPS)
    VM_DefineNative(this, "RlPollInputEvents", RlPollInputEvents)
    VM_DefineNative(this, "RlIsKeyPressed", RlIsKeyPressed)
    VM_DefineNative(this, "RlIsKeyDown", RlIsKeyDown)
    VM_DefineNative(this, "RlBeginDrawing", RlBeginDrawing)
    VM_DefineNative(this, "RlEndDrawing", RlEndDrawing)
    VM_DefineNative(this, "RlClearBackground", RlClearBackground)
    VM_DefineNative(this, "RlDrawRectangle", RlDrawRectangle)
    VM_DefineNative(this, "RlDrawCircle", RlDrawCircle)
    VM_DefineNative(this, "RlDeltaTime", RlDeltaTime)

    VM_DefineNative(this, "RlKeyEscape", RlKeyEscape)
    VM_DefineNative(this, "RlKeyUp", RlKeyUp)
    VM_DefineNative(this, "RlKeyDown", RlKeyDown)
    VM_DefineNative(this, "RlKeyLeft", RlKeyLeft)
    VM_DefineNative(this, "RlKeyRight", RlKeyRight)
    VM_DefineNative(this, "RlKeyW", RlKeyW)
    VM_DefineNative(this, "RlKeyA", RlKeyA)
    VM_DefineNative(this, "RlKeyS", RlKeyS)
    VM_DefineNative(this, "RlKeyD", RlKeyD)
}

VM_Free :: proc(this: ^VM) {
    vmem.arena_destroy(&this.vmArena)
}

VM_StackPush :: proc(this: ^VM, value: Value) {
    append(&this.stack, value)
}

VM_StackPop :: proc(this: ^VM) -> Value {
    return pop(&this.stack)
}

VM_StackPeek :: proc(this: ^VM, distance: int) -> Value {
    return peek(&this.stack, distance)
}

VM_FramePush :: proc(this: ^VM, frame: CallFrame) {
    append(&this.frames, frame)
}

VM_FramePop :: proc(this: ^VM) -> CallFrame {
    return pop(&this.frames)
}

VM_FramePeek :: proc(this: ^VM) -> ^CallFrame {
    return &this.frames[len(this.frames) - 1]
}

VM_Call :: proc(this: ^VM, procedure: ^Procedure, argCount: int) -> bool {
    if argCount != procedure.arity {
        VM_RuntimeError(this, "Expected %d arguments but got %d", procedure.arity, argCount)
        return false
    }

    if len(this.frames) == max(int) {
        VM_RuntimeError(this, "Stack overflow")
        return false
    }

    frame := CallFrame { }
    frame.procedure = procedure
    frame.ip = 0
    // This stack frame includes all of the procedures arguments plus an
    // empty stack slot at the begining
    frame.slots = this.stack[max(0, len(this.stack) - argCount - 1):]
    VM_FramePush(this, frame)

    return true
}

VM_CallValue :: proc(this: ^VM, calee: Value, argCount: int) -> bool {
    #partial switch calee.type {
    case .Procedure: return VM_Call(this, Value_AsProcedure(calee), argCount)
    case .NativeProcedure: {
        nativeProc := Value_AsNativeProcedure(calee)
        result := nativeProc(argCount, this.stack[max(0, len(this.stack) - argCount):], this.vmAllocator)
        for i := 0; i < argCount + 1; i += 1 {
            VM_StackPop(this)
        }
        VM_StackPush(this, result)
        return true
    }
    }
    VM_RuntimeError(this, "Can only call procedures")
    return false
}

VM_Run :: proc(this: ^VM) -> VMInterpretResult {
    ReadByte :: proc(this: ^CallFrame) -> u8 {
        defer this.ip += 1
        return this.procedure.chunk.code[this.ip]
    }

    ReadShort :: proc(this: ^CallFrame) -> u16 {
        defer this.ip += 2
        return u16(this.procedure.chunk.code[this.ip] << 8) | u16(this.procedure.chunk.code[this.ip + 1])
    }

    ReadOp :: proc(this: ^CallFrame) -> OpCode {
        return OpCode(ReadByte(this))
    }

    ReadConstant :: proc(this: ^CallFrame) -> Value {
        value, ok := Chunk_GetConstantValue(&this.procedure.chunk, Constant(ReadByte(this)))
        if !ok do panic("Unable to read constant value from chunk")
        return value
    }

    ReadString :: proc(this: ^CallFrame) -> ^String {
        return Value_AsString(ReadConstant(this))
    }

    BinaryOp :: proc(this: ^VM, op: OpCode) {
        frame := VM_FramePeek(this)
        b, okB := Value_TryAsF64(VM_StackPop(this))
        a, okA := Value_TryAsF64(VM_StackPop(this))
        if !okA || !okB {
            VM_RuntimeError(this, "Operands must be f64.")
        }
        av, bv := a.value, b.value
        #partial switch op {
        case .Greater: VM_StackPush(this, Value_Bool(Chunk_AllocateBool(&frame.procedure.chunk, av > bv)))
        case .Less: VM_StackPush(this, Value_Bool(Chunk_AllocateBool(&frame.procedure.chunk, av < bv)))
        case .Add: VM_StackPush(this, Value_F64(Chunk_AllocateF64(&frame.procedure.chunk, av + bv)))
        case .Subtract: VM_StackPush(this, Value_F64(Chunk_AllocateF64(&frame.procedure.chunk, av - bv)))
        case .Multiply: VM_StackPush(this, Value_F64(Chunk_AllocateF64(&frame.procedure.chunk, av * bv)))
        case .Divide: VM_StackPush(this, Value_F64(Chunk_AllocateF64(&frame.procedure.chunk, av / bv)))
        case: panic("[ERROR] Invalid Operation: Not a binary operation")
        }
    }

    frame := VM_FramePeek(this)

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

            Debug_DisassembleInstruction(&frame.procedure.chunk, frame.ip)
        }

        op := ReadOp(frame)
        switch op {
        case .Constant: VM_StackPush(this, ReadConstant(frame))
        case .Nil: {
        } //VM_StackPush(this, Value_Nil())
        case .True: VM_StackPush(this, Value_Bool(Chunk_AllocateBool(&frame.procedure.chunk, true)))
        case .False: VM_StackPush(this, Value_Bool(Chunk_AllocateBool(&frame.procedure.chunk, false)))
        case .Pop: VM_StackPop(this)
        case .GetLocal: {
            slot := ReadByte(frame)
            VM_StackPush(this, frame.slots[slot])
        }
        case .SetLocal: {
            slot := ReadByte(frame)
            frame.slots[slot] = VM_StackPeek(this, 0)
        }
        case .GetGlobal: {
            globalName := ReadString(frame)
            globalValue, ok := this.globals[globalName.value]
            if !ok {
                VM_RuntimeError(this, "Undefined variable %s", globalName.value)
                return .RuntimeError
            }
            VM_StackPush(this, globalValue)
        }
        case .DefineGlobal: {
            globalName := ReadString(frame)
            this.globals[globalName.value] = VM_StackPeek(this, 0)
            VM_StackPop(this)
        }
        case .SetGlobal: {
            globalName := ReadString(frame)
            _, ok := this.globals[globalName.value]
            if !ok {
                VM_RuntimeError(this, "Undefined variable %s", globalName.value)
                return .RuntimeError
            }
            this.globals[globalName.value] = VM_StackPeek(this, 0)
        }
        case .Equal: {
            b := VM_StackPop(this)
            a := VM_StackPop(this)
            value := Chunk_AllocateBool(&frame.procedure.chunk, Value_Equals(a, b))
            VM_StackPush(this, Value_Bool(value))
        }
        case .Greater, .Less, .Add, .Subtract, .Multiply, .Divide: BinaryOp(this, op)
        case .Not: VM_StackPush(this, Value_Bool(Chunk_AllocateBool(&frame.procedure.chunk, Value_IsFalsey(VM_StackPop(this)))))
        case .Negate: {
            number, ok := Value_TryAsF64(VM_StackPeek(this, 0))
            if !ok {
                VM_RuntimeError(this, "Operand must be a number.")
                return .RuntimeError
            }
            VM_StackPop(this)
            VM_StackPush(this, Value_F64(Chunk_AllocateF64(&frame.procedure.chunk, -number.value)))
        }
        case .Print: Value_Println(VM_StackPop(this))
        case .Jump: {
            offset := ReadShort(frame)
            frame.ip += int(offset)
        }
        case .JumpIfFalse: {
            offset := ReadShort(frame)
            if Value_IsFalsey(VM_StackPeek(this, 0)) do frame.ip += int(offset)
        }
        case .Loop: {
            offset := ReadShort(frame)
            frame.ip -= int(offset)
        }
        case .Call: {
            argCount := int(ReadByte(frame))
            if !VM_CallValue(this, VM_StackPeek(this, argCount), argCount) do return .RuntimeError
            frame = VM_FramePeek(this)
        }
        case .Return: {
            VM_FramePop(this)
            // If this was the last call frame, end
            if len(this.frames) == 0 {
                return .Ok
            }

            result := VM_StackPop(this)
            if result.type != .Procedure && result.type != .NativeProcedure {
                VM_StackPop(this)
            }
            VM_StackPush(this, result)
            frame = VM_FramePeek(this)
        }
        case: return .CompileError
        }
    }

    return .Ok
}

VM_Interpret :: proc(this: ^VM, source: string) -> VMInterpretResult {
    parser: Parser
    Parser_Init(&parser)
    defer Parser_Free(&parser)

    compiler: Compiler
    Compiler_Init(&compiler, &parser, true)
    defer Compiler_Free(&compiler)

    ok, procedure := Compiler_Compile(&compiler, source)
    if !ok do return .CompileError

    VM_Call(this, procedure, 0)

    return VM_Run(this)
}

VM_Transpile :: proc(this: ^VM, settings: TranspilerSettings, source: string) -> VMTranspileResult {
    transpiler: Transpiler
    Transpiler_Init(&transpiler, settings)
    defer Transpiler_Free(&transpiler)

    Transpiler_Transpiler(&transpiler, source)

    return .Ok
}

VM_REPL :: proc(this: ^VM) {
    for {
        fmt.print("> ")

        buffer: [1024]byte
        _, err := os.read(os.stdin, buffer[:])
        if err != nil {
            panic("[ERROR] Failed to read from stdin")
        }
        line := string(buffer[:])
        if len(line) > 0 do VM_Interpret(this, line)
        else do break
    }
}

VM_RunFile :: proc(this: ^VM, file: string) {
    fmt.println("[DEBUG] Executing file", file)
    source, ok := os.read_entire_file_from_filename(file, this.vmAllocator)
    if !ok {
        fmt.fprintln(os.stderr, "[ERROR] Failed to read source file", file)
        os.exit(74)
    }
    result := VM_Interpret(this, string(source))
    switch result {
    case .Ok: fmt.println("[DEBUG] Successfully executed file", file)
    case .CompileError: os.exit(65)
    case .RuntimeError: os.exit(70)
    }
}

VM_TranspileFile :: proc(this: ^VM, settings: TranspilerSettings, file: string) {
    fmt.println("[DEBUG] Transpiling file", file)
    source, ok := os.read_entire_file_from_filename(file, this.vmAllocator)
    if !ok {
        fmt.fprintln(os.stderr, "[ERROR] Failed to read source file", file)
        os.exit(74)
    }
    result := VM_Transpile(this, settings, string(source))
    switch result {
    case .Ok: fmt.println("[DEBUG] Successfully executed file", file)
    case .TranspileError: fmt.println("[DEBUG] Failed to transpile file", file)
    }
}

VM_RuntimeError :: proc(this: ^VM, format: string, vargs: ..any) {
    fmt.fprintfln(os.stderr, format, ..vargs)

    #reverse for frame in this.frames {
        procedure := frame.procedure
        instruction := frame.ip
        fmt.fprintf(os.stderr, "[line %d] in %s()", procedure.chunk.lines[instruction], procedure.name)
    }

    frame := VM_FramePeek(this)
    line := frame.procedure.chunk.lines[frame.ip]
    fmt.fprintfln(os.stderr, "[line %d] in script", line)
}

VM_DefineNative :: proc(this: ^VM, name: string, procedure: NativeProcedure) {
    value := Value_NativeProcedure(procedure)
    this.globals[name] = value
}