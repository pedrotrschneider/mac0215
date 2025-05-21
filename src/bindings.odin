package yupii

import "core:fmt"
import "core:mem"
import c "core:c"
import "core:strings"
import rl "vendor:raylib"

testRaylib :: proc() {
    rl.InitWindow(800, 800, "Hello World")

    for !rl.WindowShouldClose() {
        rl.PollInputEvents()
        if rl.IsKeyPressed(.ESCAPE) do break

        rl.ClearBackground(rl.RED)
        rl.BeginDrawing()
        rl.DrawRectangle(400, 400, 100, 100, rl.GREEN)
        rl.EndDrawing()
    }

    rl.CloseWindow()
}

NativeTest :: proc(argCount: int, args: []Value, allocator: mem.Allocator) -> Value {
    f := Value_AsF64(args[0]).value
    fmt.println("this is comming from the native function:", f)
    return Value_Bool(nil)
}

RlInitWindow :: proc(argCount: int, args: []Value, allocator: mem.Allocator) -> Value {
    width := Value_AsF64(args[0]).value
    height := Value_AsF64(args[1]).value
    windowName := Value_AsString(args[2]).value
    fmt.println("window name is", windowName)

    rl.InitWindow(c.int(width), c.int(height), strings.unsafe_string_to_cstring(windowName))
    return Value_Bool(nil)
}

RlCloseWindow :: proc(argCount: int, args: []Value, allocator: mem.Allocator) -> Value {
    rl.CloseWindow()
    return Value_Bool(nil)
}

RlWindowShouldClose :: proc(argCount: int, args: []Value, allocator: mem.Allocator) -> Value {
    b := new(Bool, allocator)
    b.value = rl.WindowShouldClose()
    return Value_Bool(b)
}

RlSetTargetFPS :: proc(argCount: int, args: []Value, allocator: mem.Allocator) -> Value {
    target := c.int(Value_AsF64(args[0]).value)
    rl.SetTargetFPS(target)

    b := new(Bool, allocator)
    b.value = rl.WindowShouldClose()
    return Value_Bool(b)
}

RlPollInputEvents :: proc(argCount: int, args: []Value, allocator: mem.Allocator) -> Value {
    rl.PollInputEvents()
    return Value_Bool(nil)
}

RlIsKeyPressed :: proc(argCount: int, args: []Value, allocator: mem.Allocator) -> Value {
    key := Value_AsF64(args[0]).value

    b := new(Bool, allocator)
    b.value = rl.IsKeyPressed(rl.KeyboardKey(key))
    return Value_Bool(b)
}

RlBeginDrawing :: proc(argCount: int, args: []Value, allocator: mem.Allocator) -> Value {
    rl.BeginDrawing()
    return Value_Bool(nil)
}

RlEndDrawing :: proc(argCount: int, args: []Value, allocator: mem.Allocator) -> Value {
    rl.EndDrawing()
    return Value_Bool(nil)
}

RlClearBackground :: proc(argCount: int, args: []Value, allocator: mem.Allocator) -> Value {
    r := u8(Value_AsF64(args[0]).value)
    g := u8(Value_AsF64(args[1]).value)
    b := u8(Value_AsF64(args[2]).value)
    a := u8(Value_AsF64(args[3]).value)

    rl.ClearBackground(rl.Color { r, g, b, a })
    return Value_Bool(nil)
}

RlDrawRectangle :: proc(argCount: int, args: []Value, allocator: mem.Allocator) -> Value {
    px := c.int(Value_AsF64(args[0]).value)
    py := c.int(Value_AsF64(args[1]).value)
    width := c.int(Value_AsF64(args[2]).value)
    height := c.int(Value_AsF64(args[3]).value)
    r := u8(Value_AsF64(args[4]).value)
    g := u8(Value_AsF64(args[5]).value)
    b := u8(Value_AsF64(args[6]).value)
    a := u8(Value_AsF64(args[7]).value)

    rl.DrawRectangle(px, py, width, height, rl.Color { r, g, b, a })
    return Value_Bool(nil)
}