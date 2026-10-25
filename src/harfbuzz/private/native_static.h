/* Nim's cstring has no const qualifier. Preserve the existing Nim API while
 * adapting the few const pointer/callback boundaries for C++ and MSVC. */
#ifndef HARFBUZZ_NIM_NATIVE_STATIC_H
#define HARFBUZZ_NIM_NATIVE_STATIC_H
#include <harfbuzz/hb.h>
#include <harfbuzz/hb-ot.h>

#define hb_ot_name_list_names(face, count) \
  ((hb_ot_name_entry_t *) hb_ot_name_list_names(face, count))
#define hb_buffer_deserialize_glyphs(buffer, text, len, end, font, format) \
  hb_buffer_deserialize_glyphs(buffer, text, len, (const char **) (end), font, format)
#define hb_buffer_deserialize_unicode(buffer, text, len, end, format) \
  hb_buffer_deserialize_unicode(buffer, text, len, (const char **) (end), format)
#define hb_buffer_set_message_func(buffer, callback, data, destroy) \
  hb_buffer_set_message_func(buffer, (hb_buffer_message_func_t) (callback), data, destroy)
#endif
