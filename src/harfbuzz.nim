# Nim bindings to HarfBuzz text shaping engine
#
# (c) 2026 George Lemon | MIT License
#          https://github.com/nimbase/harfbuzz-nim 

## harfbuzz: low-level Nim bindings for the HarfBuzz text shaping library.
##
## C names are preserved verbatim so upstream code stays greppable.
## Uses pkg-config by default; `harfbuzzStatic` uses caller-supplied build flags.
## `harfbuzzRuntime` binds procedure pointers from the unchanged native API.

when not defined(harfbuzzStatic) and not defined(harfbuzzRuntime):
  {.passC: gorge("pkg-config --cflags harfbuzz").}
  {.passL: gorge("pkg-config --libs harfbuzz").}
# Callback signatures are ABI-identical to C (pointer-sized opaques,
# 4-byte enums, POD structs) but differ nominally (Nim type spellings
# vs C tags), which clang 16+ escalates to a hard error when Nim procs
# are registered as C callbacks. Demote back to a warning; see
# hb_common for the full note.
when not defined(harfbuzzStatic) and not defined(harfbuzzRuntime):
  {.passC: "-Wno-incompatible-function-pointer-types".}

when defined(harfbuzzRuntime):
  import harfbuzz/runtime_api
  export runtime_api
else:
  import harfbuzz/private/native_api
  export native_api
