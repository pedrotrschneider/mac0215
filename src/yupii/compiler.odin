#+private
package yupii

import "core:fmt"
import utf8 "core:unicode/utf8"
import strconv "core:strconv"
import "core:os"
import vmem "core:mem/virtual"
import "core:mem"

// *************** PUBLIC ***************

Compiler :: struct {
    currentProc: ^Procedure,
    procedures: map[string]Procedure,
    compilers: [dynamic]Compiler,
    isScript: bool,

    parser: ^Parser,
    scopeDepth: int,

    compilerArena: vmem.Arena,
    compilerAllocator: mem.Allocator,
}

Compiler_Init :: proc(this: ^Compiler, parser: ^Parser, isScript: bool) {
    this.parser = parser
    this.scopeDepth = 0

    ok: bool
    this.compilerAllocator, ok = InitGrowingArenaAllocator(&this.compilerArena)
    if !ok do panic("Unable to initialize compiler's arena allocator")

    this.procedures = make(map[string]Procedure, this.compilerAllocator)
    this.compilers = make([dynamic]Compiler, this.compilerAllocator)

    this.currentProc = new(Procedure, this.compilerAllocator)
    Procedure_Init(this.currentProc)

    Chunk_AddLocalEmpty(&this.currentProc.chunk)

    this.isScript = isScript
    if isScript do return
    previous := Parser_Previous(this.parser)
    source, _ := Token_GetSource(&previous)
    procName := utf8.runes_to_string(source, this.compilerAllocator)
    this.currentProc.name = procName
}

Compiler_Free :: proc(this: ^Compiler) {
    for procName in this.procedures {
        Procedure_Free(&this.procedures[procName])
    }

    for &compiler in this.compilers {
        Compiler_Free(&compiler)
    }

    vmem.arena_destroy(&this.compilerArena)
}

Compiler_Compile :: proc(this: ^Compiler, source: string) -> (bool, ^Procedure) {
    lexer: Lexer
    Lexer_Init(&lexer, source)
    defer Lexer_Free(&lexer)

    Lexer_PopulateParser(&lexer, this.parser, this.isScript)

    when DEBUG_PRINT_CODE {
        fmt.println("== Printing tokens ==")
        for &token in this.parser.tokens {
            Token_Display(&token)
            fmt.println()
        }
    }

    for !Compiler_MatchToken(this, .EOF) {
        Compiler_CompileDeclaration(this)
    }

    return !this.parser.hadError, Compiler_End(this)
}

Compiler_CurrentChunk :: proc(this: ^Compiler) -> ^Chunk {
    return &this.currentProc.chunk
}

// *************** PRIVATE ***************

// *************** Core procedures ***************

@(private="file")
Compiler_Advance :: proc(this: ^Compiler) {
    Parser_Swap(this.parser)

    for {
        Parser_Advance(this.parser)
        current := Parser_Current(this.parser)
        if current.type != .Error do break

        // Error handling
        errorMessage, ok := Token_GetErrorMessage(&current)
        if !ok do panic("Unable to get error message from error token")
        Parser_ErrorAtCurrent(this.parser, errorMessage)
    }
}

@(private="file")
Compiler_Consume :: proc(this: ^Compiler, expected: TokenType, errorMessage: string) {
    if Parser_Current(this.parser).type != expected do Parser_ErrorAtCurrent(this.parser, errorMessage)
    Compiler_Advance(this)
}

@(private="file")
Compiler_ConsumeOneOf :: proc(this: ^Compiler, expected: []TokenType, errorMessage: string) {
// Check if any of the provided token types math the current token
    for type in expected {
        if Parser_Current(this.parser).type == type {
            Compiler_Advance(this)
            return
        }
    }
    Parser_ErrorAtCurrent(this.parser, errorMessage)
}

