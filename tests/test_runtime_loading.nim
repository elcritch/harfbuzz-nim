## Runtime mode must start successfully even when every DLL is unavailable.
when defined(harfbuzzRuntime):
  import std/[os, unittest]
  import harfbuzz
  from harfbuzz/runtime import harfbuzzSymbol

  const expectMissing {.booldefine.} = false

  suite "deferred HarfBuzz libraries":
    test "explicit loading reports missing libraries without exiting":
      expect HarfBuzzLoadError:
        loadHarfbuzz(path = currentSourcePath().parentDir / "missing-harfbuzz-library")

    when expectMissing:
      test "C API failures are catchable and can be retried":
        for attempt in 0 .. 1:
          expect HarfBuzzLoadError:
            discard hb_version_string()

      test "a successful explicit load recovers after failed discovery":
        let path = getEnv("HARFBUZZ_TEST_CORE_PATH")
        if path.len > 0:
          loadHarfbuzz(path = path)
          check hb_version_atleast(7, 0, 0) != 0
          check ($hb_version_string()).len > 0
    else:
      when compileOption("threads"):
        test "concurrent first calls share the loaded library":
          proc probe(ok: ptr bool) {.thread.} =
            ok[] = true
            for i in 0 ..< 100:
              ok[] = ok[] and hb_version_atleast(7, 0, 0) != 0

          var results: array[2, bool]
          var threads: array[2, Thread[ptr bool]]
          for i in 0 ..< threads.len:
            createThread(threads[i], probe, addr results[i])
          joinThreads(threads)
          check results[0] and results[1]

      test "core loads explicitly and supports C function pointers":
        loadHarfbuzz()
        let versionAtLeast = hb_version_atleast
        check versionAtLeast(7, 0, 0) != 0
        check ($hb_version_string()).len > 0

      test "missing companion libraries leave core usable":
        expect HarfBuzzLoadError:
          loadHarfbuzz(HarfBuzzLibrary.Subset, "missing-harfbuzz-subset-library")
        check hb_version_atleast(7, 0, 0) != 0

      test "missing C symbols raise a load error":
        expect HarfBuzzLoadError:
          discard harfbuzzSymbol(HarfBuzzLibrary.Core, "hb_missing_symbol_for_test")
        check hb_version_atleast(7, 0, 0) != 0
