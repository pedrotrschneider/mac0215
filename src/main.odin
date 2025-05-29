package yupii

import "core:fmt"
import os "core:os"

main :: proc() {
    run()
}

@(private="file")
run :: proc() {
    fmt.println("[DEBUG] Starting program...")
    vm: VM
    VM_Init(&vm)
    defer VM_Free(&vm)

    args := os.args
    argc := len(args)

    settings: TranspilerSettings
    settings.packageName = "main"
    settings.importedPackages = {
        { "rl", "vendor:raylib" },
        { "", "core:math" },
        { "c", "core:c" },
        { "", "core:strings" },
        { "", "core:fmt" },
    }
    settings.bindingImplementations = {
        `sqrt :: proc(f: f64) -> f64 {
            return math.sqrt(f)
        }`,
        `println :: proc(s: string) {
            fmt.println(s)
        }`,
        `RlInitWindow :: proc(width, height: f64, windowName: string) {
            rl.InitWindow(c.int(width), c.int(height), strings.unsafe_string_to_cstring(windowName))
        }`,
        `RlCloseWindow :: proc() {
            rl.CloseWindow()
        }`,
        `RlWindowShouldClose :: proc() -> bool {
            return rl.WindowShouldClose()
        }`,
        `RlSetTargetFPS :: proc(target: f64) {
            rl.SetTargetFPS(c.int(target))
        }`,
        `RlPollInputEvents :: proc() {
            rl.PollInputEvents()
        }`,
        `RlIsKeyPressed :: proc(key: f64) -> bool {
            return rl.IsKeyPressed(rl.KeyboardKey(key))
        }`,
        `RlIsKeyDown :: proc(key: f64) -> bool {
            return rl.IsKeyDown(rl.KeyboardKey(key))
        }`,
        `RlBeginDrawing :: proc() {
            rl.BeginDrawing()
        }`,
        `RlEndDrawing :: proc() {
            rl.EndDrawing()
        }`,
        `RlClearBackground :: proc(r, g, b, a: f64) {
            rl.ClearBackground(rl.Color { u8(r), u8(g), u8(b), u8(a) })
        }`,
        `RlDrawRectangle :: proc(px, py, width, height, r, g, b, a: f64) {
            rl.DrawRectangle(c.int(px), c.int(py), c.int(width), c.int(height), rl.Color { u8(r), u8(g), u8(b), u8(a) })
        }`,
        `RlDrawCircle :: proc(px, py, radius, r, g, b, a: f64) {
            rl.DrawCircle(c.int(px), c.int(py), f32(radius), rl.Color { u8(r), u8(g), u8(b), u8(a) })
        }`,
        `RlDeltaTime :: proc() -> f64 {
            return f64(rl.GetFrameTime())
        }`,
        `RlKeyEscape :: proc() -> f64 {
            return f64(int(rl.KeyboardKey.ESCAPE))
        }`,
        `RlKeyUp :: proc() -> f64 {
            return f64(int(rl.KeyboardKey.UP))
        }`,
        `RlKeyDown :: proc() -> f64 {
            return f64(int(rl.KeyboardKey.DOWN))
        }`,
        `RlKeyW :: proc() -> f64 {
            return f64(int(rl.KeyboardKey.W))
        }`,
        `RlKeyS :: proc() -> f64 {
            return f64(int(rl.KeyboardKey.S))
        }`,
    }

    if argc == 1 {
        VM_REPL(&vm)
    } else if argc == 2 {
        VM_RunFile(&vm, args[1])
    } else if argc == 3 {
        VM_TranspileFile(&vm, settings, args[2])
    } else {
        panic("[ERROR] Usage: yupii {path_to_file}")
    }
}