package main

import "core:fmt"
import os "core:os"

Value :: distinct f64

Value_Print :: proc(value: Value) {
    fmt.printf("%.3g", value)
}

main :: proc() {
    fmt.println("Starting program...")
    vm: VM
    VM_Init(&vm)
    defer VM_Free(&vm)

    args := os.args
    argc := len(args)

    if argc == 1 {
        VM_REPL(&vm)
    } else if argc == 2 {
        VM_RunFile(&vm, args[1])
    } else {
        panic("[ERROR] Usage: yupii {path_to_file}")
    }
}