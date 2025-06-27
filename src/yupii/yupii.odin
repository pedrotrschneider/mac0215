package yupii

import os "core:os/os2"
import "core:strings"
import "core:fmt"
import "core:dynlib"

InterpreterSettings :: struct {
    bindings: []struct{
        name: string,
        nativeProc: NativeProcedure,
    },
}

TranspilerSettings :: struct {
    packageName: string,
    importedPackages: []struct{
        alias: string,
        name: string,
    },
    bindingImplementations: []string,
}

TranspileFileAndRun :: proc(settings: TranspilerSettings, file: string) {
    TranspileFile(settings, file, "/tmp/tmp.odin")
    err := RunProcessSync({ "odin", "build", "/tmp/tmp.odin", "-file", "-build-mode:dll", "-out=/tmp/tmp.so" })
    if err != os.ERROR_NONE {
        fmt.println("Unable to run command")
        panic("Aborting...")
    }

    _, loaded := dynlib.load_library("/tmp/tmp.so")
    if !loaded {
        dlLoadError := dynlib.last_error()
        fmt.println("Failed to load tmp.so dynamic library")
        fmt.println(dlLoadError)
        panic("Aborting...")
    }
}

InterpretFile :: proc(settings: InterpreterSettings, file: string) {
    vm: VM
    VM_Init(&vm)
    defer VM_Free(&vm)

    VM_RunFile(&vm, settings, file)
}

TranspileFile :: proc(settings: TranspilerSettings, file, outFile: string) {
    vm: VM
    VM_Init(&vm)
    defer VM_Free(&vm)

    VM_TranspileFile(&vm, settings, file, outFile)
}

REPL :: proc(settings: InterpreterSettings) {
    vm: VM
    VM_Init(&vm)
    defer VM_Free(&vm)

    VM_REPL(&vm, settings)
}

CLI :: proc() {
    args := os.args
    argc := len(args)

    if argc == 1 {
        REPL({ })
    } else if argc == 3 && strings.compare(args[1], "-i") == 0 {
        InterpretFile(InterpreterSettings { }, args[2])
    } else if argc == 4 && strings.compare(args[1], "-t") == 0 {
        TranspileFile(TranspilerSettings{ }, args[2], args[3])
    } else {
        panic("[ERROR] Usage: yupii { -t | -i } { path_to_file } { outFile | nil }")
    }
}

YUPII_CLI :: #config(YUPII_CLI, false)
when YUPII_CLI {
    main :: proc() {
        CLI()
    }
}