@(private="file")
Compiler_ParsePrecedence :: proc(this: ^Compiler, precedence: Precedence) {
    Compiler_Advance(this)

    previousRule := Compiler_GetRule(Parser_Previous(this.parser).type)
    if previousRule.prefix == nil {
        Parser_Error(this.parser, "Expected expression")
        return
    }

    canAssign := precedence <= .Assignment
    previousRule.prefix(this, canAssign)

    for Compiler_GetRule(Parser_Current(this.parser).type).precedence >= precedence {
        Compiler_Advance(this)
        previousRule = Compiler_GetRule(Parser_Previous(this.parser).type)
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
    if depth == -1 do Parser_Error(this.parser, "Can't read local variable in its own initializer")
    return local, found
}

@(private="file")
Compiler_AddLocal :: proc(this: ^Compiler, name: Token) {
    if Chunk_AddLocal(Compiler_CurrentChunk(this), name) > 255 {
        Parser_Error(this.parser, "Too many local variables in scope")
    }
}

@(private="file")
Compiler_DeclareVariable :: proc(this: ^Compiler) {
    if this.scopeDepth == 0 do return // If it's a global variable, we do nothing

    name := Parser_Previous(this.parser)
    if Chunk_HasLocal(Compiler_CurrentChunk(this), &name, this.scopeDepth) {
        Parser_Error(this.parser, "A variable with this name already exists")
    }
    Compiler_AddLocal(this, name)
}

@(private="file")
Compiler_ParseVariable :: proc(this: ^Compiler, errorMessage: string) -> Constant {
    Compiler_Consume(this, .Identifier, errorMessage)
    Compiler_DeclareVariable(this)
    if this.scopeDepth > 0 do return 0
    previous := Parser_Previous(this.parser)
    return Compiler_MakeIdentifierConstant(this, &previous)
}

@(private="file")
Compiler_MarkVariableInitialized :: proc(this: ^Compiler) {
    if this.scopeDepth == 0 do return
    Chunk_MarkLocalInitialized(Compiler_CurrentChunk(this), this.scopeDepth)
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
    return &this.currentProc.chunk
}

@(private="file")
Compiler_MakeConstant :: proc(this: ^Compiler, value: Value) -> Constant {
    constant := Chunk_AddConstant(Compiler_CurrentChunk(this), value)
    if constant > Constant(max(u8)) {
        Parser_Error(this.parser, "Too many constants in one chunk")
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
    if Parser_RemainingTokens(this.parser) < len(tokens) do return false
    depth := 1
    for token in tokens {
        if Parser_Peek(this.parser, depth).type != token do return false
        depth += 1
    }
    return true
}

@(private="file")
Compiler_CheckToken :: proc(this: ^Compiler, type: TokenType) -> bool {
    return Parser_Current(this.parser).type == type
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
Compiler_End :: proc(this: ^Compiler) -> ^Procedure {
    Compiler_EmitReturn(this)
    procedure := this.currentProc
    when DEBUG_PRINT_CODE {
        if !this.parser.hadError do Chunk_Disassemble(Compiler_CurrentChunk(this), procedure.name)
    }
    return procedure
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
    .LeftParen = { Compiler_CompileGrouping, Compiler_CompileCall, .Call },
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
    .And = { nil, Compiler_CompileAnd, .And },
    .Else = { nil, nil, .None },
    .False = { Compiler_CompileLiteral, nil, .None },
    .For = { nil, nil, .None },
    .Defer = { nil, nil, .None },
    .If = { nil, nil, .None },
    .Nil = { Compiler_CompileLiteral, nil, .None },
    .Or = { nil, Compiler_CompileOr, .Or },
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

@(private="file")
Compiler_CompileExpressionStatement :: proc(this: ^Compiler) {
    Compiler_CompileExpression(this)
    Compiler_Consume(this, .Endl, "Expect endline after expression")
    Compiler_EmitOp(this, .Pop)
}

// *************** Literals ***************

@(private="file")
Compiler_CompileLiteral :: proc(this: ^Compiler, canAssign: bool) {
    #partial switch Parser_Previous(this.parser).type {
    case .False: Compiler_EmitOp(this, .False)
    case .True: Compiler_EmitOp(this, .True)
    //    case .Nil: Compiler_EmitOp(this, .Nil)
    case: return
    }
}

@(private="file")
Compiler_CompileNumeric :: proc(this: ^Compiler, canAssign: bool) {
    previous := Parser_Previous(this.parser)
    previousRunes, ok := Token_GetSource(&previous)
    if !ok do panic("Failed to get source from token")

    numberStr := utf8.runes_to_string(previousRunes)
    defer delete(numberStr)

    number, parseOk := strconv.parse_f64(numberStr)
    if !parseOk {
        fmt.fprintln(os.stderr, "[ERROR] Unable to convert", numberStr, "to number")
        panic("Exiting...")
    }
    literal := Chunk_AllocateF64(Compiler_CurrentChunk(this), number)
    value := Value_F64(literal)
    Compiler_EmitConstant(this, Compiler_MakeConstant(this, value))
}

@(private="file")
Compiler_CompileString :: proc(this: ^Compiler, canAssign: bool) {
    previous := Parser_Previous(this.parser)
    previousRunes, ok := Token_GetSource(&previous)
    if !ok do panic("Failed to get source from token")
    // The range on the runes is to exclude quotation marks from the begining and the end
    str := Chunk_AllocateStringFromRunes(Compiler_CurrentChunk(this), previousRunes[1:len(previousRunes) - 1])
    constant := Compiler_MakeConstant(this, Value_String(str))
    Compiler_EmitConstant(this, constant)
}

@(private="file")
Compiler_CompileRune :: proc(this: ^Compiler, canAssign: bool) {
    previous := Parser_Previous(this.parser)
    previousRunes, ok := Token_GetSource(&previous)
    if !ok do panic("Failed to get source from token")
    // The range on the runes is to exclude quotation marks from the begining and the end
    r := Chunk_AllocateRune(Compiler_CurrentChunk(this), previousRunes[1])
    constant := Compiler_MakeConstant(this, Value_Rune(r))
    Compiler_EmitConstant(this, constant)
}

@(private="file")
Compiler_CompileTypeIdentifier :: proc(this: ^Compiler) -> ValueType {
    current := Parser_Current(this.parser)
    currentRunes, ok := Token_GetSource(&current)
    if !ok do panic("Unable to get runes from token")

    valueType, success := Value_GetValueType(currentRunes)
    if !success {
        Parser_Error(this.parser, "Invalid type name")
    }
    Compiler_Consume(this, .Identifier, "Expected type identifier after variable declaration")
    return valueType
}

@(private="file")
Compiler_CompileProc :: proc(this: ^Compiler) {
    compiler: Compiler
    Compiler_Init(&compiler, this.parser, false)
    append(&this.compilers, compiler)
    Compiler_BeginScope(&compiler)

    Compiler_Consume(&compiler, .ColonColon, "Expect :: after procedure name")
    Compiler_Consume(&compiler, .Proc, "Expect proc keyword")
    Compiler_Consume(&compiler, .LeftParen, "Expect '(' after procedure name")
    if !Compiler_CheckToken(this, .RightParen) {
        for {
            compiler.currentProc.arity += 1
            if compiler.currentProc.arity > 255 do Parser_ErrorAtCurrent(compiler.parser, "Can't have more than 255 parameters")
            constant := Compiler_ParseVariable(&compiler, "expect parameter name")
            Compiler_Consume(&compiler, .Colon, "Expect ':' after parameter name")
            Compiler_Consume(&compiler, .Identifier, "Expect type identifier after parameter name")
            Compiler_DefineVariable(&compiler, u8(constant))

            if !Compiler_MatchToken(&compiler, .Comma) do break
        }
    }
    Compiler_Consume(&compiler, .RightParen, "Expect '(' after procedure declaration")
    Compiler_Consume(&compiler, .LeftBrace, "Expect '{' after procedure declaration")
    Compiler_CompileBlock(&compiler)

    procedure := Compiler_End(&compiler)
    constant := Compiler_MakeConstant(this, Value_Procedure(procedure))
    Compiler_EmitConstant(this, constant)
}

// *************** Variables ***************

@(private="file")
Compiler_CompileVariable :: proc(this: ^Compiler, canAssign: bool) {
    previous := Parser_Previous(this.parser)
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
    for !Compiler_CheckToken(this, .RightBrace) && !Compiler_CheckToken(this, .EOF) {
        Compiler_CompileDeclaration(this)
    }
    Compiler_Consume(this, .RightBrace, "Expect '}' after block")
}

@(private="file")
Compiler_CompileUnary :: proc(this: ^Compiler, canAssign: bool) {
    operatorType := Parser_Previous(this.parser).type

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
    operatorType := Parser_Previous(this.parser).type
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
Compiler_CompileArgumentList :: proc(this: ^Compiler) -> u8 {
    argCount := u8(0)
    if !Compiler_CheckToken(this, .RightParen) {
        for {
            Compiler_CompileExpression(this)
            argCount += 1
            if argCount == 255 do Parser_Error(this.parser, "Can't have more than 255 arguments")
            if !Compiler_MatchToken(this, .Comma) do break
        }
    }
    Compiler_Consume(this, .RightParen, "Expect ')' after arguments")
    return argCount
}

@(private="file")
Compiler_CompileCall :: proc(this: ^Compiler, canAssign: bool) {
    argCount := Compiler_CompileArgumentList(this)
    Compiler_EmitOpAndOperand(this, .Call, argCount)
}

@(private="file")
Compiler_CompileAnd :: proc(this: ^Compiler, canAssign: bool) {
    endJump := Compiler_EmitJump(this, .JumpIfFalse)
    Compiler_EmitOp(this, .Pop)
    Compiler_ParsePrecedence(this, .And)
    Compiler_PatchJump(this, endJump)
}

@(private="file")
Compiler_CompileOr :: proc(this: ^Compiler, canAssign: bool) {
    elseJump := Compiler_EmitJump(this, .JumpIfFalse)
    endJump := Compiler_EmitJump(this, .Jump)

    Compiler_PatchJump(this, elseJump)
    Compiler_EmitOp(this, .Pop)

    Compiler_ParsePrecedence(this, .Or)
    Compiler_PatchJump(this, endJump)
}

// *************** Declarations ***************

@(private="file")
Compiler_CompileDeclaration :: proc(this: ^Compiler) {
    if Compiler_MatchToken(this, .Endl) do return

    if Compiler_CheckTokens(this, { .Colon, .Identifier, .Equal }) do Compiler_CompileVarDeclaration(this)
    else if Compiler_CheckTokens(this, { .ColonColon, .Proc }) do Compiler_CompileProcDeclaration(this)
    else do Compiler_CompileStatement(this)
    if (this.parser.panicMode) do Compiler_Synchronize(this)
}

@(private="file")
Compiler_CompileVarDeclaration :: proc(this: ^Compiler) {
    variable := Compiler_ParseVariable(this, "Expect variable name")

    Compiler_Consume(this, .Colon, "Expected ':' and type identifier after variable declaration")
    valueType := Compiler_CompileTypeIdentifier(this)

    // Todo: this breaks with bool. Fix it
    //    if !Compiler_CheckToken(this, Token_TypeFromValueType(valueType)) {
    //        Parser_Error(this.parser, "Type mismatch in variable declaration")
    //    }
    if this.scopeDepth > 0 {
        Chunk_SetLocalType(Compiler_CurrentChunk(this), valueType)
    }

    if Compiler_MatchToken(this, .Equal) do Compiler_CompileExpression(this)
    else do Compiler_EmitOp(this, .Nil)

    Compiler_ConsumeOneOf(this, { .Endl, .Semicolon }, "Expect endline or ';' after variable declaration")
    Compiler_DefineVariable(this, u8(variable))
}

@(private="file")
Compiler_CompileProcDeclaration :: proc(this: ^Compiler) {
    global := Compiler_ParseVariable(this, "Expect function name")
    Compiler_MarkVariableInitialized(this)

    Compiler_CompileProc(this)

    Compiler_DefineVariable(this, u8(global))
}

// *************** Statements ***************

@(private="file")
Compiler_CompileStatement :: proc(this: ^Compiler) {
    if Compiler_MatchToken(this, .Print) do Compiler_CompilePrintStatement(this)
    else if Compiler_MatchToken(this, .Return) do Compiler_CompileReturnStatement(this)
    else if Compiler_MatchToken(this, .If) do Compiler_CompileIfStatement(this)
    else if Compiler_MatchToken(this, .For) do Compiler_CompileForStatement2(this)
    else if Compiler_MatchToken(this, .LeftBrace) {
        Compiler_BeginScope(this)
        Compiler_CompileBlock(this)
        Compiler_EndScope(this)
    } else do Compiler_CompileExpressionStatement(this)
}

@(private="file")
Compiler_CompilePrintStatement :: proc(this: ^Compiler) {
    Compiler_CompileExpression(this)
    Compiler_Consume(this, .Endl, "Expect endline after value.")
    Compiler_EmitOp(this, .Print)
}

@(private="file")
Compiler_CompileReturnStatement :: proc(this: ^Compiler) {
    if this.scopeDepth == 0 do Parser_Error(this.parser, "Can't return out of top-level code")

    if Compiler_MatchToken(this, .Endl) {
        Compiler_EmitReturn(this)
        return
    }

    Compiler_CompileExpression(this)
    Compiler_Consume(this, .Endl, "Expect endline after return value.")
    Compiler_EmitOp(this, .Return)

}

@(private="file")
Compiler_CompileIfStatement :: proc(this: ^Compiler) {
    Compiler_CompileExpression(this)

    thenJump := Compiler_EmitJump(this, .JumpIfFalse)
    Compiler_EmitOp(this, .Pop)
    Compiler_CompileStatement(this)
    elseJump := Compiler_EmitJump(this, .Jump)

    Compiler_PatchJump(this, thenJump)
    Compiler_EmitOp(this, .Pop)

    if Compiler_MatchToken(this, .Else) do Compiler_CompileStatement(this)
    Compiler_PatchJump(this, elseJump)
}

@(private="file")
Compiler_CompileForStatement :: proc(this: ^Compiler) {
    loopStart := len(Compiler_CurrentChunk(this).code)
    Compiler_CompileExpression(this)

    exitJump := Compiler_EmitJump(this, .JumpIfFalse)
    Compiler_EmitOp(this, .Pop)
    Compiler_CompileStatement(this)
    Compiler_EmitLoop(this, u8(loopStart))

    Compiler_PatchJump(this, exitJump)
    Compiler_EmitOp(this, .Pop)
}

@(private="file")
Compiler_CompileForStatement2 :: proc(this: ^Compiler) {
// We begin the scope here to make it so variables created in the
// initializer can only be present in the loop's body
    Compiler_BeginScope(this)

    // Compiling the intializer clause
    if Compiler_MatchToken(this, .Semicolon) {
    // No initializer
    } else if Compiler_CheckTokens(this, { .Colon, .Identifier, .Equal }) {
    // Variable initialization
        Compiler_CompileVarDeclaration(this)
    } else {
    // Simple expression
        Compiler_CompileExpressionStatement(this)
    }

    loopStart := len(Compiler_CurrentChunk(this).code)

    // Compiling condition clause
    exitJump := -1
    if !Compiler_MatchToken(this, .Semicolon) {
        Compiler_CompileExpression(this)
        Compiler_Consume(this, .Semicolon, "Expect ';' after loop condition")

        // Jump out of the loop if the condition is false
        exitJump = Compiler_EmitJump(this, .JumpIfFalse)
        Compiler_EmitOp(this, .Pop)
    }

    if !Compiler_CheckToken(this, .LeftBrace) {
        bodyJump := Compiler_EmitJump(this, .Jump)
        incrementStart := len(Compiler_CurrentChunk(this).code)

        Compiler_CompileExpression(this)
        Compiler_EmitOp(this, .Pop)

        Compiler_EmitLoop(this, u8(loopStart))
        loopStart = incrementStart
        Compiler_PatchJump(this, bodyJump)
    }

    Compiler_CompileStatement(this)

    Compiler_EmitLoop(this, u8(loopStart))

    if exitJump != -1 {
        Compiler_PatchJump(this, exitJump)
        Compiler_EmitOp(this, .Pop)
    }

    Compiler_EndScope(this)
}

// *************** Error handling ***************

@(private="file")
Compiler_Synchronize :: proc(this: ^Compiler) {
    this.parser.panicMode = false

    for Parser_Current(this.parser).type != .EOF {
        if Parser_Previous(this.parser).type == .Semicolon do return
        #partial switch Parser_Current(this.parser).type {
        case .If, .Else, .For, .Defer, .Print, .Proc, .Struct, .Distinct, .Return: return
        case: {
        } // Do nothing otherwise
        }
    }
}

// *************** Bytecode generation helpers ***************

@(private="file")
Compiler_EmitByte :: proc(this: ^Compiler, byte: u8) {
    Chunk_Write(Compiler_CurrentChunk(this), byte, Parser_Previous(this.parser).line)
}

@(private="file")
Compiler_EmitOp :: proc(this: ^Compiler, op: OpCode) {
    Chunk_WriteOp(Compiler_CurrentChunk(this), op, Parser_Previous(this.parser).line)
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

@(private="file")
Compiler_EmitJump :: proc(this: ^Compiler, op: OpCode) -> int {
    Compiler_EmitOp(this, op)
    Compiler_EmitByte(this, 0xff)
    Compiler_EmitByte(this, 0xff)
    return len(Compiler_CurrentChunk(this).code) - 2
}

@(private="file")
Compiler_PatchJump :: proc(this: ^Compiler, offset: int) {
// -2 to adjust for the bytecode for the jump offset itself
    jump := len(Compiler_CurrentChunk(this).code) - offset - 2

    if u16(jump) > max(u16) do Parser_Error(this.parser, "Too much code to jump over")

    Compiler_CurrentChunk(this).code[offset + 0] = u8((jump >> 8) & 0xff)
    Compiler_CurrentChunk(this).code[offset + 1] = u8(jump & 0xff)
}

@(private="file")
Compiler_EmitLoop :: proc(this: ^Compiler, loopStart: u8) {
    Compiler_EmitOp(this, .Loop)

    offset := u8(len(Compiler_CurrentChunk(this).code)) - loopStart + 2
    if u16(offset) > max(u16) do Parser_Error(this.parser, "Loop body too large")

    Compiler_EmitByte(this, (offset >> 8) & 0xff)
    Compiler_EmitByte(this, offset & 0xff)
}