package main

import "core:fmt"
import utf8 "core:unicode/utf8"
import slice "core:slice"

ValueType :: enum {
    Bool,
    Nil,
    Number,
    Obj,
}

Value :: struct {
    type: ValueType,
    as: union {
        bool,
        f64,
        ^Obj,
    },
}

// *************** Printers ***************

Value_Print :: proc(value: Value) {
    switch value.type {
    case .Bool: fmt.print(value.as.(bool) ? "true" : "false")
    case .Nil: fmt.print("nil")
    case .Number: fmt.printf("%g", value.as.(f64))
    case .Obj: {
        obj := Value_AsObj(value)
        switch obj.type {
        case .String: fmt.print(utf8.runes_to_string(Value_AsString(value).runes))
        }
    }
    }
}

Value_Println :: proc(value: Value) {
    Value_Print(value)
    fmt.println()
}

// *************** Constructors ***************

Value_Bool :: proc(boolean: bool) -> Value {
    return { .Bool, boolean }
}

Value_Nil :: proc() -> Value {
    return { .Nil, 0 }
}

Value_Number :: proc(number: f64) -> Value {
    return { .Number, number }
}

Value_Obj :: proc(obj: ^Obj) -> Value {
    return { .Obj, obj }
}

// *************** Getters ***************

Value_TryAsBool :: proc(value: Value) -> (bool, bool) {
    return value.as.(bool)
}

Value_AsBool :: proc(value: Value) -> bool {
    return value.as.(bool)
}

Value_TryAsNumber :: proc(value: Value) -> (f64, bool) {
    return value.as.(f64)
}

Value_AsNumber :: proc(value: Value) -> f64 {
    return value.as.(f64)
}

Value_TryAsObj :: proc(value: Value) -> (^Obj, bool) {
    return value.as.(^Obj)
}

Value_AsObj :: proc(value: Value) -> ^Obj {
    return value.as.(^Obj)
}

Value_TryObjType :: proc(value: Value) -> (ObjType, bool) {
    obj, ok := value.as.(^Obj)
    return ok ? obj.type : nil, ok
}

Value_ObjType :: proc(value: Value) -> ObjType {
    return value.as.(^Obj).type
}

Value_TryAsString :: proc(value: Value) -> (^ObjString, bool) {
    isString := Value_IsString(value)
    return isString ? Value_AsString(value) : nil, isString
}

Value_AsString :: proc(value: Value) -> ^ObjString {
    return (^ObjString)(value.as.(^Obj))
}

Value_TryAsRunes :: proc(value: Value) -> ([]rune, bool) {
    isString := Value_IsString(value)
    return isString ? Value_AsString(value).runes : nil, isString
}

Value_AsRunes :: proc(value: Value) -> []rune {
    return Value_AsString(value).runes
}

// *************** Checkers ***************

Value_IsBool :: proc(value: Value) -> bool {
    return value.type == .Bool
}

Value_IsNil :: proc(value: Value) -> bool {
    return value.type == .Nil
}

Value_IsNumber :: proc(value: Value) -> bool {
    return value.type == .Number
}

Value_IsObj :: proc(value: Value) -> bool {
    return value.type == .Obj
}

Value_IsObjType :: proc(value: Value, type: ObjType) -> bool {
    return Value_IsObj(value) && Value_AsObj(value).type == type
}

Value_IsString :: proc(value: Value) -> bool {
    return Value_IsObjType(value, .String)
}

Value_IsFalsey :: proc(value: Value) -> bool {
    isNil := Value_IsNil(value)
    boolValue, isBool := Value_TryAsBool(value)
    numberValue, isNumber := Value_TryAsNumber(value)
    return isNil || (isBool && !boolValue) || (isNumber && numberValue == 0)
}

// *************** Comparators ***************

Value_Equals :: proc(a, b: Value) -> bool {
    if a.type != b.type do return false
    switch a.type {
    case .Bool: return Value_AsBool(a) == Value_AsBool(b)
    case .Nil: return true // We checked that bot are the same type. Since both are nil, they are the same
    case .Number: return Value_AsNumber(a) == Value_AsNumber(b)
    case .Obj: {
        aObj := Value_AsObj(a)
        bObj := Value_AsObj(b)
        if aObj.type != bObj.type do return false
        switch aObj.type {
        case .String: {
            aObjString := Value_AsString(a)
            bObjString := Value_AsString(b)
            return len(aObjString.runes) == len(bObjString.runes) && slice.equal(aObjString.runes, bObjString.runes)
        }
        }
    }
    }
    return false
}