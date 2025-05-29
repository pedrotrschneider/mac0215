package keyword_rune_generator

import "core:os"
import fmt "core:fmt"
import utf8 "core:unicode/utf8"
import strings "core:strings"

main :: proc() {
    buffer := make([]u8, 1024)
    defer delete(buffer)

    n, err := os.read(os.stdin, buffer[:])
    if err != nil {
        panic("Failed to read from stdin")
    }
    if n == 0 do return
    lines := strings.split(string(buffer[:n]), "\n")
    defer delete(lines)
    for line in lines {
        runes := utf8.string_to_runes(line)
        defer delete(runes)

        camelCase := strings.to_pascal_case(line)
        defer delete(camelCase)
        fmt.print(".", camelCase, " = { .", camelCase, ", { ", sep="")
        for rune, i in runes {
            fmt.print("\'", rune, "\'", sep="")
            if i == len(runes) - 1 do continue
            fmt.print(", ")
        }
        fmt.println(" } },")
    }
}