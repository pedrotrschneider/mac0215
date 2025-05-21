package yupii

import "core:fmt"
import "core:mem"

NativeTest :: proc(argCount: int, args: []Value, allocator: mem.Allocator) -> Value {
    f := Value_AsF64(args[1]).value
    fmt.println("this is comming from the native function:", f)

    b := new(Bool, allocator)
    b.value = true
    return Value_Bool(b)
}