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
    if a.length != b.length do return false
    return slice.equal(a.source.([]rune)[a.start:a.start+a.length], b.source.([]rune)[b.start:b.start+b.length])
}

peek :: proc(array: ^$T/[dynamic]$E, loc := #caller_location) -> (res: E) {
    assert(len(array) > 0, loc=loc)
    res = array[len(array)-1]
    return
}

peek_front :: proc(array: ^$T/[dynamic]$E, loc := #caller_location) -> (res: E) {
    assert(len(array) > 0, loc=loc)
    res = array[0]
    return
}