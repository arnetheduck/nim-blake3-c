# Package

version = "1.8.7.0" # last number is for blake3_c itself
author = "Jacek Sieka"
description = "Nim bindings for the BLAKE3 C implementation"
license = "Apache-2.0"
srcDir = "src"

installFiles = @[
  "src/blake3_c.nim", "src/blake3/blake3.h", "src/blake3/blake3.c",
  "src/blake3/blake3_dispatch.c", "src/blake3/blake3_portable.c",
  "src/blake3/blake3_impl.h", "src/blake3/blake3_sse2.c", "src/blake3/blake3_sse41.c",
  "src/blake3/blake3_avx2.c", "src/blake3/blake3_avx512.c", "src/blake3/blake3_neon.c",
  "src/blake3/blake3_sse2_x86-64_unix.S", "src/blake3/blake3_sse41_x86-64_unix.S",
  "src/blake3/blake3_avx2_x86-64_unix.S", "src/blake3/blake3_avx512_x86-64_unix.S",
  "src/blake3/blake3_sse2_x86-64_windows_gnu.S",
  "src/blake3/blake3_sse41_x86-64_windows_gnu.S",
  "src/blake3/blake3_avx2_x86-64_windows_gnu.S",
  "src/blake3/blake3_avx512_x86-64_windows_gnu.S", "src/blake3/blake3_version.txt",
]

# Dependencies

requires "nim >= 2.0"

task test, "Runs the test suite":
  proc test(env, path: string) =
    # Compilation language is controlled by TEST_LANG
    var lang = "c"
    if existsEnv "TEST_LANG":
      lang = getEnv "TEST_LANG"
    exec "nim " & lang & " " & env & " -r " & path

  test "", "tests/test_blake3.nim"
