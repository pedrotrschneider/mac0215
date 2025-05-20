package yupii

Procedure_Init :: proc(this: ^Procedure) {
    this.arity = 0
    this.name = "<script>"
    Chunk_Init(&this.chunk)
}

Procedure_Free :: proc(this: ^Procedure) {
    Chunk_Free(&this.chunk)
}