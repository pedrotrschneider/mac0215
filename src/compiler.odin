package yupii

import "core:strconv"
import utf8 "core:unicode/utf8"
import fmt "core:fmt"
import os "core:os"
import "core:mem"
import vmem "core:mem/virtual"

// *************** PUBLIC ***************

Local :: struct {
    name: Token,
    depth: int,
}

Compiler :: struct {
    locals: [dynamic]Local,
    scopeDepth: int,
    compilingChunk : ^Chunk,
    scanner: Scanner,
    parser: Parser,

    compilerArena: vmem.Arena,
    compilerAllocator: mem.Allocator,
}

Compiler_Init :: proc(this: ^Compiler) {
    compilerArenaOk: bool
    this.compilerAllocator, compilerArenaOk = InitGrowingArenaAllocator(&this.compilerArena)
    if !compilerArenaOk do panic("Unable to create compiler's arena")

    this.locals = make([dynamic]Local, 0, int(max(u8)) + 1, this.compilerAllocator)
    this.scopeDepth = 0

    Parser_Init(&this.parser)
}

Compiler_Free :: proc(this: ^Compiler) {
    vmem.arena_destroy(&this.compilerArena)
}

Compiler_Compile :: proc(this: ^Compiler, source: string, chunk: ^Chunk) -> bool {
    Scanner_Init(&this.scanner, source)
    defer Scanner_Free(&this.scanner)

    this.compilingChunk = chunk

    Compiler_Advance(this)

    for !Compiler_MatchToken(this, .EOF) {
        Compiler_CompileDeclaration(this)
    }

    Compiler_End(this)

    return !this.parser.hadError
}

// *************** PRIVATE ***************

// *************** Core functions ***************

@(private="file")
Compiler_Advance :: proc(this: ^Compiler) {
    this.parser.previous = this.parser.current

    for {
        this.parser.current = Scanner_ScanToken(&this.scanner)
        if this.parser.current.type != .Error do break

        current := this.parser.current
        errorMessage, shouldFree := Token_GetSourceString(&current)
        defer if shouldFree do delete(errorMessage)
        Parser_ErrorAtCurrent(&this.parser, errorMessage)
    }
}

@(private="file")
Compiler_Consume :: proc(this: ^Compiler, type: TokenType, message: string) {
    if this.parser.current.type != type do Parser_ErrorAtCurrent(&this.parser, message)
    Compiler_Advance(this)
}

@(private="file")
Compiler_ParsePrecedence :: proc(this: ^Compiler, precedence: Precedence) {
    Compiler_Advance(this)
    prefixRule := Compiler_GetRule(this.parser.previous.type).prefix
    if prefixRule == nil {
        Parser_Error(&this.parser, "Expected expression")
        return
    }

    canAssign := precedence <= .Assignment
    prefixRule(this, canAssign)

    for precedence <= Compiler_GetRule(this.parser.current.type).precedence {
        Compiler_Advance(this)
        infix_rule := Compiler_GetRule(this.parser.previous.type).infix
        infix_rule(this, canAssign)
    }
}

@(private="file")
Compiler_IdentifierConstant :: proc(this: ^Compiler, name: ^Token) -> u8 {
    nameRunes := name.source.([]rune)[name.start:name.start + name.length]
    str := Chunk_AllocateStringFromRunes(this.compilingChunk, nameRunes)
    return Compiler_MakeConstant(this, Value_String(str))
}

@(private="file")
Compiler_ResolveLocal :: proc(this: ^Compiler, name: ^Token) -> (u8, bool) {
    for &local, i in this.locals {
        if IdentifiersEqual(name, &local.name) {
            // If local.depth == -1 this means the variable has been declared but not defined yet.
            // If that's the case, the user is likely trying to do something like this: a := a
            if local.depth == -1 do Parser_Error(&this.parser, "Can't read local variable in its own initializer")
            return u8(i), true
        }
    }
    return 0, false
}

@(private="file")
Compiler_AddLocal :: proc(this: ^Compiler, name: Token) {
    if len(this.locals) > 255 {
        Parser_Error(&this.parser, "Too many local variables in scope.")
        return
    }
    append(&this.locals, Local { name, -1 })
}

@(private="file")
Compiler_DeclareVariable :: proc(this: ^Compiler) {
    if this.scopeDepth == 0 do return // If it's a global variable, we don't need to do anything

    name := &this.parser.previous
    // Check if a variable with this name already exists in the current scope
    #reverse for &local in this.locals {
        if local.depth < this.scopeDepth do break
        if IdentifiersEqual(name, &local.name) {
            Parser_Error(&this.parser, "A variable with this name already existis in the current scope")
        }
    }
    Compiler_AddLocal(this, name^)
}

