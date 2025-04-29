package yupii

import "core:fmt"
import utf8 "core:unicode/utf8"
import strconv "core:strconv"
import os "core:os"

// *************** PUBLIC ***************

Compiler :: struct {
    parser: Parser,
    compilingChunk: ^Chunk,
    scopeDepth: int,
}

Compiler_Init :: proc(this: ^Compiler) {
    Parser_Init(&this.parser)

    this.scopeDepth = 0
}

Compiler_Free :: proc(this: ^Compiler) {
    Parser_Free(&this.parser)
}

Compiler_Compile :: proc(this: ^Compiler, source: string, chunk: ^Chunk) -> bool {
    this.compilingChunk = chunk

    lexer: Lexer
    Lexer_Init(&lexer, source)
    defer Lexer_Free(&lexer)

    Lexer_PopulateParser(&lexer, &this.parser)
//    for &token in this.parser.tokens {
//        Token_Display(&token)
//        fmt.println()
//    }
//    fmt.println()

    for !Compiler_MatchToken(this, .EOF) {
        Compiler_CompileDeclaration(this)
    }

    Compiler_End(this)
    return !this.parser.hadError
}

Compiler_CurrentChunk :: proc(this: ^Compiler) -> ^Chunk {
    return this.compilingChunk
}

// *************** PRIVATE ***************

// *************** Core procedures ***************

@(private="file")
Compiler_Advance :: proc(this: ^Compiler) {
    Parser_Swap(&this.parser)

    for {
        Parser_Advance(&this.parser)
        current := Parser_Current(&this.parser)
        if current.type != .Error do break

        // Error handling
        errorMessage, ok := Token_GetErrorMessage(&current)
        if !ok do panic("Unable to get error message from error token")
        Parser_ErrorAtCurrent(&this.parser, errorMessage)
    }
}

@(private="file")
Compiler_Consume :: proc(this: ^Compiler, expected: TokenType, errorMessage: string) {
    if Parser_Current(&this.parser).type != expected do Parser_ErrorAtCurrent(&this.parser, errorMessage)
    Compiler_Advance(this)
}

@(private="file")
Compiler_ParsePrecedence :: proc(this: ^Compiler, precedence: Precedence) {
    Compiler_Advance(this)
    previousRule := Compiler_GetRule(Parser_Previous(&this.parser).type)
    if previousRule.prefix == nil {
        Parser_Error(&this.parser, "Expected expression")
        return
    }

    canAssign := precedence <= .Assignment
    previousRule.prefix(this, canAssign)

    for Compiler_GetRule(Parser_Current(&this.parser).type).precedence >= precedence {
        Compiler_Advance(this)
        previousRule = Compiler_GetRule(Parser_Previous(&this.parser).type)
        previousRule.infix(this, canAssign)
    }
}

@(private="file")
Compiler_MakeIdentifierConstant :: proc(this: ^Compiler, name: ^Token) -> Constant {
    nameRunes, ok := Token_GetSource(name)
    if !ok do panic("Unable to get runes from token")

    str := Chunk_AllocateStringFromRunes(Compiler_CurrentChunk(this), nameRunes)
    return Compiler_MakeConstant(this, Value_String(str))
}

@(private="file")
Compiler_ResolveLocal :: proc(this: ^Compiler, name: ^Token) -> (u8, bool) {
    local, depth, found := Chunk_ResolveLocal(Compiler_CurrentChunk(this), name)
    if !found do return 0, false
    // If local.depth == -1 this means the variable has been declared but not defined yet.
    // If that's the case, the user is likely trying to do something like this: a := a
    if depth == -1 do Parser_Error(&this.parser, "Can't read local variable in its own initializer")
    return local, found
}

@(private="file")
Compiler_AddLocal :: proc(this: ^Compiler, name: Token) {
    if Chunk_AddLocal(this.compilingChunk, name) > 255 {
        Parser_Error(&this.parser, "Too many local variables in scope")
    }
}

@(private="file")
Compiler_DeclareVariable :: proc(this: ^Compiler) {
    if this.scopeDepth == 0 do return // If it's a global variable, we do nothing

    name := Parser_Previous(&this.parser)
    if Chunk_HasLocal(this.compilingChunk, &name, this.scopeDepth) {
        Parser_Error(&this.parser, "A variable with this name already exists")
    }
    Compiler_AddLocal(this, name)
}

@(private="file")
Compiler_ParseVariable :: proc(this: ^Compiler, errorMessage: string) -> Constant {
    Compiler_Consume(this, .Identifier, errorMessage)
    Compiler_DeclareVariable(this)
    if this.scopeDepth > 0 do return 0
    previous := Parser_Previous(&this.parser)
    return Compiler_MakeIdentifierConstant(this, &previous)
}

@(private="file")
Compiler_MarkVariableInitialized :: proc(this: ^Compiler) {
    Chunk_MarkLocalInitialized(this.compilingChunk, this.scopeDepth)
}

