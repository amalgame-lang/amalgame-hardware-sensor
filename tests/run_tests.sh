#!/bin/bash
# Portable-driver test runner. Tests the driver against FAKE backends
# that implement the Amalgame.Hal interfaces — no hardware, no gpiod,
# just amalgame-hal as --external. Needs amc 0.8.72+.
#
# amalgame-hal is resolved from $HAL_DIR if set, else git-cloned at
# $HAL_TAG (default v0.1.0).
set -u

if [ $# -ge 1 ]; then AMC="$1"
elif [ -n "${AMC:-}" ]; then :
elif command -v amc >/dev/null 2>&1; then AMC="$(command -v amc)"
else echo "ERROR: amc not found." >&2; exit 2; fi
[ -x "$AMC" ] || { echo "ERROR: amc not executable: $AMC" >&2; exit 2; }
AMC="$(cd "$(dirname "$AMC")" && pwd)/$(basename "$AMC")"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PKG_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
AMC_DIR="$(cd "$(dirname "$AMC")" && pwd)"
if   [ -d "$AMC_DIR/runtime" ]; then RT="$AMC_DIR/runtime"
elif [ -d "$AMC_DIR/../share/amalgame/runtime" ]; then RT="$(cd "$AMC_DIR/../share/amalgame/runtime" && pwd)"
elif [ -n "${AMC_RUNTIME:-}" ]; then RT="$AMC_RUNTIME"
else echo "ERROR: amc runtime/ not found." >&2; exit 2; fi
if   [ -f "$AMC_DIR/lib/libamalgame.a" ]; then LIBA="$AMC_DIR/lib/libamalgame.a"
elif [ -f "$AMC_DIR/../share/amalgame/lib/libamalgame.a" ]; then LIBA="$(cd "$AMC_DIR/../share/amalgame/lib" && pwd)/libamalgame.a"
else echo "ERROR: libamalgame.a not found." >&2; exit 2; fi

BUILD="$(mktemp -d)"; trap 'rm -rf "$BUILD"' EXIT
GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
echo "$(basename "$PKG_ROOT") — $("$AMC" --version 2>&1 | head -1)"

# Resolve amalgame-hal (facade only — interfaces).
if [ -n "${HAL_DIR:-}" ]; then
    HAL="$HAL_DIR"
else
    HAL_TAG="${HAL_TAG:-v0.1.0}"
    git clone --depth 1 --branch "$HAL_TAG" -q \
        https://github.com/amalgame-lang/amalgame-hal "$BUILD/hal" \
        || { echo "ERROR: cannot clone amalgame-hal@$HAL_TAG" >&2; exit 2; }
    HAL="$BUILD/hal"
fi
HALF="$HAL/facade.am"

# Smoke: the driver facade compiles against the HAL.
"$AMC" --lib --quiet "$PKG_ROOT/facade.am" --external "$HALF" -o "$BUILD/drv" \
    || { echo "facade compile FAILED"; exit 1; }
gcc -O2 -I"$RT" -w -c "$BUILD/drv.c" -o "$BUILD/drv.o" || exit 1
echo "  facade compiles against amalgame-hal"

PASS=0; FAIL=0
for t in "$SCRIPT_DIR"/*.am; do
    name="$(basename "$t" .am)"
    cp "$t" "$BUILD/$name.am"
    if (cd "$BUILD" && "$AMC" --quiet -o "$name" "$name.am" --external "$HALF" --external "$PKG_ROOT/facade.am") 2>"$BUILD/$name.err" \
       && gcc -O2 -I"$RT" -w "$BUILD/$name.c" "$BUILD/drv.o" "$LIBA" -lgc -lm -lz -ldl -lpthread -o "$BUILD/$name.bin" 2>>"$BUILD/$name.err"; then
        OUT="$("$BUILD/$name.bin" 2>&1)"; echo "$OUT" | sed 's/^/    /'
        if echo "$OUT" | grep -q '\[FAIL\]'; then FAIL=1; else PASS=1; fi
    else
        echo -e "  ${RED}$name build FAILED${NC}"; cat "$BUILD/$name.err"; FAIL=1
    fi
done

if [ "$FAIL" -eq 0 ]; then echo -e "${GREEN}ALL TESTS PASSED${NC}"; else echo -e "${RED}TESTS FAILED${NC}"; exit 1; fi