@(private="file")
Compiler_ParseVariable :: proc(this: ^Compiler, errorMessage: string) -> u8 {
    Compiler_Consume(this, .Identifier, errorMessage)

    Compiler_DeclareVariable(this)
    if this.scopeDepth > 0 do return 0

    return Compiler_IdentifierConstant(this, &this.parser.previous)
}

@(private="file")
Compiler_MarkVariableInitialized :: proc(this: ^Compiler) {
    this.locals[len(this.locals) - 1].depth = this.scopeDepth
}

@(private="file")
Compiler_DefineVariable :: proc(this: ^Compiler, global: u8) {
    // If it's not a global variable, we don't need to do anything
    if this.scopeDepth > 0 {
        Compiler_MarkVariableInitialized(this)
        return
    }
    Compiler_EmitOpAndOperand(this, .DefineGlobal, global)
}

// *************** Utils ***************

@(private="file")
Compiler_CurrentChunk :: proc(this: ^Compiler) -> ^Chunk {
    return this.compilingChunk
}

@(private="file")
Compiler_MakeConstant :: proc(this: ^Compiler, value: Value) -> u8 {
    constant := Chunk_AddConstant(Compiler_CurrentChunk(this), value)
    if constant > int(max(u8)) {
        Parser_Error(&this.parser, "Too many constants in on chunk")
        return 0
    }
    return u8(constant)
}

@(private="file")
Compiler_MatchToken :: proc(this: ^Compiler, type: TokenType) -> bool {
    if !Compiler_CheckToken(this, type) do return false
    Compiler_Advance(this)
    return true
}

@(private="file")
Compiler_CheckToken :: proc(this: ^Compiler, type: TokenType) -> bool {
    return this.parser.current.type == type
}

@(private="file")
Compiler_BeginScope :: proc(this: ^Compiler) {
    this.scopeDepth += 1
}

@(private="file")
Compiler_EndScope :: proc(this: ^Compiler) {
    this.scopeDepth -= 1
    // Remove all local variables from the scope that's closing
    for len(this.locals) > 0 && peek(&this.locals).depth > this.scopeDepth {
        Compiler_EmitOp(this, .Pop)
        pop(&this.locals)
    }
}

@(private="file")
Compiler_End :: proc(this: ^Compiler) {
    Compiler_EmitReturn(this)
    when DEBUG_PRINT_CODE {
        if !this.parser.hadError do Chunk_Disassemble(Compiler_CurrentChunk(this), "Code")
    }
}

// *************** Operator precedence helpers ***************

@(private="file")
Precedence :: enum {
    None,
    Assignment, // =
    Or, //         or
    And, //        and
    Equality, //   == !=
    Comparison, // < > <= >=
    Term, //       + -
    Factor, //     * /
    Unary, //      ! -
    Call, //       . ()
    Primary,
}

@(private="file")
ParseFn :: proc(this: ^Compiler, canAssign: bool)
@(private="file")
ParseRule :: struct {
    prefix, infix: ParseFn,
    precedence: Precedence,
}

@(private="file")
rules : [TokenType]ParseRule = {
    .LeftParen = { Compiler_CompileGrouping, nil, .None },
    .RightParen = { nil, nil, .None },
    .LeftBrace = { nil, nil, .None },
    .RightBrace = { nil, nil, .None },
    .Comma = { nil, nil, .None },
    .Dot = { nil, nil, .None },
    .Minus = { Compiler_CompileUnary, Compiler_CompileBinary, .Term },
    .Plus = { nil, Compiler_CompileBinary, .Term },
    .Colon = { nil, nil, .None },
    .Semicolon = { nil, nil, .None },
    .Slash = { nil, Compiler_CompileBinary, .Factor },
    .Star = { nil, Compiler_CompileBinary, .Factor },
    .Bang = { Compiler_CompileUnary, nil, .None },
    .BangEqual = { nil, Compiler_CompileBinary, .Equality },
    .Equal = { nil, nil, .None },
    .EqualEqual = { nil, Compiler_CompileBinary, .Equality },
    .Greater = { nil, Compiler_CompileBinary, .Comparison },
    .GreaterEqual = { nil, Compiler_CompileBinary, .Comparison },
    .Less = { nil, Compiler_CompileBinary, .Comparison },
    .LessEqual = { nil, Compiler_CompileBinary, .Comparison },
    .ArrowRight = { nil, nil, .None },
    .Identifier = { Compiler_CompileVariable, nil, .None },
    .TypeId = { nil, nil, .None },
    .NumericLiteral = { Compiler_CompileNumeric, nil, .None },
    .StringLiteral = { Compiler_CompileString, nil, .None },
    .RuneLiteral = { Compiler_CompileRune, nil, .None },
    .And = { nil, nil, .None },
    .Else = { nil, nil, .None },
    .False = { Compiler_CompileLiteral, nil, .None },
    .For = { nil, nil, .None },
    .Defer = { nil, nil, .None },
    .If = { nil, nil, .None },
    .Nil = { Compiler_CompileLiteral, nil, .None },
    .Or = { nil, nil, .None },
    .Print = { nil, nil, .None },
    .Var = { nil, nil, .None },
    .Proc = { nil, nil, .None },
    .Struct = { nil, nil, .None },
    .Distinct = { nil, nil, .None },
    .Return = { nil, nil, .None },
    .True = { Compiler_CompileLiteral, nil, .None },
    .Error = { nil, nil, .None },
    .EOF = { nil, nil, .None },
}

