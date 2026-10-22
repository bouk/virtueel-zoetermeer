"""Start de webversie (build/web) in headless Chromium, toon de console-uitvoer en maak screenshots.

Gebruik: python tools/test-web.py [seconden] [screenshot.png]
"""
import http.server
import os
import sys
import threading
import time

from playwright.sync_api import sync_playwright

MAP = os.path.join(os.path.dirname(__file__), '..', 'build', 'web')


def server():
    class Stil(http.server.SimpleHTTPRequestHandler):
        def __init__(self, *a, **k):
            super().__init__(*a, directory=MAP, **k)

        def log_message(self, *a):
            pass
    httpd = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Stil)
    threading.Thread(target=httpd.serve_forever, daemon=True).start()
    return httpd.server_address[1]


def main():
    seconden = float(sys.argv[1]) if len(sys.argv) > 1 else 15
    shot = sys.argv[2] if len(sys.argv) > 2 else 'build/web-shot.png'
    poort = server()
    with sync_playwright() as p:
        browser = p.chromium.launch(args=['--no-sandbox'])
        pagina = browser.new_page(viewport={'width': 1024, 'height': 768})
        pagina.on('console', lambda m: print('[console.%s] %s' % (m.type, m.text)))
        pagina.on('pageerror', lambda e: print('[paginafout]', e))
        pagina.on('crash', lambda *_: print('[CRASH]'))
        pagina.goto('http://127.0.0.1:%d/%s' % (poort, os.environ.get('ZM_URLARGS', '')))
        time.sleep(seconden)
        pagina.screenshot(path=shot)
        print('status:', pagina.inner_text('#status') if pagina.is_visible('#status') else '(verborgen)')
        browser.close()


if __name__ == '__main__':
    main()
