#+private
package main

import "yupii"

import "core:math"
import "core:fmt"
import "core:mem"
import c "core:c"
import "core:strings"
import rl "vendor:raylib"

NativeTest :: proc(argCount: int, args: []yupii.Value, allocator: mem.Allocator) -> yupii.Value {
    f := yupii.Value_AsF64(args[0]).value
    fmt.println("this is comming from the native function:", f)
    return yupii.Value_Bool(nil)
}

// ------------ BUILTIN BINDINGS ------------

BindingSqrt :: proc(argCount: int, args: []yupii.Value, allocator: mem.Allocator) -> yupii.Value {
    f := yupii.Value_AsF64(args[0]).value

    r := new(yupii.F64, allocator)
    r.value = f64(math.sqrt(f))
    return yupii.Value_F64(r)
}

BindingPrintLn :: proc(argCount: int, args: []yupii.Value, allocator: mem.Allocator) -> yupii.Value {
    s := yupii.Value_AsString(args[0]).value
    fmt.println(s)
    return yupii.Value_Bool(nil)
}

// ------------ RAYLIB BINDINGS ------------

RlInitWindow :: proc(argCount: int, args: []yupii.Value, allocator: mem.Allocator) -> yupii.Value {
    width := yupii.Value_AsF64(args[0]).value
    height := yupii.Value_AsF64(args[1]).value
    windowName := yupii.Value_AsString(args[2]).value
    fmt.println("window name is", windowName)

    cstringBuilder := strings.builder_make(allocator)
    strings.write_string(&cstringBuilder, windowName)
    cWindowName, _ := strings.to_cstring(&cstringBuilder)

    rl.InitWindow(c.int(width), c.int(height), cWindowName)
    return yupii.Value_Bool(nil)
}

RlCloseWindow :: proc(argCount: int, args: []yupii.Value, allocator: mem.Allocator) -> yupii.Value {
    rl.CloseWindow()
    return yupii.Value_Bool(nil)
}

RlWindowShouldClose :: proc(argCount: int, args: []yupii.Value, allocator: mem.Allocator) -> yupii.Value {
    b := new(yupii.Bool, allocator)
    b.value = rl.WindowShouldClose()
    return yupii.Value_Bool(b)
}

RlSetTargetFPS :: proc(argCount: int, args: []yupii.Value, allocator: mem.Allocator) -> yupii.Value {
    target := c.int(yupii.Value_AsF64(args[0]).value)
    rl.SetTargetFPS(target)

    b := new(yupii.Bool, allocator)
    b.value = rl.WindowShouldClose()
    return yupii.Value_Bool(b)
}

RlPollInputEvents :: proc(argCount: int, args: []yupii.Value, allocator: mem.Allocator) -> yupii.Value {
    rl.PollInputEvents()
    return yupii.Value_Bool(nil)
}

RlIsKeyPressed :: proc(argCount: int, args: []yupii.Value, allocator: mem.Allocator) -> yupii.Value {
    key := yupii.Value_AsF64(args[0]).value

    b := new(yupii.Bool, allocator)
    b.value = rl.IsKeyPressed(rl.KeyboardKey(key))
    return yupii.Value_Bool(b)
}

RlIsKeyDown :: proc(argCount: int, args: []yupii.Value, allocator: mem.Allocator) -> yupii.Value {
    key := yupii.Value_AsF64(args[0]).value

    b := new(yupii.Bool, allocator)
    b.value = rl.IsKeyDown(rl.KeyboardKey(key))
    return yupii.Value_Bool(b)
}

RlBeginDrawing :: proc(argCount: int, args: []yupii.Value, allocator: mem.Allocator) -> yupii.Value {
    rl.BeginDrawing()
    return yupii.Value_Bool(nil)
}

RlEndDrawing :: proc(argCount: int, args: []yupii.Value, allocator: mem.Allocator) -> yupii.Value {
    rl.EndDrawing()
    return yupii.Value_Bool(nil)
}

RlClearBackground :: proc(argCount: int, args: []yupii.Value, allocator: mem.Allocator) -> yupii.Value {
    r := u8(yupii.Value_AsF64(args[0]).value)
    g := u8(yupii.Value_AsF64(args[1]).value)
    b := u8(yupii.Value_AsF64(args[2]).value)
    a := u8(yupii.Value_AsF64(args[3]).value)

    rl.ClearBackground(rl.Color { r, g, b, a })
    return yupii.Value_Bool(nil)
}

