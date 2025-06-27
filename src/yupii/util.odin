#+private
package yupii

import "core:mem"
import vmem "core:mem/virtual"
import slice "core:slice"
import fmt "core:fmt"
import os "core:os/os2"

IsDigit :: proc(r: rune) -> bool {
    return r >= '0' && r <= '9'
}

IsAlpha :: proc(r: rune) -> bool {
    return (r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z') || r == '_'
}

InitGrowingArenaAllocator :: proc(arena: ^vmem.Arena) -> (allocator: mem.Allocator, success: bool) {
    arenaError := vmem.arena_init_growing(arena)
    success = arenaError == nil
    allocator = vmem.arena_allocator(arena)
    return
}

IdentifiersEqual :: proc(a, b: ^Token) -> bool {
    sourceA, okA := Token_GetSource(a)
    if !okA do panic("Unable to get source from token a")
    sourceB, okB := Token_GetSource(b)
    if !okB do panic("Unable to get source from token b")

    if len(sourceA) != len(sourceB) do return false
    return slice.equal(sourceA, sourceB)
}

peek :: proc(array: ^$T/[dynamic]$E, distance: int = 0, loc := #caller_location) -> (res: E) {
    assert(len(array) > distance, loc=loc)
    res = array[len(array) - 1 - distance]
    return
}

peek_front :: proc(array: ^$T/[dynamic]$E, loc := #caller_location) -> (res: E) {
    assert(len(array) > 0, loc=loc)
    res = array[0]
    return
}

RunProcessSync :: proc(command: []string) -> (err: os.Error) {
    fmt.print("[DEBUG] Running command:")
    for c in command do fmt.print("", c)
    fmt.println()

    r, w := os.pipe() or_return
    defer os.close(r)
    defer os.close(w)
    p: os.Process
    {
        defer os.close(w)
        p = os.process_start({
            command = command,
            stdout = w,
        }) or_return
    }
    output := os.read_entire_file(r, context.temp_allocator) or_return
    state := os.process_wait(p) or_return

    if !state.exited {
        fmt.println("[DEBUG] Process did not exit yet")
        fmt.println(state)
        err = os.General_Error.Invalid_Command
    }

    if !state.success {
        fmt.println("[DEBUG] Process did not exit successfully")
        fmt.println(string(output))
        err = os.General_Error.Invalid_Command
    }

    return
}