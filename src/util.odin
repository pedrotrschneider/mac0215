package yupii

import "core:mem"
import vmem "core:mem/virtual"

IsDigit :: proc(r: rune) -> bool {
    return r >= '0' && r <= '9'
}

IsAlpha :: proc(r: rune) -> bool {
    return (r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z') || r == '_'
}

InitGrowingArenaAllocator :: proc(arena: ^vmem.Arena) -> (allocator: mem.Allocator, ok: bool) {
    arenaError := vmem.arena_init_growing(arena)
    ok = arenaError == nil
    allocator = vmem.arena_allocator(arena)
    return
}