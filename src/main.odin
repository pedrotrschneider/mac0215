package yupii

import "core:fmt"
import os "core:os"

TEST_INPUT :: `
test :: proc() {
	print "this is from inside the proc"
}

main :: proc() {
    test()
}

test2 :: proc() {
    print "this is another test"
}

print main
`

//NativeProcedure :: proc(argCount: int, args: []Value)

main :: proc() {
//    test()
    run()
//    testRaylib()
}

@(private="file")
test :: proc() {
}

@(private="file")
run :: proc() {
    fmt.println("[DEBUG] Starting program...")
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