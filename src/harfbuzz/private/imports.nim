## One declaration block for linker-resolved and runtime-loaded C imports.
import std/macros

when defined(harfbuzzStatic) and defined(harfbuzzRuntime):
  {.error: "harfbuzzStatic and harfbuzzRuntime are mutually exclusive".}

when defined(harfbuzzRuntime):
  import std/[dynlib, strutils]
  import harfbuzz/runtime

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
    let handle = genSym(nskParam, "handle")
    let assignments = newStmtList()
    for declaration in declarations:
      if declaration.kind != nnkProcDef:
        error("hbImports expects C proc declarations", declaration)
      let exported = declaration[0]
      let name =
        if exported.kind == nnkPostfix:
          exported[1]
        else:
          exported
      let signature = newTree(
        nnkProcTy,
        declaration[3].copyNimTree(),
        newTree(
          nnkPragma,
          ident"cdecl",
          ident"gcsafe",
          newColonExpr(ident"raises", newNimNode(nnkBracket)),
        ),
      )
      result.add newTree(
        nnkVarSection, newIdentDefs(exported.copyNimTree(), signature.copyNimTree())
      )
      let address = newCall(bindSym"symAddr", handle, newLit(name.strVal))
      assignments.add newAssignment(
        name.copyNimTree(), newTree(nnkCast, signature, address)
      )
    let binder = genSym(nskProc, "bindHarfbuzzImports")
    result.add newProc(
      binder,
      params = [newEmptyNode(), newIdentDefs(handle, bindSym"LibHandle")],
      body = assignments,
      pragmas = newTree(
        nnkPragma, ident"gcsafe", newColonExpr(ident"raises", newNimNode(nnkBracket))
      ),
    )
    result.add newCall(bindSym"registerHarfbuzzImports", newLit(library), binder)
  else:
    let headerLiteral = newLit(header)
    result = quote:
      {.push header: `headerLiteral`, importc, cdecl.}
      `declarations`
      {.pop.}
