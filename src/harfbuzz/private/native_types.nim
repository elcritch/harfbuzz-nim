## Preserve the C typedefs when native static builds use stricter compilers.
import std/[macros, os]

const hbNativeHeader* = currentSourcePath().parentDir / "native_static.h"

macro hbNativeType*(header: static[string], definition: untyped): untyped =
  result = definition
  when defined(harfbuzzStatic):
    let name = definition[0][0][1].strVal
    let pragmas = result[0][1]
    pragmas.add newColonExpr(ident"importc", newLit(name))
    pragmas.add newColonExpr(ident"header", newLit(header))
    if definition[2].kind == nnkObjectTy:
      if definition[2][2].len == 0:
        pragmas.add ident"incompleteStruct"
      else:
        pragmas.add ident"bycopy"
        pragmas.add ident"completeStruct"
