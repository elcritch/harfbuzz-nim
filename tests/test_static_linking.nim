## Smoke test for externally supplied static archives; also runs in shared mode.
## See README.md for static compiler flags.
import std/[assertions, os]

import harfbuzz

proc onMove(
    funcs: ptr hb_draw_funcs_t,
    data: pointer,
    state: ptr hb_draw_state_t,
    x, y: cfloat,
    userData: pointer,
) {.cdecl.} =
  inc cast[ptr int](data)[]

block staticCapi:
  doAssert hb_version_atleast(7, 0, 0) != 0
  let path = currentSourcePath().parentDir / "data" / "DejaVuSans.ttf"
  let blob = hb_blob_create_from_file_or_fail(path.cstring)
  doAssert blob != nil
  defer:
    hb_blob_destroy(blob)
  let face = hb_face_create(blob, 0)
  defer:
    hb_face_destroy(face)
  let font = hb_font_create(face)
  defer:
    hb_font_destroy(font)
  hb_ot_font_set_funcs(font)

  let buffer = hb_buffer_create()
  defer:
    hb_buffer_destroy(buffer)
  hb_buffer_add_utf8(buffer, "A", 1, 0, 1)
  hb_buffer_guess_segment_properties(buffer)
  hb_shape(font, buffer, nil, 0)
  var count: cuint
  let infos = hb_buffer_get_glyph_infos(buffer, addr count)
  doAssert count == 1
  doAssert infos[].codepoint != 0

  let funcs = hb_draw_funcs_create()
  defer:
    hb_draw_funcs_destroy(funcs)
  hb_draw_funcs_set_move_to_func(funcs, onMove, nil, nil)
  var moves = 0
  hb_font_draw_glyph(font, infos[].codepoint, funcs, addr moves)
  doAssert moves > 0

  let input = hb_subset_input_create_or_fail()
  defer:
    hb_subset_input_destroy(input)
  hb_set_add(hb_subset_input_unicode_set(input), 0x41)
  let subset = hb_subset_or_fail(face, input)
  doAssert subset != nil
  defer:
    hb_face_destroy(subset)
  doAssert hb_face_get_glyph_count(subset) > 0
