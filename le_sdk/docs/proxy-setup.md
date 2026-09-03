# CORS Development Proxy

> **WARNING: Development tool only. Do not use in production.**
>
> This setup performs HTTPS man-in-the-middle interception to inject CORS
> headers. It weakens TLS security on the device for the duration of use.
> Only use on development machines with test devices/emulators. Never use
> on networks carrying real user data.

## Problem

Lattice Edge web extensions run inside an Android WebView. When an extension
calls `fetch()` to an external API, the browser engine enforces CORS. If the
API server doesn't return `Access-Control-Allow-Origin` headers, the request
is blocked. This is especially strict for extensions loaded from `file://`
origins (deployed to device storage).

## Solution

A local HTTPS interception proxy runs on the developer's machine. Connected
devices route traffic through it. The proxy intercepts HTTPS responses and
injects permissive CORS headers, allowing `fetch()` to succeed.

Two pieces:
1. **Device proxy configuration** — handled by `proxy-setup.sh`
2. **HTTPS interception proxy** — you run separately (see below)

## Prerequisites

- An HTTPS interception proxy (see [Proxy Server](#proxy-server) below)
- `adb` on PATH (or `ANDROID_HOME` set)
- A connected Android emulator or device
- The app built as a **debug** build (`flutter run` uses debug by default)

> **Release builds will NOT work with this proxy.** The debug network security
> config that trusts user-installed CAs only applies to debug builds. This is
> intentional — release builds should never trust user CAs.

## Quick Start

```bash
# Terminal 1: Configure devices (Ctrl+C to clear when done)
bash le_sdk/scripts/proxy-setup.sh

# Terminal 2: Start your proxy server on port 9090 (default)
mitmdump --listen-port 9090 -s cors_addon.py
```

On first use, install the proxy's CA certificate on the device (see
[First-Time Device Setup](#first-time-device-setup)).

## Device Configuration Script

`le_sdk/scripts/proxy-setup.sh` manages the Android system proxy setting on
connected devices. It does **not** start a proxy server — you run that
separately.

```bash
# Configure devices to use proxy on port 9090 (default)
bash le_sdk/scripts/proxy-setup.sh

# Custom port
bash le_sdk/scripts/proxy-setup.sh --port 8888

# Clear proxy from all devices (if script was killed ungracefully)
bash le_sdk/scripts/proxy-setup.sh --clear
```

**What it does:**
- Sets `adb shell settings put global http_proxy` on all connected devices
- For emulators: sets up `adb reverse` so `127.0.0.1:PORT` reaches the host
- For physical devices: uses the host machine's LAN IP
- On `Ctrl+C`: clears the proxy setting from all devices

## Proxy Server

You need an HTTPS interception proxy that can modify response headers. We
provide `cors_addon.py` for use with [mitmproxy](https://mitmproxy.org/),
but any proxy with similar capabilities will work.

### mitmproxy (recommended)

Install: `pip install mitmproxy`

Run in [reverse/regular proxy mode](https://docs.mitmproxy.org/stable/concepts-modes/#regular-proxy)
with the CORS addon:

```bash
mitmdump --listen-port 9090 -s cors_addon.py
```

The `cors_addon.py` script:
- Injects `Access-Control-Allow-*` headers into every response
- Auto-responds to `OPTIONS` preflight requests with permissive headers

To exclude domains from interception (e.g. Android system services), use
[`--ignore-hosts`](https://docs.mitmproxy.org/stable/howto-ignoredomains/):

```bash
mitmdump --listen-port 9090 -s cors_addon.py \
  --ignore-hosts '(.*\.)?googleapis\.com|(.*\.)?anduril\.com'
```

See the [mitmproxy documentation](https://docs.mitmproxy.org/stable/) for
full configuration options.

### Other proxies

Any HTTPS interception proxy that supports response header modification will
work. Requirements:
- HTTPS MITM with installable CA certificate
- Ability to add response headers via script/plugin/rule
- CLI or headless mode for scripted startup

Examples: [Charles Proxy](https://www.charlesproxy.com/),
[Whistle](https://github.com/nicevoice/whistle)

## First-Time Device Setup

The proxy's CA certificate must be installed on each device/emulator once.
This allows the proxy to decrypt and re-encrypt HTTPS traffic so it can
modify response headers.

1. Start the proxy server and `proxy-setup.sh`
2. On the device, open the browser and navigate to the proxy's cert install
   page (for mitmproxy: **http://mitm.it**)
3. Download the Android certificate
4. Go to **Settings > Security > Encryption & credentials**
5. Tap **Install a certificate > CA certificate**
6. Select the downloaded certificate file

The certificate persists across proxy restarts.

## How It Works

```
Extension (WebView)                    Proxy (developer machine)
       |                                        |
       |-- fetch("https://api.example.com") --> |
       |                                        |-- forwards to api.example.com
       |                                        |<- response (no CORS headers)
       |                                        |-- injects CORS headers
       |<- response (with CORS headers) --------|
       |
       | (browser allows the response)
```

## Security Notes

**Debug network security config (`android/app/src/debug/`):**
- Trusts user-installed CA certificates in addition to system CAs
- Only applies to debug builds — the Android build system excludes `src/debug/`
  resources from release builds automatically
- Without this, Android apps ignore user-installed CAs (API 24+)

**System proxy setting:**
- `adb shell settings put global http_proxy` affects ALL traffic on the device
- The cleanup handler in `proxy-setup.sh` clears this on `Ctrl+C`
- If the script is killed ungracefully, clear manually:
  ```bash
  bash le_sdk/scripts/proxy-setup.sh --clear
  # or directly:
  adb shell settings put global http_proxy :0
  ```

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Device hung / no internet | Proxy may be down. Clear: `bash proxy-setup.sh --clear` |
| fetch() still blocked by CORS | Verify CA cert is installed. Check proxy logs for the request. |
| TLS errors in proxy logs | CA cert not trusted. Reinstall cert or ensure app is a debug build. |
| Release build doesn't work | Expected. Only debug builds trust user CAs. This is by design. |
