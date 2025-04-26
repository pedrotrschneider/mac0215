package main

ObjType :: enum {
    String,
}

Obj :: struct {
    type: ObjType,
    next: ^Obj,
}

ObjString :: struct {
    using obj: Obj,
    runes: []rune,
}

Obj_AllocateObj :: proc($T: typeid, objType: ObjType) -> ^T {
    obj := new(T)
    obj.type = objType
    return obj
}

Obj_AllocateObjString :: proc(runes: []rune) -> ^ObjString {
    newString := (Obj_AllocateObj(ObjString, .String))
    newString.runes = runes
    return newString
}

Obj_CopyRunesToObjString :: proc(runes: []rune) -> ^ObjString {
    runesCopy := make([]rune, len(runes))
    copy(runesCopy, runes)
    return Obj_AllocateObjString(runesCopy)
}

Obj_TakeRunesToObjString :: proc(runes: []rune) -> ^ObjString {
    return Obj_AllocateObjString(runes)
}

Obj_Free :: proc(obj: ^Obj) {
    switch obj.type {
    case .String: {
        objString := (^ObjString)(obj)
        delete(objString.runes)
        delete(obj)
    }
    }
}