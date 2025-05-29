package main

import "yupii"
import "core:strings"
import "core:os"

main :: proc() {
    args := os.args
    argc := len(args)

    transpilerSettings: yupii.TranspilerSettings
    transpilerSettings.packageName = "main"
    transpilerSettings.importedPackages = {
        { alias = "rl", name = "vendor:raylib" },
        { alias = "", name = "core:math" },
        { alias = "c", name = "core:c" },
        { alias = "", name = "core:strings" },
        { alias = "", name = "core:fmt" },
    }

    transpilerSettings.bindingImplementations = {
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

    interpreterSettings: yupii.InterpreterSettings
    interpreterSettings.bindings = {
        { "sqrt", BindingSqrt },
        { "println", BindingPrintLn },

        { "NativeTest", NativeTest },
        { "RlInitWindow", RlInitWindow },
        { "RlCloseWindow", RlCloseWindow },
        { "RlWindowShouldClose", RlWindowShouldClose },
        { "RlSetTargetFPS", RlSetTargetFPS },
        { "RlPollInputEvents", RlPollInputEvents },
        { "RlIsKeyPressed", RlIsKeyPressed },
        { "RlIsKeyDown", RlIsKeyDown },
        { "RlBeginDrawing", RlBeginDrawing },
        { "RlEndDrawing", RlEndDrawing },
        { "RlClearBackground", RlClearBackground },
        { "RlDrawRectangle", RlDrawRectangle },
        { "RlDrawCircle", RlDrawCircle },
        { "RlDeltaTime", RlDeltaTime },

        { "RlKeyEscape", RlKeyEscape },
        { "RlKeyUp", RlKeyUp },
        { "RlKeyDown", RlKeyDown },
        { "RlKeyLeft", RlKeyLeft },
        { "RlKeyRight", RlKeyRight },
        { "RlKeyW", RlKeyW },
        { "RlKeyA", RlKeyA },
        { "RlKeyS", RlKeyS },
        { "RlKeyD", RlKeyD },
    }

    if argc == 1 {
        yupii.REPL({ })
    } else if argc == 3 && strings.compare(args[1], "-i") == 0 {
        yupii.InterpretFile(interpreterSettings, args[2])
    } else if argc == 4 && strings.compare(args[1], "-t") == 0 {
        yupii.TranspileFile(transpilerSettings, args[2], args[3])
    } else {
        panic("[ERROR] Usage: yupii { -t | -i } { path_to_file } { outFile | nil }")
    }
}