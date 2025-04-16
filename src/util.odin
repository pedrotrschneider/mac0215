package main

IsDigit :: proc(r: rune) -> bool {
    return r >= '0' && r <= '9'
}

IsAlpha :: proc(r: rune) -> bool {
    return (r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z') || r == '_'
}