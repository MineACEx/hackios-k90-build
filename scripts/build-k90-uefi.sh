#!/usr/bin/env bash
set -euo pipefail
mkdir -p output
python3 -m venv venv
venv/bin/pip install -r mu/pip-requirements.txt pillow
export PATH="$PWD/venv/bin:$PATH"
python3 scripts/prepare-k90-uefi.py mu kernel
cd mu
# Use the installed NASM instead of fetching the NuGet wrapper through Mono.
test -f Mu_Basecore/BaseTools/Bin/nasm_ext_dep.yaml
mv Mu_Basecore/BaseTools/Bin/nasm_ext_dep.yaml Mu_Basecore/BaseTools/Bin/nasm_ext_dep.yaml.disabled
nasm -v
python3 build_uefi.py -d annibale 2>&1 | tee ../output/uefi-build.log
test -s Build/annibalePkg/RELEASE_CLANGPDB/FV/SILICIUM_UEFI.fd
cd ../kernel
EXTRA_CFLAGS=-DDIRECT_PHONE_PLAT BUILD_ID=dc49065f8f17c3683925270388eba128f28eab33 bash xnuloader/build.sh
python3 xnuloader/mkpayload.py -o ../output/loader-usb-payload.bin loader.efi=xnuloader/loader-phone.efi --usb
ln -s ../mu Mu-Silicium
UEFI_TARGET=annibale UEFI_FD=../mu/Build/annibalePkg/RELEASE_CLANGPDB/FV/SILICIUM_UEFI.fd DTB=../mu/Resources/DTBs/annibale.dtb FD_BASE=0xA7100000 FD_SIZE=0x300000 PAYLOAD_BASE=0xF0000000 PAYLOAD_CAP=0x03700000 python3 mkxnuimg.py -p ../output/loader-usb-payload.bin -o ../output/k90-hackios-loader-v1.img
cp ../mu/Build/annibalePkg/RELEASE_CLANGPDB/FV/SILICIUM_UEFI.fd ../mu/BootShim/BootShim.bin ../mu/Resources/DTBs/annibale.dtb ../mu/hackios-inputs.json xnuloader/loader-phone.efi ../output/
llvm-objdump -d ../mu/BootShim/BootShim.elf > ../output/bootshim-disassembly.txt
cd ../output
sha256sum *.img *.fd *.bin *.dtb *.efi > SHA256SUMS