@(private="file")
Compiler_DefineVariable :: proc(this: ^Compiler, index: u8) {
    if this.scopeDepth > 0 {
        Compiler_MarkVariableInitialized(this)
        return
    }
    Compiler_EmitOpAndOperand(this, .DefineGlobal, index)
}

// *************** Utils ***************

@(private="file")
Compiler_CurrentChunk :: proc(this: ^Compiler) -> ^Chunk {
    return this.compilingChunk
}

@(private="file")
Compiler_MakeConstant :: proc(this: ^Compiler, value: Value) -> Constant {
    constant := Chunk_AddConstant(Compiler_CurrentChunk(this), value)
    if constant > Constant(max(u8)) {
        Parser_Error(&this.parser, "Too many constants in one chunk")
        return Constant(0)
    }
    return Constant(constant)
}

@(private="file")
Compiler_MatchToken :: proc(this: ^Compiler, type: TokenType) -> bool {
    if !Compiler_CheckToken(this, type) do return false
    Compiler_Advance(this)
    return true
}

@(private="file")
Compiler_CheckTokens :: proc(this: ^Compiler, tokens: []TokenType) -> bool {
    if Parser_RemainingTokens(&this.parser) < len(tokens) do return false
    depth := 1
    for token in tokens{
        if Parser_Peek(&this.parser, depth).type != token do return false
        depth += 1
    }
    return true
}

@(private="file")
Compiler_CheckToken :: proc(this: ^Compiler, type: TokenType) -> bool {
    return Parser_Current(&this.parser).type == type
}

@(private="file")
Compiler_BeginScope :: proc(this: ^Compiler) {
    this.scopeDepth += 1
}

