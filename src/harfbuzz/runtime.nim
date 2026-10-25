## Deferred loading for `-d:harfbuzzRuntime`. No DLL is opened at import time.
## Successful handles remain loaded for the process lifetime, so native objects
## and callbacks cannot outlive their libraries.
import std/[dynlib, locks, strutils, tables]

type
  HarfBuzzLibrary* {.pure.} = enum
    Core
    Subset
    Icu

  HarfBuzzLoadError* = object of CatchableError
    ## A shared library or requested C symbol could not be loaded.

const
  harfbuzzDynlib* {.strdefine.} = ""
  harfbuzzSubsetDynlib* {.strdefine.} = ""
  harfbuzzIcuDynlib* {.strdefine.} = ""

var
  loaderLock: Lock
  handles: array[HarfBuzzLibrary, LibHandle]
  loadedPaths: array[HarfBuzzLibrary, string]
  symbols: array[HarfBuzzLibrary, Table[string, pointer]]

initLock(loaderLock)

proc libraryNames(library: HarfBuzzLibrary): seq[string] =
  let override =
    case library
    of HarfBuzzLibrary.Core: harfbuzzDynlib
    of HarfBuzzLibrary.Subset: harfbuzzSubsetDynlib
    of HarfBuzzLibrary.Icu: harfbuzzIcuDynlib
  if override.len > 0:
    return @[override]
  let stem =
    case library
    of HarfBuzzLibrary.Core: "harfbuzz"
    of HarfBuzzLibrary.Subset: "harfbuzz-subset"
    of HarfBuzzLibrary.Icu: "harfbuzz-icu"
  when defined(windows):
    result = @[stem & ".dll", "lib" & stem & "-0.dll", "lib" & stem & ".dll"]
  elif defined(macosx):
    result = @["lib" & stem & ".0.dylib", "lib" & stem & ".dylib"]
    for prefix in ["/opt/homebrew/opt/harfbuzz/lib/", "/usr/local/opt/harfbuzz/lib/"]:
      result.add prefix & "lib" & stem & ".0.dylib"
  else:
    result = @["lib" & stem & ".so.0", "lib" & stem & ".so"]

proc loadUnlocked(library: HarfBuzzLibrary, path = "") =
  if handles[library] != nil:
    return
  let names =
    if path.len > 0:
      @[path]
    else:
      libraryNames(library)
  for name in names:
    let handle = loadLib(name)
    if handle != nil:
      handles[library] = handle
      loadedPaths[library] = name
      return
  raise newException(
    HarfBuzzLoadError,
    "could not load HarfBuzz " & $library & "; tried: " & names.join(", "),
  )

proc loadHarfbuzz*(library = HarfBuzzLibrary.Core, path = "") {.gcsafe.} =
  ## Loads a library explicitly; otherwise the first C API call loads it lazily.
  ## `path` overrides platform discovery and the corresponding string define.
  ## Raises `HarfBuzzLoadError` on failure; a failed load can be retried.
  ## Core, subset, and ICU load independently. Loaded libraries cannot be replaced.
  {.cast(gcsafe).}:
    withLock loaderLock:
      if handles[library] != nil and path.len > 0 and path != loadedPaths[library]:
        raise newException(ValueError, "HarfBuzz " & $library & " is already loaded")
      loadUnlocked(library, path)

proc harfbuzzSymbol*(library: HarfBuzzLibrary, name: string): pointer {.gcsafe.} =
  ## Internal resolver used by the generated C API wrappers.
  {.cast(gcsafe).}:
    withLock loaderLock:
      loadUnlocked(library)
      result = symbols[library].getOrDefault(name)
      if result != nil:
        return
      result = symAddr(handles[library], name)
      if result == nil:
        raise newException(HarfBuzzLoadError, "missing HarfBuzz symbol: " & name)
      symbols[library][name] = result
