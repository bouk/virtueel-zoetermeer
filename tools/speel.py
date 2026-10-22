"""Speel de portable build van Virtueel Zoetermeer stap voor stap (voor een agent of een mens).

Het spel draait headless op de achtergrond (build/fpc/RosTest met het testharnas in
live-modus, zie src/tests/ZMHarness.pas). Elk subcommando voegt een regel toe aan het
besturingsbestand en wacht tot het harnas die heeft uitgevoerd. Zo is elke stap synchroon en
staat de hele sessie in <map>/besturing.zms, dat later als script na te spelen is.

  python tools/speel.py start              start een nieuw spel (map: build/speel)
  python tools/speel.py foto [naam]        screenshot; drukt het pad af (bekijk de PNG)
  python tools/speel.py klik X Y [rechts]  klik op schermcoordinaten (1024x768)
  python tools/speel.py cel X Y [rechts]   klik op het midden van kaartcel X,Y (zie 'kaart')
  python tools/speel.py kaart [X1 Y1 X2 Y2] plattegrond van de kaart in tekst (cellen 0..44)
  python tools/speel.py beweeg X Y         beweeg de muis (bijv. om een hint te zien)
  python tools/speel.py toets NAAM         Return, Escape, Left, Right, Up, Down, plus, minus, ...
  python tools/speel.py wacht MS           laat het spel MS milliseconden doorlopen
  python tools/speel.py toestand           niveau, geld, score en wat er op de kaart staat
  python tools/speel.py stop               spel afsluiten

Crash: het proces is weg -> 'SPEL GECRASHT' plus het einde van de log, exitcode 2. Is het
spel zelf netjes afgesloten (Stop -> Ja), dan meldt het commando dat met exitcode 4.
Hang: een commando wordt niet binnen 60 s bevestigd en de hartslag staat stil ->
'SPEL HANGT', exitcode 3. Omgeving: ZM_SPEELMAP om een andere map te gebruiken.
"""
import collections
import json
import os
import shutil
import signal
import subprocess
import sys
import time

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
MAP = os.path.abspath(os.environ.get('ZM_SPEELMAP', os.path.join(ROOT, 'build', 'speel')))
BESTURING = os.path.join(MAP, 'besturing.zms')
UIT = os.path.join(MAP, 'uit')
PIDBESTAND = os.path.join(MAP, 'pid')
LOG = os.path.join(MAP, 'log.txt')
PROGRAMMA = os.path.join(ROOT, 'build', 'fpc', 'RosTest')


def lees(pad, standaard=''):
    try:
        return open(pad).read()
    except OSError:
        return standaard


def pid():
    try:
        return int(lees(PIDBESTAND).strip())
    except ValueError:
        return None


def leeft():
    p = pid()
    if not p:
        return False
    try:
        os.kill(p, 0)
    except OSError:
        return False
    # een zombie telt als dood
    return 'Z' not in lees('/proc/%d/stat' % p).split(')')[-1][:3]


def gewoon_beeindigd():
    """Het harnas schrijft bij een gewoon einde exitcode 0 naar uit/einde."""
    return lees(os.path.join(UIT, 'einde')).strip() == '0'


def crash():
    if gewoon_beeindigd():
        print('het spel is afgesloten (bijv. via Stop -> Ja); start een nieuw spel met "start"')
        sys.exit(4)
    print('SPEL GECRASHT')
    print('--- laatste regels van', LOG)
    print('\n'.join(lees(LOG).splitlines()[-30:]))
    print('--- commandolog (na te spelen):', BESTURING)
    sys.exit(2)


def regels():
    return len(lees(BESTURING).splitlines())


def stuur(regel, wachttijd=60, einde_verwacht=False):
    """Voeg een regel toe en wacht tot het harnas hem bevestigt."""
    if not leeft():
        crash()
    with open(BESTURING, 'a') as f:
        f.write(regel + '\n')
    doel = regels()
    begin = time.time()
    while True:
        try:
            if int(lees(os.path.join(UIT, 'bevestigd'), '0').strip() or 0) >= doel:
                return
        except ValueError:
            pass
        if not leeft():
            if einde_verwacht:
                return
            crash()
        if time.time() - begin > wachttijd:
            hartslag = os.path.join(UIT, 'hartslag')
            stil = time.time() - os.path.getmtime(hartslag) if os.path.exists(hartslag) else 1e9
            if stil > 10:
                print('SPEL HANGT (geen hartslag sinds %.0f s)' % stil)
                print('commandolog:', BESTURING)
                sys.exit(3)
            begin = time.time()          # het spel leeft nog, maar is druk: blijf wachten
        time.sleep(0.05)


def start():
    if leeft():
        print('er draait al een spel (pid %d); eerst "stop"' % pid())
        return
    if not os.path.exists(PROGRAMMA):
        print('bouw eerst: nix develop --command tools/build.sh src/tests/RosTest.dpr')
        sys.exit(1)
    os.makedirs(UIT, exist_ok=True)
    for oud in os.listdir(UIT):
        os.remove(os.path.join(UIT, oud))
    open(BESTURING, 'w').close()
    omgeving = dict(os.environ,
                    ZM_HEADLESS='1', ZM_DEBUG='1',
                    ZM_BESTURING=BESTURING, ZM_TESTOUT=UIT,
                    ZM_SAVE=os.path.join(MAP, 'opslag'))
    omgeving.setdefault('ZM_DATA', os.path.join(ROOT, 'orig', 'game'))
    omgeving.setdefault('ZM_EXE', os.path.join(ROOT, 'orig', 'game-1.1', 'ROS.exe'))
    # eigen kopie van het programma, zodat een nieuwe build het lopende spel niet raakt
    kopie = os.path.join(MAP, 'RosTest')
    shutil.copy2(PROGRAMMA, kopie)
    with open(LOG, 'w') as log:
        p = subprocess.Popen([kopie], env=omgeving, stdout=log, stderr=subprocess.STDOUT,
                             start_new_session=True)
    open(PIDBESTAND, 'w').write(str(p.pid))
    stuur('wait 3000')
    print('spel gestart (pid %d); maak een foto om te zien wat er op het scherm staat' % p.pid)


