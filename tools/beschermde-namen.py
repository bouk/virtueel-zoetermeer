"""Verzamel identifiers die bij het vertalen naar het Nederlands NIET hernoemd mogen worden.

Dat zijn namen die uit het origineel komen (RTTI: klassen, gepubliceerde velden, methoden en
properties; DFM: componenten, events, properties; de unitnamen) en de API van Delphi/VCL/Win32
zoals de compat-laag die nabootst (alles wat in de interface van src/compat staat), plus de
namen uit de RTL van Free Pascal die de spelcode gebruikt.

Gebruik: python tools/beschermde-namen.py > build/beschermd.txt
"""
import glob
import json
import os
import re

ROOT = os.path.join(os.path.dirname(__file__), '..')
WOORD = re.compile(r'[A-Za-z_][A-Za-z0-9_]*')

# Veelgebruikte RTL-namen (System, SysUtils, Classes, Math, IniFiles) die de spelcode gebruikt
# of overschrijft; aanvullend op wat de compat-interfaces opleveren.
RTL = """
Create Destroy Free Assign AssignTo DefineProperties Loaded Notification ReadState WriteState
Add Insert Delete Clear Count Items Capacity IndexOf Remove Exchange Move Sort Find First Last
Get Put Grow Pack Expand Objects Strings Text CommaText Values Names LoadFromFile SaveToFile
LoadFromStream SaveToStream ReadData WriteData Read Write ReadBuffer WriteBuffer Seek Position
Size Owner Name Tag Components ComponentCount FindComponent InsertComponent RemoveComponent
Data Handle Parent Visible Enabled Left Top Width Height Caption Color Font Canvas Paint Invalidate
Repaint Update Refresh SetBounds MouseDown MouseUp MouseMove KeyDown KeyUp KeyPress Click DblClick
WndProc Dispatch DefaultHandler Message Result Self Sender inherited Exit Halt
IntToStr StrToInt FloatToStr StrToFloat Format Trim UpperCase LowerCase Copy Pos Length SetLength
Inc Dec Ord Chr Round Trunc Frac Int Abs Sqr Sqrt Sin Cos Random Randomize Max Min Odd High Low
TObject TPersistent TComponent TList TStringList TStrings TStream TMemoryStream TFileStream
TNotifyEvent TRect TPoint Point Rect Bounds Exception EAbort TIniFile ReadString ReadInteger
WriteString WriteInteger ReadBool WriteBool SectionExists ReadSection ReadSectionValues
""".split()


def interface_names(path):
    s = open(path, encoding='latin1').read()
    m = re.search(r'\binterface\b(.*?)\bimplementation\b', s, re.S | re.I)
    deel = m.group(1) if m else s
    deel = re.sub(r'\{[^}]*\}|//[^\n]*|\(\*.*?\*\)', ' ', deel, flags=re.S)
    deel = re.sub(r"'(?:[^']|'')*'", ' ', deel)
    return set(WOORD.findall(deel))


def main():
    namen = set(RTL)
    # 1. de compat-laag (Delphi/VCL/Win32-API)
    for pad in glob.glob(os.path.join(ROOT, 'src/compat/**/*.pas'), recursive=True):
        namen |= interface_names(pad)
    # 2. RTTI uit de klassencatalogus
    cat = open(os.path.join(ROOT, 'symbols/classes-1.1.md'), encoding='utf-8').read()
    namen |= set(re.findall(r'^## (\w+) = class\((\w+)\)', cat, re.M) and
                 [n for pair in re.findall(r'^## (\w+) = class\((\w+)\)', cat, re.M) for n in pair])
    namen |= set(re.findall(r'^  - `\+0x[0-9a-f]+` (\w+):', cat, re.M))          # gepubliceerde velden
    namen |= set(re.findall(r'^  - `0x[0-9a-f]+` (\w+)$', cat, re.M))            # gepubliceerde methoden
    for prop, typ in re.findall(r'^  - (\w+): (\w+) read', cat, re.M):           # properties en hun typen
        namen |= {prop, typ}
    # 3. DFM's (component-, event- en propertynamen)
    for pad in glob.glob(os.path.join(ROOT, 'build/dfm-1.1/*.txt')):
        for regel in open(pad, encoding='latin1'):
            m = re.match(r'\s*object (\w+): (\w+)', regel)
            if m:
                namen |= {m.group(1), m.group(2)}
                continue
            m = re.match(r'\s*([\w.]+) = (.*)', regel)
            if m:
                namen |= set(m.group(1).split('.'))
                waarde = re.sub(r"'(?:[^']|'')*'", '', m.group(2))
                if not waarde.startswith('{'):
                    namen |= set(WOORD.findall(waarde))   # events, enum- en setwaarden (htNone, ...)
    # 4. unitnamen
    units = json.load(open(os.path.join(ROOT, 'symbols/units-1.1.json')))
    namen |= set(units['package_units'])
    namen |= {os.path.splitext(os.path.basename(p))[0] for p in glob.glob(os.path.join(ROOT, 'src/game/*.pas'))}
    for n in sorted(namen, key=str.lower):
        print(n)


if __name__ == '__main__':
    main()