RlDrawRectangle :: proc(argCount: int, args: []yupii.Value, allocator: mem.Allocator) -> yupii.Value {
    px := c.int(yupii.Value_AsF64(args[0]).value)
    py := c.int(yupii.Value_AsF64(args[1]).value)
    width := c.int(yupii.Value_AsF64(args[2]).value)
    height := c.int(yupii.Value_AsF64(args[3]).value)
    r := u8(yupii.Value_AsF64(args[4]).value)
    g := u8(yupii.Value_AsF64(args[5]).value)
    b := u8(yupii.Value_AsF64(args[6]).value)
    a := u8(yupii.Value_AsF64(args[7]).value)

    rl.DrawRectangle(px, py, width, height, rl.Color { r, g, b, a })
    return yupii.Value_Bool(nil)
}

RlDrawCircle :: proc(argCount: int, args: []yupii.Value, allocator: mem.Allocator) -> yupii.Value {
    px := c.int(yupii.Value_AsF64(args[0]).value)
    py := c.int(yupii.Value_AsF64(args[1]).value)
    radius := f32(yupii.Value_AsF64(args[2]).value)
    r := u8(yupii.Value_AsF64(args[3]).value)
    g := u8(yupii.Value_AsF64(args[4]).value)
    b := u8(yupii.Value_AsF64(args[5]).value)
    a := u8(yupii.Value_AsF64(args[6]).value)

    rl.DrawCircle(px, py, radius, rl.Color { r, g, b, a })
    return yupii.Value_Bool(nil)
}

RlDeltaTime :: proc(argCount: int, args: []yupii.Value, allocator: mem.Allocator) -> yupii.Value {
    dt := new(yupii.F64, allocator)
    dt.value = f64(rl.GetFrameTime())
    return yupii.Value_F64(dt)
}

RlKeyEscape :: proc(argCount: int, args: []yupii.Value, allocator: mem.Allocator) -> yupii.Value {
    k := new(yupii.F64, allocator)
    k.value = f64(int(rl.KeyboardKey.ESCAPE))
    return yupii.Value_F64(k)
}

RlKeyUp :: proc(argCount: int, args: []yupii.Value, allocator: mem.Allocator) -> yupii.Value {
    k := new(yupii.F64, allocator)
    k.value = f64(int(rl.KeyboardKey.UP))
    return yupii.Value_F64(k)
}

RlKeyDown :: proc(argCount: int, args: []yupii.Value, allocator: mem.Allocator) -> yupii.Value {
    k := new(yupii.F64, allocator)
    k.value = f64(int(rl.KeyboardKey.DOWN))
    return yupii.Value_F64(k)
}

RlKeyLeft :: proc(argCount: int, args: []yupii.Value, allocator: mem.Allocator) -> yupii.Value {
    k := new(yupii.F64, allocator)
    k.value = f64(int(rl.KeyboardKey.LEFT))
    return yupii.Value_F64(k)
}

RlKeyRight :: proc(argCount: int, args: []yupii.Value, allocator: mem.Allocator) -> yupii.Value {
    k := new(yupii.F64, allocator)
    k.value = f64(int(rl.KeyboardKey.RIGHT))
    return yupii.Value_F64(k)
}

RlKeyW :: proc(argCount: int, args: []yupii.Value, allocator: mem.Allocator) -> yupii.Value {
    k := new(yupii.F64, allocator)
    k.value = f64(int(rl.KeyboardKey.W))
    return yupii.Value_F64(k)
}

RlKeyA :: proc(argCount: int, args: []yupii.Value, allocator: mem.Allocator) -> yupii.Value {
    k := new(yupii.F64, allocator)
    k.value = f64(int(rl.KeyboardKey.A))
    return yupii.Value_F64(k)
}

RlKeyS :: proc(argCount: int, args: []yupii.Value, allocator: mem.Allocator) -> yupii.Value {
    k := new(yupii.F64, allocator)
    k.value = f64(int(rl.KeyboardKey.S))
    return yupii.Value_F64(k)
}

RlKeyD :: proc(argCount: int, args: []yupii.Value, allocator: mem.Allocator) -> yupii.Value {
    k := new(yupii.F64, allocator)
    k.value = f64(int(rl.KeyboardKey.D))
    return yupii.Value_F64(k)
}