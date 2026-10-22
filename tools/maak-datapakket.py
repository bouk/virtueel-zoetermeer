"""Maak het datapakket voor de webversie: data.json (index) + data.pack (alle bestanden achter elkaar).

De browserhost (web/zoetermeer.js) laadt beide en zet de bestanden in zijn in-memory
bestandssysteem onder /data/.

Gebruik: python tools/maak-datapakket.py <speelmap> <ROS.exe v1.1> <uitvoer-prefix>
  <speelmap>  uitgepakte installatie (images/, *.Ini, Objecten.csv, wijken.dat)
"""
import json
import os
import sys

OVERSLAAN = {'stub.exe', 'ros.exe', 'uninstall.exe'}   # ROS.exe komt apart (v1.1)


def main():
    speelmap, exe, prefix = sys.argv[1:4]
    bestanden = []
    for map_, _, namen in os.walk(speelmap):
        for naam in sorted(namen):
            if naam.lower() in OVERSLAAN:
                continue
            pad = os.path.join(map_, naam)
            bestanden.append(('/data/' + os.path.relpath(pad, speelmap).replace(os.sep, '/'), pad))
    bestanden.append(('/data/ROS.exe', exe))
    index, positie = [], 0
    with open(prefix + '.pack', 'wb') as uit:
        for doel, bron in bestanden:
            inhoud = open(bron, 'rb').read()
            uit.write(inhoud)
            index.append([doel, positie, len(inhoud)])
            positie += len(inhoud)
    with open(prefix + '.json', 'w') as f:
        json.dump({'dataDir': '/data/', 'exe': '/data/ROS.exe', 'files': index}, f)
    print('%d bestanden, %d bytes' % (len(index), positie))


if __name__ == '__main__':
    main()
