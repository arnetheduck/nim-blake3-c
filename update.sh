#!/usr/bin/env bash
set -eu -o pipefail
cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")"

git diff --exit-code -- . ':(exclude)update.sh' > /dev/null || { echo "Commit changes before updating!" ; exit 1 ; }

# https://github.com/BLAKE3-team/BLAKE3/releases
VERSION="${1:-1.8.7}"
HASH="${2:-f3149ec5bb5449af877ba20377a11008ff499fa2}"

API="https://api.github.com/repos/BLAKE3-team/BLAKE3"
RAW="https://raw.githubusercontent.com/BLAKE3-team/BLAKE3"

# Resolve a tag to the commit it points to (lightweight or annotated).
tag_commit() {
  curl -sf "$API/git/ref/tags/$1" | python3 -c '
import json, sys, urllib.request
d = json.load(sys.stdin)
obj = d["object"]
if obj["type"] != "commit":
    tag = json.load(urllib.request.urlopen(obj["url"]))
    print(tag["object"]["sha"])
else:
    print(obj["sha"])
'
}

if [ -z "$HASH" ]; then
  HASH="$(tag_commit "$VERSION")"
else
  ACTUAL="$(tag_commit "$VERSION")"
  [ "$ACTUAL" = "$HASH" ] || { echo "Tag $VERSION points to $ACTUAL, not $HASH" >&2 ; exit 1 ; }
fi

# upstream path -> local path
FILES=(
  "c/blake3.c src/blake3/blake3.c"
  "c/blake3.h src/blake3/blake3.h"
  "c/blake3_dispatch.c src/blake3/blake3_dispatch.c"
  "c/blake3_portable.c src/blake3/blake3_portable.c"
  "c/blake3_impl.h src/blake3/blake3_impl.h"
  "c/blake3_sse2.c src/blake3/blake3_sse2.c"
  "c/blake3_sse41.c src/blake3/blake3_sse41.c"
  "c/blake3_avx2.c src/blake3/blake3_avx2.c"
  "c/blake3_avx512.c src/blake3/blake3_avx512.c"
  "c/blake3_neon.c src/blake3/blake3_neon.c"
  "c/blake3_sse2_x86-64_unix.S src/blake3/blake3_sse2_x86-64_unix.S"
  "c/blake3_sse2_x86-64_windows_gnu.S src/blake3/blake3_sse2_x86-64_windows_gnu.S"
  "c/blake3_sse41_x86-64_unix.S src/blake3/blake3_sse41_x86-64_unix.S"
  "c/blake3_sse41_x86-64_windows_gnu.S src/blake3/blake3_sse41_x86-64_windows_gnu.S"
  "c/blake3_avx2_x86-64_unix.S src/blake3/blake3_avx2_x86-64_unix.S"
  "c/blake3_avx2_x86-64_windows_gnu.S src/blake3/blake3_avx2_x86-64_windows_gnu.S"
  "c/blake3_avx512_x86-64_unix.S src/blake3/blake3_avx512_x86-64_unix.S"
  "c/blake3_avx512_x86-64_windows_gnu.S src/blake3/blake3_avx512_x86-64_windows_gnu.S"
  "test_vectors/test_vectors.json tests/test_vectors.json"
  "LICENSE_A2 LICENSE_A2"
  "LICENSE_A2LLVM LICENSE_A2LLVM"
  "LICENSE_CC0 LICENSE_CC0"
)

# Download all files and verify their git blob hashes against the tree at $HASH.
TREE="$(curl -sf "$API/git/trees/$HASH?recursive=1")"

for pair in "${FILES[@]}"; do
  set -- $pair
  src="$1"
  dst="$2"
  curl -sfL "$RAW/$VERSION/$src" -o "$dst"
  EXPECTED="$(python3 -c '
import json, sys
d = json.loads(sys.argv[1])
for t in d["tree"]:
    if t["path"] == sys.argv[2] and t["type"] == "blob":
        print(t["sha"])
        break
' "$TREE" "$src")"
  [ -n "$EXPECTED" ] || { echo "File $src not found in tree at $HASH" >&2 ; exit 1 ; }
  ACTUAL_BLOB="$(git hash-object "$dst")"
  [ "$ACTUAL_BLOB" = "$EXPECTED" ] || { echo "Hash mismatch for $dst" >&2 ; exit 1 ; }
done

# Document provenance.
cat > src/blake3/blake3_version.txt <<EOF
BLAKE3 version: $VERSION
git commit: $HASH
url: https://github.com/BLAKE3-team/BLAKE3/commit/$HASH
EOF

sed -i.bak \
  -e "s|^version.*|version = \"${VERSION}.0\"|g" \
  blake3_c.nimble
rm -f blake3_c.nimble.bak  # Portable GNU/macOS `sed` needs backup

! git diff --exit-code > /dev/null || { echo "This repository is already up to date" ; exit 0 ; }

git commit -a \
  -m "bump \`blake3\` to \`${VERSION}\`" \
  -m "- https://github.com/BLAKE3-team/BLAKE3/releases/tag/${VERSION}"

echo "The repo has been updated with a commit recording the update."
echo "You can review the changes with 'git diff HEAD^' before pushing to a public repository."
