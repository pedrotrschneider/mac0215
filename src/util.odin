package yupii

import "core:mem"
import vmem "core:mem/virtual"
import slice "core:slice"

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

peek :: proc(array: ^$T/[dynamic]$E, loc := #caller_location) -> (res: E) {
    assert(len(array) > 0, loc=loc)
    res = array[len(array) - 1]
    return
}

peek_front :: proc(array: ^$T/[dynamic]$E, loc := #caller_location) -> (res: E) {
    assert(len(array) > 0, loc=loc)
    res = array[0]
    return
}