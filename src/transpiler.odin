package yupii

import "core:strings"
import "core:mem"
import vmem "core:mem/virtual"
import utf8 "core:unicode/utf8"
import os "core:os"

TranspileResult :: enum {
    Ok,
    TranspileError,
}

TranspilerSettings :: struct {
    packageName: string,
    importedPackages: []struct{
        alias: string,
        name: string,
    },
    bindingImplementations: []string,
}

Transpiler :: struct {
    settings: TranspilerSettings,
    transpilerArena: vmem.Arena,
    transpilerAllocator: mem.Allocator,
}

Transpiler_Init :: proc(this: ^Transpiler, settings: TranspilerSettings) {
    this.settings = settings

    transpilerArenaOk: bool
    this.transpilerAllocator, transpilerArenaOk = InitGrowingArenaAllocator(&this.transpilerArena)
    if !transpilerArenaOk do panic("Unable to initialize transpiler's arena")
}

Transpiler_Free :: proc(this: ^Transpiler) {
    vmem.arena_destroy(&this.transpilerArena)
}

Transpiler_Transpiler :: proc(this: ^Transpiler, source: string) -> TranspileResult {
    parser: Parser
    Parser_Init(&parser)
    defer Parser_Free(&parser)

    lexer: Lexer
    Lexer_Init(&lexer, source)
    defer Lexer_Free(&lexer)

    Lexer_PopulateParser(&lexer, &parser)

    transpiled_builder := strings.builder_make(this.transpilerAllocator)

    strings.write_string(&transpiled_builder, "package ")
    strings.write_string(&transpiled_builder, this.settings.packageName)
    strings.write_rune(&transpiled_builder, '\n')
    strings.write_rune(&transpiled_builder, '\n')

    for importedPackage in this.settings.importedPackages {
        strings.write_string(&transpiled_builder, "import ")
        strings.write_string(&transpiled_builder, importedPackage.alias)
        strings.write_rune(&transpiled_builder, ' ')
        strings.write_quoted_string(&transpiled_builder, importedPackage.name)
        strings.write_rune(&transpiled_builder, '\n')
    }
    strings.write_rune(&transpiled_builder, '\n')


    for bindingImplementation in this.settings.bindingImplementations {
        strings.write_string(&transpiled_builder, bindingImplementation)
        strings.write_rune(&transpiled_builder, '\n')
        strings.write_rune(&transpiled_builder, '\n')
    }

    for token in parser.tokens {
        switch token.type {
        case .LeftParen: strings.write_rune(&transpiled_builder, '(')
        case .RightParen: strings.write_rune(&transpiled_builder, ')')
        case .LeftBrace: strings.write_rune(&transpiled_builder, '{')
        case .RightBrace: strings.write_rune(&transpiled_builder, '}')
        case .Comma: strings.write_string(&transpiled_builder, ", ")
        case .Dot: strings.write_rune(&transpiled_builder, '.')
        case .Minus: strings.write_rune(&transpiled_builder, '-')
        case .Plus: strings.write_rune(&transpiled_builder, '+')
        case .Colon: strings.write_rune(&transpiled_builder, ':')
        case .ColonColon: strings.write_string(&transpiled_builder, "::")
        case .Semicolon: strings.write_rune(&transpiled_builder, ';')
        case .Slash: strings.write_rune(&transpiled_builder, '/')
        case .Star: strings.write_rune(&transpiled_builder, '*')
        case .Endl: strings.write_rune(&transpiled_builder, '\n')
        case .Bang: strings.write_rune(&transpiled_builder, '!')
        case .BangEqual: strings.write_string(&transpiled_builder, "!=")
        case .Equal: strings.write_rune(&transpiled_builder, '=')
        case .EqualEqual: strings.write_string(&transpiled_builder, "==")
        case .Greater: strings.write_rune(&transpiled_builder, '>')
        case .GreaterEqual: strings.write_string(&transpiled_builder, ">=")
        case .Less: strings.write_rune(&transpiled_builder, '<')
        case .LessEqual: strings.write_string(&transpiled_builder, "<=")
        case .ArrowRight: strings.write_string(&transpiled_builder, "->")
        case .Identifier, .IntegerLiteral, .FloatLiteral, .RuneLiteral, .StringLiteral: {
            strings.write_string(&transpiled_builder, utf8.runes_to_string(token.source.([]rune)))
        }
        case .If: strings.write_string(&transpiled_builder, "if ")
        case .Else: strings.write_string(&transpiled_builder, "else ")
        case .For: strings.write_string(&transpiled_builder, "for ")
        case .Defer: strings.write_string(&transpiled_builder, "defer ")
        case .True: strings.write_string(&transpiled_builder, "true")
        case .False: strings.write_string(&transpiled_builder, "false")
        case .Nil: strings.write_string(&transpiled_builder, "nil")
        case .And: strings.write_string(&transpiled_builder, "&&")
        case .Or: strings.write_string(&transpiled_builder, "||")
        case .Print: strings.write_string(&transpiled_builder, "")
        case .Proc: strings.write_string(&transpiled_builder, "proc")
        case .Struct: strings.write_string(&transpiled_builder, "struct")
        case .Distinct: strings.write_string(&transpiled_builder, "distinct")
        case .Return: strings.write_string(&transpiled_builder, "return")
        case .EOF: break
        case .Error: return .TranspileError
        }
    }

    transpiled_string := strings.to_string(transpiled_builder)
    os.write_entire_file("test.odin", transmute([]byte)(transpiled_string))
    return .Ok
}