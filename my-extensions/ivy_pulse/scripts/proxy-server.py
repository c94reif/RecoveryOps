#!/usr/bin/env python3


import argparse
import http.server
import os
import ssl
import sys
import urllib.error
import urllib.request


WEB_DIR_DEFAULT = os.path.join(os.path.dirname(__file__), "..", "build", "web")
PORT_DEFAULT = 8080


FORWARD_HEADERS = [
    "content-type",
    "authorization",
    "anduril-sandbox-authorization",
]


class ProxyHandler(http.server.SimpleHTTPRequestHandler):
    lattice_url = ""

    def do_OPTIONS(self):
        """Handle CORS preflight."""
        self.send_response(204)
        self._send_cors_headers()
        self.end_headers()

    def do_PUT(self):
        self._proxy_if_api() or super().do_PUT()

    def do_POST(self):
        self._proxy_if_api() or super().do_POST()

    def do_GET(self):
        self._proxy_if_api() or super().do_GET()

    def do_DELETE(self):
        self._proxy_if_api() or super().do_DELETE()

    def _proxy_if_api(self):
        if not self.path.startswith("/api/"):
            return False
        self._proxy_request()
        return True

    def _proxy_request(self):
        target_url = f"{self.lattice_url}{self.path}"
        content_length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_length) if content_length > 0 else None

        headers = {}
        for h in FORWARD_HEADERS:
            val = self.headers.get(h)
            if val:
                headers[h] = val

        req = urllib.request.Request(
            target_url,
            data=body,
            headers=headers,
            method=self.command,
        )

        print(f"[proxy] ===== INCOMING REQUEST =====")
        print(f"[proxy] {self.command} {self.path}")
        print(f"[proxy] From: {self.client_address[0]}:{self.client_address[1]}")
        print(f"[proxy] Forwarding to: {target_url}")
        print(f"[proxy] Headers forwarded: {list(headers.keys())}")
        if body:
            print(f"[proxy] Body size: {len(body)} bytes")
            print(f"[proxy] Body: {body[:500].decode('utf-8', errors='replace')}")

        try:
            ctx = ssl.create_default_context()
            with urllib.request.urlopen(req, context=ctx) as resp:
                resp_body = resp.read()
                self.send_response(resp.status)
                self._send_cors_headers()
                for key, val in resp.getheaders():
                    if key.lower() not in ("transfer-encoding", "connection"):
                        self.send_header(key, val)
                self.end_headers()
                self.wfile.write(resp_body)
                print(f"[proxy] ===== RESPONSE =====")
                print(f"[proxy] Status: {resp.status}")
                print(f"[proxy] Response headers: {dict(resp.getheaders())}")
                print(f"[proxy] Response body ({len(resp_body)} bytes): {resp_body[:500].decode('utf-8', errors='replace')}")
        except urllib.error.HTTPError as e:
            resp_body = e.read()
            self.send_response(e.code)
            self._send_cors_headers()
            self.send_header("Content-Type", e.headers.get("Content-Type", "text/plain"))
            self.end_headers()
            self.wfile.write(resp_body)
            print(f"[proxy] ===== HTTP ERROR =====")
            print(f"[proxy] Status: {e.code}")
            print(f"[proxy] Reason: {e.reason}")
            print(f"[proxy] Response headers: {dict(e.headers)}")
            print(f"[proxy] Response body: {resp_body[:500].decode('utf-8', errors='replace')}")
        except urllib.error.URLError as e:
            self.send_response(502)
            self._send_cors_headers()
            self.end_headers()
            msg = f"Proxy error: {e.reason}".encode()
            self.wfile.write(msg)
            print(f"[proxy] ===== URL ERROR =====")
            print(f"[proxy] Could not reach {target_url}")
            print(f"[proxy] Reason: {e.reason}")
        except Exception as e:
            self.send_response(502)
            self._send_cors_headers()
            self.end_headers()
            msg = f"Proxy error: {e}".encode()
            self.wfile.write(msg)
            print(f"[proxy] ===== UNEXPECTED ERROR =====")
            print(f"[proxy] Type: {type(e).__name__}")
            print(f"[proxy] Error: {e}")
            import traceback
            traceback.print_exc()

    def _send_cors_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", ", ".join(FORWARD_HEADERS))

    def log_message(self, format, *args):
        if self.path.startswith("/api/"):
            return
        super().log_message(format, *args)


def main():
    parser = argparse.ArgumentParser(description="Lattice Edge dev proxy server")
    parser.add_argument("--port", type=int, default=PORT_DEFAULT)
    parser.add_argument("--web-dir", default=WEB_DIR_DEFAULT)
    args = parser.parse_args()

    lattice_url = input("Lattice base URL to forward to (e.g. lattice-1qt68c.env.sandboxes.developer.anduril.com): ").strip()
    if not lattice_url.startswith("http"):
        lattice_url = f"https://{lattice_url}"
    lattice_url = lattice_url.rstrip("/")

    web_dir = os.path.abspath(args.web_dir)
    if not os.path.isfile(os.path.join(web_dir, "index.html")):
        print(f"Error: {web_dir}/index.html not found. Run 'flutter build web' first.")
        sys.exit(1)

    ProxyHandler.lattice_url = lattice_url
    os.chdir(web_dir)

    server = http.server.HTTPServer(("0.0.0.0", args.port), ProxyHandler)
    print(f"\nServing {web_dir} on http://0.0.0.0:{args.port}")
    print(f"Proxying /api/* -> {ProxyHandler.lattice_url}")
    print("Press Ctrl+C to stop\n")

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopped.")


if __name__ == "__main__":
    main()
