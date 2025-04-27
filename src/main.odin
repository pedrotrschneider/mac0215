package yupii

import "core:fmt"
import os "core:os"
//import "core:mem"

TEST_INPUT :: "1 + 2"

main :: proc() {
//    test()
    run()
}

testagain :: proc() -> ^int {
    testvalue := new(int)
    testvalue^ = 10
    return testvalue
}

@(private="file")
test :: proc() {
    dir := os.get_current_directory()
    fmt.println(dir)
    delete(dir)
}

@(private="file")
run :: proc() {
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