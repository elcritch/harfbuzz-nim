## One declaration block for linker-resolved and deferred C imports.
import std/macros

when defined(harfbuzzStatic) and defined(harfbuzzRuntime):
  {.error: "harfbuzzStatic and harfbuzzRuntime are mutually exclusive".}

when defined(harfbuzzRuntime):
  import std/strutils
  import harfbuzz/runtime

  proc cPragmas(definition: NimNode): NimNode {.compileTime.} =
    result = newNimNode(nnkPragma)
    for pragma in definition[4]:
      let key =
        if pragma.kind == nnkExprColonExpr:
          pragma[0]
        else:
          pragma
      if key.strVal notin ["header", "importc", "cdecl"]:
        result.add pragma
    result.add ident"cdecl"

  proc deferredProc(definition, address: NimNode): NimNode {.compileTime.} =
    result = definition.copyNimTree()
    result[4] = cPragmas(definition)
    let parameters = definition[3].copyNimTree()
    for index in 1 ..< parameters.len:
      parameters[index][^1] = newEmptyNode()
    let signature = newTree(
      nnkProcTy,
      parameters,
      newTree(
        nnkPragma,
        ident"cdecl",
        ident"gcsafe",
        newColonExpr(ident"raises", newNimNode(nnkBracket)),
      ),
    )
    let function = genSym(nskLet, "function")
    let call = newCall(function)
    for index in 1 ..< parameters.len:
      for argument in 0 ..< parameters[index].len - 2:
        call.add parameters[index][argument].copyNimTree()
    let body = newStmtList(newLetStmt(function, newTree(nnkCast, signature, address)))
    if parameters[0].kind == nnkEmpty:
      body.add call
    else:
      body.add newAssignment(ident"result", call)
    result[6] = body

  proc cName(definition: NimNode): string {.compileTime.} =
    let exported = definition[0]
    let name =
      if exported.kind == nnkPostfix:
        exported[1]
      else:
        exported
    name.strVal

macro hbImports*(header: static[string], declarations: untyped): untyped =
  when defined(harfbuzzRuntime):
    result = newStmtList()
    let library =
      if "subset" in header:
        HarfBuzzLibrary.Subset
      elif "icu" in header:
        HarfBuzzLibrary.Icu
      else:
        HarfBuzzLibrary.Core
    for declaration in declarations:
      if declaration.kind != nnkProcDef:
        error("hbImports expects C proc declarations", declaration)
      let address =
        newCall(bindSym"harfbuzzSymbol", newLit(library), newLit(cName(declaration)))
      result.add deferredProc(declaration, address)
  else:
    let headerLiteral = newLit(header)
    result = quote:
      {.push header: `headerLiteral`, importc, cdecl.}
      `declarations`
      {.pop.}