@(private="file")
Compiler_GetRule :: proc(type: TokenType) -> ^ParseRule {
    return &rules[type]
}

// *************** Expression compilation helpers ***************

@(private="file")
Compiler_CompileNumeric :: proc(this: ^Compiler, canAssign: bool) {
    previous := this.parser.previous
    numberStr := utf8.runes_to_string(previous.source.([]rune)[previous.start:previous.start + previous.length])
    defer delete(numberStr)

    number, ok := strconv.parse_f64(numberStr)
    if !ok {
        fmt.fprintln(os.stderr, "[ERROR] Unable to convert", numberStr, "to number")
        panic("Exiting...")
    }
    literal := Chunk_AllocateF64(this.compilingChunk, number)
    value := Value_F64(literal)
    Compiler_EmitConstant(this, Compiler_MakeConstant(this, value))
}

@(private="file")
Compiler_CompileString :: proc(this: ^Compiler, canAssign: bool) {
    start := this.parser.previous.start + 1 // Skip the "
    end := start + this.parser.previous.length - 2 // Remove the final "
    str := Chunk_AllocateStringFromRunes(this.compilingChunk, this.parser.previous.source.([]rune)[start:end])
    constant := Compiler_MakeConstant(this, Value_String(str))
    Compiler_EmitConstant(this, constant)
}

@(private="file")
Compiler_CompileRune :: proc(this: ^Compiler, canAssign: bool) {
    start := this.parser.previous.start + 1 // Skip the '
    r := Chunk_AllocateRune(this.compilingChunk, this.parser.previous.source.([]rune)[start])
    constant := Compiler_MakeConstant(this, Value_Rune(r))
    Compiler_EmitConstant(this, constant)
}

@(private="file")
Compiler_CompileNamedVariable :: proc(this: ^Compiler, name: ^Token, canAssign: bool) {
    getOp, setOp: OpCode
    arg, found := Compiler_ResolveLocal(this, name)
    if found {
        getOp = .GetLocal
        setOp = .SetLocal
    } else {
        arg = Compiler_IdentifierConstant(this, name)
        getOp = .GetGlobal
        setOp = .SetGlobal
    }

    if canAssign && Compiler_MatchToken(this, .Equal) {
        Compiler_CompileExpression(this)
        Compiler_EmitOpAndOperand(this, setOp, arg)
    } else do Compiler_EmitOpAndOperand(this, getOp, arg)

}

@(private="file")
Compiler_CompileVariable :: proc(this: ^Compiler, canAssign: bool) {
    Compiler_CompileNamedVariable(this, &this.parser.previous, canAssign)
}

@(private="file")
Compiler_CompileGrouping :: proc(this: ^Compiler, canAssign: bool) {
    Compiler_CompileExpression(this)
    Compiler_Consume(this, .RightParen, "Expected ')' after expression.")
}

@(private="file")
Compiler_CompileUnary :: proc(this: ^Compiler, canAssign: bool) {
    operatorType := this.parser.previous.type

    // Compile the operand
    Compiler_ParsePrecedence(this, .Unary)

    #partial switch operatorType {
    case .Bang: Compiler_EmitOp(this, .Not)
    case .Minus: Compiler_EmitOp(this, .Negate)
    case: fmt.fprintln(os.stderr, "[ERROR]", operatorType, "is not a unary operator"); panic("Exiting...")
    }
}

@(private="file")
Compiler_CompileBinary :: proc(this: ^Compiler, canAssign: bool) {
    operatorType := this.parser.previous.type
    rule := Compiler_GetRule(operatorType)
    Compiler_ParsePrecedence(this, Precedence(int(rule.precedence) + 1))

    #partial switch operatorType {
    case .BangEqual: Compiler_EmitOps(this, { .Equal, .Not })
    case .EqualEqual: Compiler_EmitOp(this, .Equal)
    case .Greater: Compiler_EmitOp(this, .Greater)
    case .GreaterEqual: Compiler_EmitOps(this, { .Less, .Not })
    case .Less: Compiler_EmitOp(this, .Less)
    case .LessEqual: Compiler_EmitOps(this, { .Greater, .Not })
    case .Plus: Compiler_EmitOp(this, .Add)
    case .Minus: Compiler_EmitOp(this, .Subtract)
    case .Star: Compiler_EmitOp(this, .Multiply)
    case .Slash: Compiler_EmitOp(this, .Divide)
    case: fmt.fprintln(os.stderr, "[ERROR]", operatorType, "is not a binary operator"); panic("Exiting...")
    }
}

