package main

import "core:strconv"
import utf8 "core:unicode/utf8"
import fmt "core:fmt"
import os "core:os"

// *************** PUBLIC ***************

Compiler :: struct {
    compiling_chunk: ^Chunk,
    // TODO: The scanner will need to be cleaned up in the future
    scanner: Scanner,
    parser: Parser,
}

Compiler_Compile :: proc(this: ^Compiler, source: string, chunk: ^Chunk) -> bool {
    Scanner_Init(&this.scanner, source)
    Parser_Init(&this.parser)

    this.compiling_chunk = chunk

    Compiler_Advance(this)
    Compiler_CompileExpression(this)
    Compiler_Consume(this, .EOF, "Expected end of expression.")

    Compiler_End(this)

    return !this.parser.had_error
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
        error_message := utf8.runes_to_string(current.source[current.start:current.start + current.length])
        defer delete(error_message)
        Parser_ErrorAtCurrent(&this.parser, error_message)
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

    prefixRule(this)

    for precedence <= Compiler_GetRule(this.parser.current.type).precedence {
        Compiler_Advance(this)
        infix_rule := Compiler_GetRule(this.parser.previous.type).infix
        infix_rule(this)
    }
}

// *************** Utils ***************

@(private="file")
Compiler_CurrentChunk :: proc(this: ^Compiler) -> ^Chunk {
    return this.compiling_chunk
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
Compiler_End :: proc(this: ^Compiler) {
    Compiler_EmitReturn(this)
    when DEBUG_PRINT_CODE {
        if !this.parser.had_error do Chunk_Disassemble(Compiler_CurrentChunk(this), "Code")
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
ParseFn :: proc(this: ^Compiler)
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
    .Identifier = { nil, nil, .None },
    .String = { Compiler_CompileString, nil, .None },
    .Number = { Compiler_CompileNumber, nil, .None },
    .And = { nil, nil, .None },
    .Class = { nil, nil, .None },
    .Else = { nil, nil, .None },
    .False = { Compiler_CompileLiteral, nil, .None },
    .For = { nil, nil, .None },
    .Fun = { nil, nil, .None },
    .If = { nil, nil, .None },
    .Nil = { Compiler_CompileLiteral, nil, .None },
    .Or = { nil, nil, .None },
    .Print = { nil, nil, .None },
    .Return = { nil, nil, .None },
    .Super = { nil, nil, .None },
    .This = { nil, nil, .None },
    .True = { Compiler_CompileLiteral, nil, .None },
    .Var = { nil, nil, .None },
    .While = { nil, nil, .None },
    .Error = { nil, nil, .None },
    .EOF = { nil, nil, .None },
}

@(private="file")
Compiler_GetRule :: proc(type: TokenType) -> ^ParseRule {
    return &rules[type]
}

// *************** Expression compilation helpers ***************

@(private="file")
Compiler_CompileNumber :: proc(this: ^Compiler) {
    previous := this.parser.previous
    number_str := utf8.runes_to_string(previous.source[previous.start:previous.start + previous.length])
    defer delete(number_str)

    number, ok := strconv.parse_f64(number_str)
    if !ok {
        fmt.fprintln(os.stderr, "[ERROR] Unable to convert", number_str, "to number")
        panic("Exiting...")
    }
    value := Value_Number(number)
    Compiler_EmitConstant(this, Compiler_MakeConstant(this, value))
}

@(private="file")
Compiler_CompileString :: proc(this: ^Compiler) {
    start := this.parser.previous.start + 1
    end := start + this.parser.previous.length - 2
    stringObj := Obj_CopyRunesToObjString(this.parser.previous.source[start:end])
    constant := Compiler_MakeConstant(this, Value_Obj(stringObj))
    Compiler_EmitConstant(this, constant)
}

@(private="file")
Compiler_CompileGrouping :: proc(this: ^Compiler) {
    Compiler_CompileExpression(this)
    Compiler_Consume(this, .RightParen, "Expected ')' after expression.")
}

@(private="file")
Compiler_CompileUnary :: proc(this: ^Compiler) {
    operator_type := this.parser.previous.type

    // Compile the operand
    Compiler_ParsePrecedence(this, .Unary)

    #partial switch operator_type {
    case .Bang: Compiler_EmitOp(this, .Not)
    case .Minus: Compiler_EmitOp(this, .Negate)
    case: fmt.fprintln(os.stderr, "[ERROR]", operator_type, "is not a unary operator"); panic("Exiting...")
    }
}

@(private="file")
Compiler_CompileBinary :: proc(this: ^Compiler) {
    operator_type := this.parser.previous.type
    rule := Compiler_GetRule(operator_type)
    Compiler_ParsePrecedence(this, Precedence(int(rule.precedence) + 1))

    #partial switch operator_type {
    case .BangEqual: Compiler_EmitOps(this, .Equal, .Not)
    case .EqualEqual: Compiler_EmitOp(this, .Equal)
    case .Greater: Compiler_EmitOp(this, .Greater)
    case .GreaterEqual: Compiler_EmitOps(this, .Less, .Not)
    case .Less: Compiler_EmitOp(this, .Less)
    case .LessEqual: Compiler_EmitOps(this, .Greater, .Not)
    case .Plus: Compiler_EmitOp(this, .Add)
    case .Minus: Compiler_EmitOp(this, .Subtract)
    case .Star: Compiler_EmitOp(this, .Multiply)
    case .Slash: Compiler_EmitOp(this, .Divide)
    case: fmt.fprintln(os.stderr, "[ERROR]", operator_type, "is not a binary operator"); panic("Exiting...")
    }
}

@(private="file")
Compiler_CompileLiteral :: proc(this: ^Compiler) {
    #partial switch this.parser.previous.type {
    case .False: Compiler_EmitOp(this, .False)
    case .True: Compiler_EmitOp(this, .True)
    case .Nil: Compiler_EmitOp(this, .Nil)
    case: return
    }
}

@(private="file")
Compiler_CompileExpression :: proc(this: ^Compiler) {
    Compiler_ParsePrecedence(this, .Assignment)
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
Compiler_EmitOps :: proc(this: ^Compiler, ops: ..OpCode) {
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