def foto(naam=None):
    naam = naam or 'foto-%d' % (regels() + 1)
    stuur('shot ' + naam)
    print(os.path.join(UIT, naam + '.png'))


def toestand():
    stuur('dump toestand')
    tekst = lees(os.path.join(UIT, 'toestand.state'))
    kop, telling = [], collections.Counter()
    for r in tekst.splitlines():
        if r.startswith('cell '):
            inhoud = r.split()[3]
            if inhoud not in ('Onbereikbaar', 'Sloop'):
                telling[inhoud] += 1
        else:
            kop.append(r)
    print('\n'.join(kop))
    print('op de kaart:', json.dumps(dict(telling.most_common()), ensure_ascii=False))


# Tekens voor 'kaart'; andere inhoud krijgt de eerste letter van zijn naam (klein).
TEKENS = {'Sloop': '.', 'Onbereikbaar': ' ', 'Bakst': '=', 'Weg': '=', 'Snel': 'S', 'Klaver': 'S',
          'Rails10': '#', 'AndereStad': '@', 'Laagbouw': 'L', 'Middenbouw': 'M', 'Hoogbouw': 'H',
          'Kantoor': 'K', 'Molen': 'W'}


def kaart(*grenzen):
    """Plattegrond uit een state dump: rijen = y, kolommen = x. Daaronder het gebouw zonder route
    (Bereikbaar 0, het knippert). TWorld.BerekenReistijd stopt bij het eerste gebouw zonder route,
    dus er kunnen er meer zijn: los het gemelde op en kijk opnieuw."""
    stuur('dump toestand')
    x1, y1, x2, y2 = (int(g) for g in grenzen) if len(grenzen) == 4 else (0, 0, 44, 44)
    cellen, gebruikt, los = {}, {}, []
    for r in lees(os.path.join(UIT, 'toestand.state')).splitlines():
        if not r.startswith('cell '):
            continue
        # Param kan spaties bevatten (een wijknaam als 'Buytenwegh De Leyens')
        v = r.split()
        x, y, inhoud, bereikbaar = v[1], v[2], v[3], v[-1]
        x, y = int(x), int(y)
        teken = TEKENS.get(inhoud, inhoud[0].lower())
        cellen[x, y] = teken
        gebruikt[teken] = inhoud
        if bereikbaar == '0' and inhoud not in ('Sloop', 'Onbereikbaar', 'AndereStad'):
            los.append('%d,%d %s' % (x, y, inhoud))
    print('    ' + ''.join(str(x // 10) if x % 10 == 0 else ' ' for x in range(x1, x2 + 1)))
    print('  y ' + ''.join(str(x % 10) for x in range(x1, x2 + 1)) + '  x')
    for y in range(y1, y2 + 1):
        print('%3d ' % y + ''.join(cellen.get((x, y), '?') for x in range(x1, x2 + 1)))
    print('legenda: ' + ', '.join("'%s' %s" % (t, n) for t, n in sorted(gebruikt.items())))
    print("(' ' = wijk nog niet open). Op het scherm: x+1 = rechtsomlaag, y+1 = linksomlaag.")
    print('Cellen zijn alleen buren als ze een zijde delen (x of y verschilt 1, niet allebei).')
    if los:
        print('geen route (knippert; misschien zijn er meer): ' + '; '.join(los))


def cel(x, y, rechts=False):
    stuur('waar %d %d' % (x, y))
    px, py, binnen = (int(v) for v in lees(os.path.join(UIT, 'waar')).split())
    if not binnen:
        print('cel %d,%d valt buiten beeld (scherm %d,%d); scroll met de pijlen of zoom uit' % (x, y, px, py))
        sys.exit(1)
    stuur('click %d %d%s' % (px, py, ' right' if rechts else ''))
    print('ok (scherm %d,%d)' % (px, py))


def stop():
    if leeft():
        try:
            stuur('stop', wachttijd=5, einde_verwacht=True)
        except SystemExit:
            pass
        time.sleep(0.5)
        if leeft():
            os.killpg(pid(), signal.SIGTERM)
    print('spel gestopt')


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return
    cmd, args = sys.argv[1], sys.argv[2:]
    if cmd == 'start':
        start()
    elif cmd == 'foto':
        foto(*args[:1])
    elif cmd == 'klik':
        stuur('click %d %d%s' % (int(args[0]), int(args[1]), ' right' if args[2:3] == ['rechts'] else ''))
        print('ok')
    elif cmd == 'cel':
        cel(int(args[0]), int(args[1]), args[2:3] == ['rechts'])
    elif cmd == 'kaart':
        kaart(*args[:4])
    elif cmd == 'beweeg':
        stuur('move %d %d' % (int(args[0]), int(args[1])))
        print('ok')
    elif cmd == 'toets':
        stuur('key ' + args[0])
        print('ok')
    elif cmd == 'wacht':
        stuur('wait %d' % int(args[0]))
        print('ok')
    elif cmd == 'toestand':
        toestand()
    elif cmd == 'stop':
        stop()
    else:
        print('onbekend commando:', cmd)
        print(__doc__)
        sys.exit(1)


if __name__ == '__main__':
    main()