@(private="file")
Compiler_CompileLiteral :: proc(this: ^Compiler, canAssign: bool) {
    #partial switch this.parser.previous.type {
    case .False: Compiler_EmitOp(this, .False)
    case .True: Compiler_EmitOp(this, .True)
    //    case .Nil: Compiler_EmitOp(this, .Nil)
    case: return
    }
}

@(private="file")
Compiler_CompileExpression :: proc(this: ^Compiler) {
    Compiler_ParsePrecedence(this, .Assignment)
}

@(private="file")
Compiler_CompileBlock :: proc(this: ^Compiler) {
    for !Compiler_CheckToken(this, .RightBrace) && !Compiler_CheckToken(this, .EOF) do Compiler_CompileDeclaration(this)
    Compiler_Consume(this, .RightBrace, "Expect '}' after block")
}

@(private="file")
Compiler_CompileVarDeclaration :: proc(this: ^Compiler) {
    global := Compiler_ParseVariable(this, "Expect variable name")

    if Compiler_MatchToken(this, .Equal) do Compiler_CompileExpression(this)
    else do Compiler_EmitOp(this, .Nil)

    Compiler_Consume(this, .Semicolon, "Expect ';' after variable declaration")
    Compiler_DefineVariable(this, global)
}

@(private="file")
Compiler_CompileDeclaration :: proc(this: ^Compiler) {
    if Compiler_MatchToken(this, .Var) do Compiler_CompileVarDeclaration(this)
    else do Compiler_CompileStatement(this)
    if (this.parser.panicMode) do Compiler_Synchronize(this)
}

@(private="file")
Compiler_CompileStatement :: proc(this: ^Compiler) {
    if Compiler_MatchToken(this, .Print) do Compiler_CompilePrintStatement(this)
    else if Compiler_MatchToken(this, .LeftBrace) {
        Compiler_BeginScope(this)
        Compiler_CompileBlock(this)
        Compiler_EndScope(this)
    } else do Compiler_CompileExpressionStatement(this)
}

@(private="file")
Compiler_CompileExpressionStatement :: proc(this: ^Compiler) {
    Compiler_CompileExpression(this)
    Compiler_Consume(this, .Semicolon, "Expect ';' after expression")
    Compiler_EmitOp(this, .Pop)
}

@(private="file")
Compiler_CompilePrintStatement :: proc(this: ^Compiler) {
    Compiler_CompileExpression(this)
    Compiler_Consume(this, .Semicolon, "Expect ';' after value.")
    Compiler_EmitOp(this, .Print)
}

// *************** Error handling ***************

@(private="file")
Compiler_Synchronize :: proc(this: ^Compiler) {
    this.parser.panicMode = false

    for this.parser.current.type != .EOF {
        if this.parser.previous.type == .Semicolon do return
        #partial switch this.parser.current.type {
        case .If, .Else, .For, .Defer, .Print, .Var, .Proc, .Struct, .Distinct, .Return: return
        case: {
        } // Do nothing otherwise
        }
    }
}

// *************** Bytecode generation helpers ***************

@(private="file")
Compiler_EmitByte :: proc(this: ^Compiler, byte: u8) {
    Chunk_Write(Compiler_CurrentChunk(this), byte, this.parser.previous.line)
}

@(private="file")
Compiler_EmitOp :: proc(this: ^Compiler, op: OpCode) {
    Chunk_WriteOp(Compiler_CurrentChunk(this), op, this.parser.previous.line)
}

@(private="file")
Compiler_EmitOps :: proc(this: ^Compiler, ops: []OpCode) {
    for op in ops {
        Compiler_EmitOp(this, op)
    }
}

@(private="file")
Compiler_EmitOpAndOperand :: proc(this: ^Compiler, op: OpCode, byte: u8) {
    Compiler_EmitOp(this, op)
    Compiler_EmitByte(this, byte)
}

@(private="file")
Compiler_EmitReturn :: proc(this: ^Compiler) {
    Compiler_EmitOp(this, .Return)
}

@(private="file")
Compiler_EmitConstant :: proc(this: ^Compiler, constant: u8) {
    Compiler_EmitOpAndOperand(this, .Constant, constant)
}