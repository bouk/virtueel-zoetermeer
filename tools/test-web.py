"""Test de webversie (build/web) in headless Chromium.

Start een lokale webserver, opent het spel, toont de console-uitvoer en voert optioneel een
invoerscript uit (hetzelfde .zms-formaat als de differentiële tests, zie docs/DIFFTEST.md;
'dump', 'seed' en 'sprites' worden in de browser overgeslagen).

Gebruik: python tools/test-web.py [script.zms] [uitvoermap]
  zonder script: wacht 15 s en maak screenshot <uitvoermap>/web.png
Omgeving: ZM_URLARGS='&debug' voor extra logging van de host.
"""
import http.server
import os
import sys
import threading
import time

from playwright.sync_api import sync_playwright

MAP = os.path.join(os.path.dirname(__file__), '..', 'build', 'web')

TOETSEN = {'Return': 'Enter', 'Escape': 'Escape', 'Left': 'ArrowLeft', 'Right': 'ArrowRight',
           'Up': 'ArrowUp', 'Down': 'ArrowDown', 'plus': '+', 'minus': '-', 'space': ' ',
           'BackSpace': 'Backspace', 'Delete': 'Delete', 'Tab': 'Tab'}


def start_server():
    class Stil(http.server.SimpleHTTPRequestHandler):
        def __init__(self, *a, **k):
            super().__init__(*a, directory=MAP, **k)

        def log_message(self, *a):
            pass
    httpd = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Stil)
    threading.Thread(target=httpd.serve_forever, daemon=True).start()
    return httpd.server_address[1]


def voer_uit(pagina, script, uitmap):
    for regel in open(script):
        f = regel.split('#')[0].split()
        if not f:
            continue
        cmd, args = f[0], f[1:]
        if cmd == 'wait':
            time.sleep(int(args[0]) / 1000)
        elif cmd == 'move':
            pagina.mouse.move(int(args[0]), int(args[1]))
        elif cmd == 'click':
            # Net als bij het origineel: de knop van links naderen (hover), dan klikken.
            x, y = int(args[0]), int(args[1])
            knop = 'right' if args[2:3] == ['right'] else 'left'
            pagina.mouse.move(x - 60, y)
            pagina.mouse.move(x, y, steps=20)
            time.sleep(0.3)
            pagina.mouse.down(button=knop)
            time.sleep(0.15)
            pagina.mouse.up(button=knop)
        elif cmd == 'key':
            pagina.keyboard.press(TOETSEN.get(args[0], args[0]))
        elif cmd == 'shot':
            pagina.screenshot(path=os.path.join(uitmap, args[0] + '.png'))
        elif cmd in ('dump', 'seed', 'sprites'):
            pass
        else:
            raise ValueError('onbekend scriptcommando: ' + regel)


def main():
    script = sys.argv[1] if len(sys.argv) > 1 else None
    uitmap = sys.argv[2] if len(sys.argv) > 2 else 'build/diff/web'
    os.makedirs(uitmap, exist_ok=True)
    poort = start_server()
    with sync_playwright() as p:
        browser = p.chromium.launch(args=['--no-sandbox'])
        pagina = browser.new_page(viewport={'width': 1024, 'height': 768})
        pagina.on('console', lambda m: print('[console.%s] %s' % (m.type, m.text)))
        pagina.on('pageerror', lambda e: print('[paginafout]', e))
        pagina.on('crash', lambda *_: print('[CRASH]'))
        # ?nolock: Playwright stuurt synthetische muisgebeurtenissen zonder relatieve beweging.
        pagina.goto('http://127.0.0.1:%d/?nolock%s' % (poort, os.environ.get('ZM_URLARGS', '').replace('?', '&')))
        if script:
            voer_uit(pagina, script, uitmap)
        else:
            time.sleep(15)
            pagina.screenshot(path=os.path.join(uitmap, 'web.png'))
        browser.close()


if __name__ == '__main__':
    main()
