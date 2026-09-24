## Nim bindings for the BLAKE3 C implementation.
##
## The BLAKE3 C and assembly sources are vendored in ``src/blake3/`` and
## compiled in with the `compile` pragma, so there is nothing to link
## against. The pinned upstream version and commit are recorded in
## ``src/blake3/blake3_version.txt``.
##
## See also: https://github.com/BLAKE3-team/BLAKE3

const
  KeyLen* = 32
  ## Length of the key in keyed hash mode.
  OutLen* = 32
  ## Default output length.
  BlockLen* = 64
  ChunkLen* = 1024
  MaxDepth* = 54

type
  Blake3ChunkState = object
    # C-compatible layout of ``blake3_chunk_state``. Private, per blake3 docs.
    cv: array[OutLen div 4, uint32]
    chunkCounter: uint64
    buf: array[BlockLen, uint8]
    bufLen: uint8
    blocksCompressed: uint8
    flags: uint8

  Blake3Hasher* = object # C-compatible layout of ``blake3_hasher``.
    key*: array[KeyLen div 4, uint32]
    chunk: Blake3ChunkState
    cvStackLen*: uint8
    cvStack*: array[(MaxDepth + 1) * OutLen, uint8]

when (defined(x64) or defined(amd64)):
  when defined(windows) and defined(msvc):
    # The MASM assembly files cannot be compiled by Nim, so use the C
    # intrinsic implementations instead. SSE2 is baseline on x86-64,
    # but SSE4.1/AVX2/AVX512 would need per-file compiler flags, so
    # disable them.
    {.passC: "-DBLAKE3_NO_SSE41 -DBLAKE3_NO_AVX2 -DBLAKE3_NO_AVX512".}
    {.compile: "blake3/blake3_sse2.c".}
  elif defined(windows):
    {.compile: "blake3/blake3_sse2_x86-64_windows_gnu.S".}
    {.compile: "blake3/blake3_sse41_x86-64_windows_gnu.S".}
    {.compile: "blake3/blake3_avx2_x86-64_windows_gnu.S".}
    {.compile: "blake3/blake3_avx512_x86-64_windows_gnu.S".}
  else:
    {.compile: "blake3/blake3_sse2_x86-64_unix.S".}
    {.compile: "blake3/blake3_sse41_x86-64_unix.S".}
    {.compile: "blake3/blake3_avx2_x86-64_unix.S".}
    {.compile: "blake3/blake3_avx512_x86-64_unix.S".}
elif defined(i386) or defined(x86):
  # 32-bit x86: use the portable implementation to avoid global compiler
  # flags for the SIMD intrinsics.
  {.passC: "-DBLAKE3_NO_SSE2 -DBLAKE3_NO_SSE41 -DBLAKE3_NO_AVX2 -DBLAKE3_NO_AVX512".}
elif defined(arm64):
  {.compile: "blake3/blake3_neon.c".}

{.compile: "blake3/blake3.c".}
{.compile: "blake3/blake3_dispatch.c".}
{.compile: "blake3/blake3_portable.c".}

proc version*(): cstring {.importc: "blake3_version".}
  ## Returns the BLAKE3 version string.

proc init*(h: var Blake3Hasher) {.importc: "blake3_hasher_init".}
  ## Initializes a hasher in the default (unkeyed) mode.

proc initKeyed*(
  h: var Blake3Hasher, key: ptr uint8
) {.importc: "blake3_hasher_init_keyed".}
  ## Initializes a hasher in keyed hash mode. ``key`` must point to
  ## ``Blake3KeyLen`` bytes.

proc initDeriveKey*(
  h: var Blake3Hasher, context: cstring
) {.importc: "blake3_hasher_init_derive_key".}
  ## Initializes a hasher in key derivation mode with a NUL-terminated
  ## context string.

proc initDeriveKeyRaw*(
  h: var Blake3Hasher, context: pointer, contextLen: csize_t
) {.importc: "blake3_hasher_init_derive_key_raw".}
  ## Initializes a hasher in key derivation mode with a raw context byte
  ## string.

proc update*(
  h: var Blake3Hasher, input: pointer, inputLen: csize_t
) {.importc: "blake3_hasher_update".}
  ## Feeds ``inputLen`` bytes from ``input`` into the hasher.

proc finalize*(
  h: Blake3Hasher, outPtr: ptr uint8, outLen: csize_t
) {.importc: "blake3_hasher_finalize".}
  ## Writes ``outLen`` bytes of the hash to ``outPtr``.

proc finalizeSeek*(
  h: Blake3Hasher, seek: uint64, outPtr: ptr uint8, outLen: csize_t
) {.importc: "blake3_hasher_finalize_seek".}
  ## Writes ``outLen`` bytes of the hash to ``outPtr``, starting at output
  ## byte ``seek``.

proc reset*(h: var Blake3Hasher) {.importc: "blake3_hasher_reset".}
  ## Resets the hasher to its initial state.
