package main

import "core:fmt"
import os "core:os"
//import "core:mem"

TEST_INPUT :: "\"st\" + \"ri\" + \"ng\""

main :: proc() {
//    defaultAllocator := context.allocator
//    trackingAllocator: mem.Tracking_Allocator
//    mem.tracking_allocator_init(&trackingAllocator, defaultAllocator)
//    context.allocator = mem.tracking_allocator(&trackingAllocator)

//    test()
    run()

//    for _, value in trackingAllocator.allocation_map {
//        fmt.printfln("%v: Leaked %v bytes", value.location, value.size)
//    }
//    mem.tracking_allocator_clear(&trackingAllocator)
}

@(private="file")
test :: proc() {
    constants := make([dynamic]Value)
    defer delete(constants)
    fmt.println(len(constants))
    fmt.println(len(constants))
    objString := Obj_TakeRunesToObjString({ 's', 't' })
    valueString := Value_Obj(objString)
    valueNumber := Value_Number(100.5)
    fmt.println(valueNumber)
    fmt.println(valueString)
    append(&constants, valueNumber)
    fmt.println(constants)
    append(&constants, valueNumber)
    fmt.println(constants)
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