@(private="file")
Compiler_EndScope :: proc(this: ^Compiler) {
    this.scopeDepth -= 1
    count := Chunk_RemoveLocalsFromScope(Compiler_CurrentChunk(this), this.scopeDepth)
    for i := 0; i < count; i += 1 {
        Compiler_EmitOp(this, .Pop)
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
    .ColonColon = { nil, nil, .None },
    .Semicolon = { nil, nil, .None },
    .Slash = { nil, Compiler_CompileBinary, .Factor },
    .Star = { nil, Compiler_CompileBinary, .Factor },
    .Endl = { nil, nil, .None },
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
    .IntegerLiteral = { Compiler_CompileNumeric, nil, .None },
    .FloatLiteral = { Compiler_CompileNumeric, nil, .None },
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
Compiler_CompileExpression :: proc(this: ^Compiler) {
    Compiler_ParsePrecedence(this, .Assignment)
}

// *************** Literals ***************

@(private="file")
Compiler_CompileLiteral :: proc(this: ^Compiler, canAssign: bool) {
    #partial switch Parser_Previous(&this.parser).type {
    case .False: Compiler_EmitOp(this, .False)
    case .True: Compiler_EmitOp(this, .True)
    //    case .Nil: Compiler_EmitOp(this, .Nil)
    case: return
    }
}

@(private="file")
Compiler_CompileNumeric :: proc(this: ^Compiler, canAssign: bool) {
    previous := Parser_Previous(&this.parser)
    previousRunes, ok := Token_GetSource(&previous)
    if !ok do panic("Failed to get source from token")

    numberStr := utf8.runes_to_string(previousRunes)
    defer delete(numberStr)

    number, parseOk := strconv.parse_f64(numberStr)
    if !parseOk {
        fmt.fprintln(os.stderr, "[ERROR] Unable to convert", numberStr, "to number")
        panic("Exiting...")
    }
    literal := Chunk_AllocateF64(this.compilingChunk, number)
    value := Value_F64(literal)
    Compiler_EmitConstant(this, Compiler_MakeConstant(this, value))
}

@(private="file")
Compiler_CompileString :: proc(this: ^Compiler, canAssign: bool) {
    previous := Parser_Previous(&this.parser)
    previousRunes, ok := Token_GetSource(&previous)
    if !ok do panic("Failed to get source from token")
    // The range on the runes is to exclude quotation marks from the begining and the end
    str := Chunk_AllocateStringFromRunes(this.compilingChunk, previousRunes[1:len(previousRunes) - 2])
    constant := Compiler_MakeConstant(this, Value_String(str))
    Compiler_EmitConstant(this, constant)
}

@(private="file")
Compiler_CompileRune :: proc(this: ^Compiler, canAssign: bool) {
    previous := Parser_Previous(&this.parser)
    previousRunes, ok := Token_GetSource(&previous)
    if !ok do panic("Failed to get source from token")
    // The range on the runes is to exclude quotation marks from the begining and the end
    r := Chunk_AllocateRune(this.compilingChunk, previousRunes[1])
    constant := Compiler_MakeConstant(this, Value_Rune(r))
    Compiler_EmitConstant(this, constant)
}

@(private="file")
Compiler_CompileTypeIdentifier :: proc(this: ^Compiler) -> ValueType {
    current := Parser_Current(&this.parser)
    currentRunes, ok := Token_GetSource(&current)
    if !ok do panic("Unable to get runes from token")

    valueType, success := Value_GetValueType(currentRunes)
    if !success {
        Parser_Error(&this.parser, "Invalid type name")
    }
    Compiler_Consume(this, .Identifier, "Expected type identifier after variable declaration")
    return valueType
}

// *************** Variables ***************

@(private="file")
Compiler_CompileVariable :: proc(this: ^Compiler, canAssign: bool) {
    previous := Parser_Previous(&this.parser)
    Compiler_CompileNamedVariable(this, &previous, canAssign)
}

@(private="file")
Compiler_CompileNamedVariable :: proc(this: ^Compiler, name: ^Token, canAssign: bool) {
    getOp, setOp: OpCode
    arg, found := Compiler_ResolveLocal(this, name)
    if found {
        getOp = .GetLocal
        setOp = .SetLocal
    } else {
        arg = u8(Compiler_MakeIdentifierConstant(this, name))
        getOp = .GetGlobal
        setOp = .SetGlobal
    }

    if canAssign && Compiler_MatchToken(this, .Equal) {
        Compiler_CompileExpression(this)
        Compiler_EmitOpAndOperand(this, setOp, arg)
    } else do Compiler_EmitOpAndOperand(this, getOp, arg)

}

// *************** Operators ***************

@(private="file")
Compiler_CompileGrouping :: proc(this: ^Compiler, canAssign: bool) {
    Compiler_CompileExpression(this)
    Compiler_Consume(this, .RightParen, "Expected ')' after expression.")
}

@(private="file")
Compiler_CompileBlock :: proc(this: ^Compiler) {
    for !Compiler_CheckToken(this, .RightBrace) && !Compiler_CheckToken(this, .EOF) do Compiler_CompileDeclaration(this)
    Compiler_Consume(this, .RightBrace, "Expect '}' after block")
}

@(private="file")
Compiler_CompileUnary :: proc(this: ^Compiler, canAssign: bool) {
    operatorType := Parser_Previous(&this.parser).type

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
    operatorType := Parser_Previous(&this.parser).type
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

// *************** Declarations ***************

@(private="file")
Compiler_CompileDeclaration :: proc(this: ^Compiler) {
    if Compiler_MatchToken(this, .Endl) do return

    if Compiler_CheckTokens(this, { .Colon, .Identifier, .Equal }) do Compiler_CompileVarDeclaration(this)
    else do Compiler_CompileStatement(this)
    if (this.parser.panicMode) do Compiler_Synchronize(this)
}

@(private="file")
Compiler_CompileVarDeclaration :: proc(this: ^Compiler) {
    variable := Compiler_ParseVariable(this, "Expect variable name")

    Compiler_Consume(this, .Colon, "Expected ':' and type identifier after variable declaration")
    valueType := Compiler_CompileTypeIdentifier(this)
    if this.scopeDepth > 0 {
        Chunk_SetLocalType(Compiler_CurrentChunk(this), valueType)
    }

    if Compiler_MatchToken(this, .Equal) do Compiler_CompileExpression(this)
    else do Compiler_EmitOp(this, .Nil)

    Compiler_Consume(this, .Endl, "Expect endline after variable declaration")
    Compiler_DefineVariable(this, u8(variable))
}

// *************** Statements ***************

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
    Compiler_Consume(this, .Endl, "Expect endline after expression")
    Compiler_EmitOp(this, .Pop)
}

@(private="file")
Compiler_CompilePrintStatement :: proc(this: ^Compiler) {
    Compiler_CompileExpression(this)
    Compiler_Consume(this, .Endl, "Expect endline after value.")
    Compiler_EmitOp(this, .Print)
}

// *************** Error handling ***************

@(private="file")
Compiler_Synchronize :: proc(this: ^Compiler) {
    this.parser.panicMode = false

    for Parser_Current(&this.parser).type != .EOF {
        if Parser_Previous(&this.parser).type == .Semicolon do return
        #partial switch Parser_Current(&this.parser).type {
        case .If, .Else, .For, .Defer, .Print, .Proc, .Struct, .Distinct, .Return: return
        case: {
        } // Do nothing otherwise
        }
    }
}

// *************** Bytecode generation helpers ***************

@(private="file")
Compiler_EmitByte :: proc(this: ^Compiler, byte: u8) {
    Chunk_Write(Compiler_CurrentChunk(this), byte, Parser_Previous(&this.parser).line)
}

@(private="file")
Compiler_EmitOp :: proc(this: ^Compiler, op: OpCode) {
    Chunk_WriteOp(Compiler_CurrentChunk(this), op, Parser_Previous(&this.parser).line)
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
Compiler_EmitConstant :: proc(this: ^Compiler, constant: Constant) {
    Compiler_EmitOpAndOperand(this, .Constant, u8(constant))
}