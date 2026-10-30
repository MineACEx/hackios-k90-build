#!/usr/bin/env bash
set -euo pipefail
ROOT="$PWD/work"
export THEOS="$PWD/theos"
export NINJAFLAGS="-j4"
mkdir -p logs graphics-output "$ROOT/xnu-deps/host/bin"
trap 'rc=$?; if [ "$rc" -ne 0 ]; then find "$ROOT/xnu-deps/build/mesa" -maxdepth 3 -name "*.log" -exec tail -n 70 {} \; 2>/dev/null || true; fi' EXIT
if [ ! -f "$THEOS/sdks/iPhoneOS16.5.sdk/SDKSettings.plist" ]; then
  git clone --depth 1 https://github.com/theos/theos.git "$THEOS"
  git -C "$THEOS" fetch --depth 1 origin 304e0799973e8145f32e4ca2de6c747a84b758ce
  git -C "$THEOS" checkout --detach FETCH_HEAD
  mkdir -p "$THEOS/toolchain"
  curl -fL --retry 2 https://github.com/L1ghtmann/llvm-project/releases/latest/download/iOSToolchain-x86_64.tar.xz -o toolchain.tar.xz
  tar -xJf toolchain.tar.xz -C "$THEOS/toolchain"
  "$THEOS/bin/install-sdk" iPhoneOS16.5
fi
printf '%s  %s\n' b61576c013b8639646ae600f7b4b171fb8f2748d99c55f84b0e3be51335fdec2 "$THEOS/toolchain/linux/iphone/bin/ld" | sha256sum -c -
printf '%s  %s\n' 15f0355059d75836977c21f77dc672dd604869ae7f511779e3049db80af560d6 "$THEOS/toolchain/linux/iphone/bin/install_name_tool" | sha256sum -c -
printf '%s  %s\n' e402d200c37290c9bb7c92d8f4b2dbb00374fa9b73bddd16f613fafa92f625a4 "$THEOS/sdks/iPhoneOS16.5.sdk/SDKSettings.plist" | sha256sum -c -
cd "$ROOT"
ln -sfn "$THEOS/toolchain/linux/iphone/bin/ld" xnu-deps/host/bin/ld64
ln -sfn xnu-clang xnu-deps/host/bin/xnu-clang++
chmod +x xnu-deps/host/bin/xnu-clang userland/mkeagl.py
export REBASE=26 VERSION=26.2.5 SHA256=794b3d1729075dae7ebd47c7283b7ca0cdb5dec668f7f11cc0a5d82f6138a0a5
bash tools/mk-mesa.sh 2>&1 | tee ../logs/mesa-console.log
M="$ROOT/xnu-deps/build/mesa/out"
test -s "$M/libOSMesa.8.dylib"
test -s "$M/gl.xml"
test -s "$M/exported-gl.txt"
mkdir -p userland/obj
python3 userland/mkeagl.py userland/src/eagl_slots.txt "$M/gl.xml" "$M/exported-gl.txt" userland/src/eagl.c > userland/obj/eagl_gen.h
CC="$ROOT/xnu-deps/host/bin/xnu-clang"
SDK="$THEOS/sdks/iPhoneOS16.5.sdk"
"$CC" -arch arm64 -isysroot "$SDK" -O1 -dynamiclib -install_name /redwood/lib/libredwood-gl.dylib -Iuserland/obj \
  -framework CoreFoundation -framework IOKit -framework IOSurface -lobjc "$M/libOSMesa.8.dylib" \
  -o ../graphics-output/libredwood-gl.dylib userland/src/eagl.c userland/src/gl_osmesa.c
"$CC" -arch arm64 -isysroot "$SDK" -O1 -framework CoreFoundation -framework IOKit "$M/libOSMesa.8.dylib" \
  -o ../graphics-output/gl_test userland/src/gl_test.c
cp "$M/libOSMesa.8.dylib" "$M/built-from" ../graphics-output/
cp "$M/exported-gl.txt" ../graphics-output/
cp -r firmware-gen8 ../graphics-output/
llvm-objdump --macho --private-headers ../graphics-output/libredwood-gl.dylib > ../graphics-output/gl-load-commands.txt
llvm-objdump --macho --private-headers ../graphics-output/libOSMesa.8.dylib > ../graphics-output/mesa-load-commands.txt
python3 - <<'PY'
import hashlib, json, pathlib
out = pathlib.Path('../graphics-output')
report = {'kernel_source': pathlib.Path('../kernel-source-sha').read_text().strip(), 'userland_source': pathlib.Path('../userland-source-sha').read_text().strip(), 'mesa': '26.2.5', 'files': {}}
for p in sorted(out.rglob('*')):
    if p.is_file():
        report['files'][str(p.relative_to(out))] = {'size': p.stat().st_size, 'sha256': hashlib.sha256(p.read_bytes()).hexdigest()}
(out/'build-manifest.json').write_text(json.dumps(report, indent=2)+'\n')
PY
