import std/[json, os, strutils, unittest]

import blake3_c

const hexDigits = "0123456789abcdef"

proc toHex(b: openArray[uint8]): string =
  for x in b:
    result &= hexDigits[int(x) div 16] & hexDigits[int(x) mod 16]

proc makeTestInput(length: int): seq[uint8] =
  ## Test input from the official test vectors: a repeating sequence of
  ## 251 bytes: 0, 1, 2, ..., 250, 0, 1, ...
  result = newSeq[uint8](length)
  for i in 0 ..< length:
    result[i] = uint8(i mod 251)

let
  testDir = currentSourcePath.rsplit({DirSep, AltSep}, 1)[0]
  vectors = parseFile(testDir & "/test_vectors.json")
  provenanceFile = testDir & "/../src/blake3/blake3_version.txt"

proc recordedVersion(): string =
  for line in lines(provenanceFile):
    if line.startsWith("BLAKE3 version: "):
      return line.substr("BLAKE3 version: ".len).strip()
  assert false, "version not found in " & provenanceFile

test "version":
  check version() == recordedVersion()

test "test vectors":
  let key = vectors["key"].getStr
  let context = vectors["context_string"].getStr
  for c in vectors["cases"]:
    let input = makeTestInput(c["input_len"].getInt)
    let expectedHash = c["hash"].getStr
    let expectedKeyed = c["keyed_hash"].getStr
    let expectedDerive = c["derive_key"].getStr
    let outLen = expectedHash.len div 2

    # Default hash.
    var h: Blake3Hasher
    init(h)
    if input.len > 0:
      update(h, input[0].addr, csize_t(input.len))
    var digest = newSeq[uint8](outLen)
    finalize(h, digest[0].addr, csize_t(outLen))
    check toHex(digest) == expectedHash
    var digest32: array[OutLen, byte]
    finalize(h, digest32[0].addr, OutLen)
    check toHex(digest32) == expectedHash.substr(0, 2 * OutLen - 1)

    # Keyed hash.
    var hk: Blake3Hasher
    initKeyed(hk, cast[ptr uint8](key[0].addr))
    if input.len > 0:
      update(hk, input[0].addr, csize_t(input.len))
    var digestK = newSeq[uint8](outLen)
    finalize(hk, digestK[0].addr, csize_t(outLen))
    check toHex(digestK) == expectedKeyed

    # Key derivation.
    var hd: Blake3Hasher
    initDeriveKey(hd, cstring(context))
    if input.len > 0:
      update(hd, input[0].addr, csize_t(input.len))
    var digestD = newSeq[uint8](outLen)
    finalize(hd, digestD[0].addr, csize_t(outLen))
    check toHex(digestD) == expectedDerive

test "reset, finalize_seek, derive_key_raw":
  let input = makeTestInput(1024)
  let context = vectors["context_string"].getStr

  # Reset restores the initial state.
  var h: Blake3Hasher
  init(h)
  update(h, input[0].addr, csize_t(input.len))
  reset(h)
  update(h, input[0].addr, csize_t(input.len))
  var digest: array[OutLen, byte]
  finalize(h, digest[0].addr, OutLen)
  var h2: Blake3Hasher
  init(h2)
  update(h2, input[0].addr, csize_t(input.len))
  var digest2: array[OutLen, byte]
  finalize(h2, digest2[0].addr, OutLen)
  check toHex(digest) == toHex(digest2)

  # finalize_seek with seek 0 matches finalize.
  var seekOut: array[OutLen, byte]
  finalizeSeek(h, 0, seekOut[0].addr, OutLen)
  check toHex(seekOut) == toHex(digest)

  # init_derive_key_raw matches init_derive_key.
  var hd: Blake3Hasher
  initDeriveKeyRaw(hd, context[0].addr, csize_t(context.len))
  if input.len > 0:
    update(hd, input[0].addr, csize_t(input.len))
  var digestD: array[OutLen, byte]
  finalize(hd, digestD[0].addr, OutLen)
  var hd2: Blake3Hasher
  initDeriveKey(hd2, cstring(context))
  if input.len > 0:
    update(hd2, input[0].addr, csize_t(input.len))
  var digestD2: array[OutLen, byte]
  finalize(hd2, digestD2[0].addr, OutLen)
  check toHex(digestD) == toHex(digestD2)
