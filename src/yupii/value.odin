package yupii

import "core:fmt"
import "core:strings"
import slice "core:slice"
import "core:mem"

ValueType :: enum  {
    Bool,
    Int, // I8, I26, I32, I64,
    //    UInt, U8, U16, U32, U64,
    F64,
    //    F16, F32, F64,
    //    Complex32, Complex64, Complex128,
    //    Quaternion64, Quaternion128, Quaternion256,
    Rune,
    String,
    Procedure,
    NativeProcedure,
//    StaticArray,
//    DynamicArray,
//    Struct,
}

valueTypeRunes := [ValueType][]rune {
    .Bool = { 'b', 'o', 'o', 'l' },
    .Int = { 'i', 'n', 't' },
    .F64 = { 'f', '6', '4' },
    .Rune = { 'r', 'u', 'n', 'e' },
    .String = { 's', 't', 'r', 'i', 'n', 'g' },
    .Procedure = { 'p', 'r', 'o', 'c', 'e', 'd', 'u', 'r', 'e' },
    .NativeProcedure = { 'n', 'a', 't', 'i', 'v', 'e', 'p', 'r', 'o', 'c' },
}

Bool :: struct {
    value: bool,
}

Int :: struct {
    value: int,
}

F64 :: struct {
    value: f64,
}

String :: struct {
    value: string,
}

Rune :: struct {
    value: rune,
}

Procedure :: struct {
    name: string,
    arity: int,
    chunk: Chunk,
}

NativeProcedure :: proc(argCount: int, args: []Value, allocator: mem.Allocator) -> Value

Value :: struct {
    type: ValueType,
    as: union {
        ^Bool,
        ^Int,
        ^F64,
        ^String,
        ^Rune,
        ^Procedure,
        NativeProcedure,
    },
}

Value_GetValueType :: proc(name: []rune) -> (type: ValueType, success: bool) {
    switch name[0] {
    case 'b': return Value_CheckValueTypeKeyword(1, name, .Bool)
    case 'f': return Value_CheckValueTypeKeyword(1, name, .F64)
    case 'i': return Value_CheckValueTypeKeyword(1, name, .Int)
    case 'n': return Value_CheckValueTypeKeyword(1, name, .NativeProcedure)
    case 's': return Value_CheckValueTypeKeyword(1, name, .String)
    case 'r': return Value_CheckValueTypeKeyword(1, name, .Rune)
    case 'p': return Value_CheckValueTypeKeyword(1, name, .Procedure)
    }
    return .Bool, false
}

@(private="file")
Value_CheckValueTypeKeyword :: proc(start: int, runes: []rune, valueType: ValueType) -> (ValueType, bool) {
    typeRunes := valueTypeRunes[valueType]
    if len(runes) != len(typeRunes) do return valueType, false
    return valueType, slice.equal(runes[start:], typeRunes[start:])
}

// *************** Constructors ***************

Value_Bool :: proc(boolean: ^Bool) -> Value {
    return Value { .Bool, boolean }
}

Value_Int :: proc(integer: ^Int) -> Value {
    return Value { .Int, integer }
}

Value_F64 :: proc(float: ^F64) -> Value {
    return Value { .F64, float }
}

Value_String :: proc(str: ^String) -> Value {
    return Value { .String, str }
}

Value_Rune :: proc(r: ^Rune) -> Value {
    return Value { .Rune, r }
}

Value_Procedure :: proc(p: ^Procedure) -> Value {
    return Value { .Procedure, p }
}

Value_NativeProcedure :: proc(np: NativeProcedure) -> Value {
    return Value { .NativeProcedure, np }
}

// *************** Printers ***************

Value_Print :: proc(this: Value) {
    switch v in this.as {
    case ^Bool: {
        if v == nil do fmt.print("none")
        else do fmt.print(v.value ? "true" : "false")
    }
    case ^Int: fmt.print(v.value)
    case ^F64: fmt.printf("%g", v.value)
    case ^String: fmt.print(v.value)
    case ^Rune: fmt.print(v.value)
    case ^Procedure: fmt.print(v.name, ":: proc")
    case NativeProcedure: fmt.print("<native> :: proc")
    case: panic("Unrecognized value type")
    }
}

Value_Println :: proc(this: Value) {
    Value_Print(this)
    fmt.println()
}

// *************** Getters ***************

Value_TryAsBool :: proc(this: Value) -> (^Bool, bool) {
    return this.as.(^Bool)
}
Value_AsBool :: proc(this: Value) -> ^Bool {
    return this.as.(^Bool)
}

Value_TryAsInt :: proc(this: Value) -> (^Int, bool) {
    return this.as.(^Int)
}
Value_AsInt :: proc(this: Value) -> ^Int {
    return this.as.(^Int)
}

Value_TryAsF64 :: proc(this: Value) -> (^F64, bool) {
    return this.as.(^F64)
}
Value_AsF64 :: proc(this: Value) -> ^F64 {
    return this.as.(^F64)
}

Value_TryAsString :: proc(this: Value) -> (^String, bool) {
    return this.as.(^String)
}
Value_AsString :: proc(this: Value) -> ^String {
    return this.as.(^String)
}

Value_TryAsRune :: proc(this: Value) -> (^Rune, bool) {
    return this.as.(^Rune)
}
Value_AsRune :: proc(this: Value) -> ^Rune {
    return this.as.(^Rune)
}

Value_TryAsProcedure :: proc(this: Value) -> (^Procedure, bool) {
    return this.as.(^Procedure)
}
Value_AsProcedure :: proc(this: Value) -> ^Procedure {
    return this.as.(^Procedure)
}

Value_TryAsNativeProcedure :: proc(this: Value) -> (NativeProcedure, bool) {
    return this.as.(NativeProcedure)
}
Value_AsNativeProcedure :: proc(this: Value) -> NativeProcedure {
    return this.as.(NativeProcedure)
}

// *************** Checkers ***************

Value_IsBool :: proc(this: Value) -> bool {
    return this.type == .Bool
}

Value_IsInt :: proc(this: Value) -> bool {
    return this.type == .Int
}

Value_IsF64 :: proc(this: Value) -> bool {
    return this.type == .F64
}

Value_IsRune :: proc(this: Value) -> bool {
    return this.type == .Rune
}

Value_IsString :: proc(this: Value) -> bool {
    return this.type == .String
}

Value_IsProcedure :: proc(this: Value) -> bool {
    return this.type == .Procedure
}

Value_IsNativeProcedure :: proc(this: Value) -> bool {
    return this.type == .NativeProcedure
}

Value_IsFalsey :: proc(this: Value) -> bool {
    boolValue, isBool := Value_TryAsBool(this)
    intValue, isInt := Value_TryAsInt(this)
    return (isBool && !boolValue.value) || (isInt && intValue.value == 0)
}

// *************** Comparators ***************

Value_Equals :: proc(a, b: Value) -> bool {
    if a.type != b.type do return false
    switch a.type {
    case .Bool: return Value_AsBool(a).value == Value_AsBool(b).value
    case .Int: return Value_AsInt(a).value == Value_AsInt(b).value
    case .F64: return Value_AsF64(a).value == Value_AsF64(b).value
    case .String: return strings.compare(Value_AsString(a).value, Value_AsString(b).value) == 0
    case .Rune: return Value_AsRune(a).value == Value_AsRune(b).value
    case .Procedure: return false
    case .NativeProcedure: return false
    }
    return false
}