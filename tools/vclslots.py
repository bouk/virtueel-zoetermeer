"""Write a reference of virtual method slots for the library classes linked into ROS.exe.

Usage: python tools/vclslots.py ROS.exe kb5.bin > symbols/vcl-vmt-slots.md
"""
import sys

import delphi
import idrkb


def main():
    im = delphi.Image(sys.argv[1])
    kb = idrkb.KnowledgeBase(sys.argv[2])
    vmts = {v.name: v for v in im.find_vmts().values()}
    slots = kb.vmt_slots()
    print('# Virtual method slots of the library classes linked into ROS.exe\n')
    print('Slot offsets are relative to the VMT pointer (`call dword ptr [reg + slot]`).')
    print('Negative TObject slots: -0x20 SafeCallException, -0x1c AfterConstruction, '
          '-0x18 BeforeDestruction, -0x14 Dispatch, -0x10 DefaultHandler, -0x0c NewInstance, '
          '-0x08 FreeInstance, -0x04 Destroy.\n')
    for name in sorted(vmts):
        if name not in slots:
            continue
        n = len(vmts[name].virtuals)
        row = ['`+%#x` %s' % (o, m) for o, m in sorted(slots[name].items()) if o < n * 4]
        if row:
            print('- **%s**: %s' % (name, ', '.join(row)))


if __name__ == '__main__':
    main()
