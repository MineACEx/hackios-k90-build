from pathlib import Path
import argparse
import hashlib
import json
import shutil
import subprocess

p = argparse.ArgumentParser()
p.add_argument('mu', type=Path)
p.add_argument('kernel', type=Path)
a = p.parse_args()
mu, kernel = a.mu.resolve(), a.kernel.resolve()
changes = []

def change(relative, before, after):
    path = mu / relative
    text = path.read_text()
    if text.count(before) != 1:
        raise RuntimeError('expected exactly one source anchor: ' + relative)
    path.write_text(text.replace(before, after), newline='\n')
    changes.append(relative)

subprocess.run(['git', 'apply', '--check', '--include=BootShim/BootShim.S', str(kernel/'uefi/mu-silicium.patch')], cwd=mu, check=True)
subprocess.run(['git', 'apply', '--include=BootShim/BootShim.S', str(kernel/'uefi/mu-silicium.patch')], cwd=mu, check=True)
changes.append('BootShim/BootShim.S')
change('BootShim/Makefile', 'CFLAGS            = --target=$(TARGET)', 'CFLAGS            = --target=$(TARGET) -DPAYLOAD_BASE=0xF0000000 -DPAYLOAD_CAP=0x03700000')
manager = 'Silicon/Silicium/SiliciumPkg/Library/BootManagerLib/'
change(manager+'BootManager.c', '#include "BootManager.h"', '#include "BootManager.h"\n#include "XnuLoader.h"')
change(manager+'BootManager.c', '  // Execute Secondary Unable To Boot', '  XnuLoaderMain ();\n\n  // Execute Secondary Unable To Boot')
change(manager+'BootManagerLib.inf', '  BootManager.c', '  BootManager.c\n  XnuLoader.c')
change(manager+'BootManagerLib.inf', '  PcdLib', '  BaseLib\n  PcdLib')
for name in ['XnuLoader.c','XnuLoader.h']:
    shutil.copyfile(kernel/'uefi/files'/manager/name, mu/manager/name)
    changes.append(manager+name)
change('Platforms/Xiaomi/annibalePkg/Library/MemoryMapLib/MemoryMapLib.c', '  {"Display_Reserved",', '  {"XNU_Payload",        0xF0000000, 0x03800000, AddMem, SYS_MEM, SYS_MEM_CAP, Reserv, WRITE_BACK_XN},\n  {"Display_Reserved",')
records = {}
for relative in changes:
    data = (mu/relative).read_bytes()
    records[relative] = {'bytes':len(data), 'sha256':hashlib.sha256(data).hexdigest()}
(mu/'hackios-inputs.json').write_text(json.dumps(records, indent=2)+'\n')
print(json.dumps(records, indent=2))
