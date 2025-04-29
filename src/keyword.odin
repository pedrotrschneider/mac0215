package yupii

Keyword :: enum {
    If, Else, For, Defer,
    True, False, Nil,
    And, Or, Print,
    Proc, Struct, Distinct,
    Return,
}

KeywordData :: struct {
    tokenType: TokenType,
    runes: []rune,
}

keywords : [Keyword]KeywordData = {
    .If = { .If, { 'i', 'f' } },
    .Else = { .Else, { 'e', 'l', 's', 'e' } },
    .For = { .For, { 'f', 'o', 'r' } },
    .Defer = { .Defer, { 'd', 'e', 'f', 'e', 'r' } },
    .True = { .True, { 't', 'r', 'u', 'e' } },
    .False = { .False, { 'f', 'a', 'l', 's', 'e' } },
    .Nil = { .Nil, { 'n', 'i', 'l' } },
    .And = { .And, { 'a', 'n', 'd' } },
    .Or = { .Or, { 'o', 'r' } },
    .Print = { .Print, { 'p', 'r', 'i', 'n', 't' } },
    .Proc = { .Proc, { 'p', 'r', 'o', 'c' } },
    .Struct = { .Struct, { 's', 't', 'r', 'u', 'c', 't' } },
    .Distinct = { .Distinct, { 'd', 'i', 's', 't', 'i', 'n', 'c', 't' } },
    .Return = { .Return, { 'r', 'e', 't', 'u', 'r', 'n' } },
}