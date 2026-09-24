# nim-blake3-c

Nim bindings for the [BLAKE3](https://github.com/BLAKE3-team/BLAKE3) C
implementation.

The BLAKE3 C and assembly sources are vendored in `src/blake3/` and
compiled in with the `compile` pragma, so it works out of the box.

The upstream version and commit are recorded in
`src/blake3/blake3_version.txt`.

## Usage

```nim
import blake3_c

var input = "hello, world"
var h: Blake3Hasher
init(h)
update(h, input[0].addr, csize_t(input.len))
var digest: array[OutLen, byte]
finalize(h, digest[0].addr, OutLen)
```

## Updating

Run `./update.sh <version> [commit]` to download a new BLAKE3 release into
`src/blake3/` and `tests/`, verify its provenance, and commit the update. The
defaults at the top of the script always record the current version and
commit.
