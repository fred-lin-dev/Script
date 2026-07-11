#!/usr/bin/env python3
"""
Téléchargement automatique de cours edX via Playwright.
Usage : python3 edx_playwright_dl.py <course_id> <dossier_sortie> [cookies.txt]
Exemple : python3 edx_playwright_dl.py "course-v1:HarvardX+CS109x+3T2024" CS109x edx_cookie.txt
"""

import sys
import os
import json
import time
import subprocess
import urllib.request
import urllib.parse
from pathlib import Path
from playwright.sync_api import sync_playwright

# ── args ─────────────────────────────────────────────────────────────────────
if len(sys.argv) < 3:
    print("Usage: python3 edx_playwright_dl.py <course_id> <dossier_sortie> [cookies.txt]")
    sys.exit(1)

COURSE_ID   = sys.argv[1]
OUTPUT_DIR  = Path(sys.argv[2])
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

# Auto-detect cookie source: Firefox profile takes priority
_FF_PROFILE = os.path.expanduser(
    "~/.mozilla/firefox/dqda2psj.default-release-1778627781849/cookies.sqlite"
)
_FF_COOKIE_CACHE = str(OUTPUT_DIR.parent / "firefox_edx_cookie.txt")

def _refresh_firefox_cookies():
    import sqlite3, shutil, tempfile
    tmp = tempfile.mktemp(suffix=".sqlite")
    shutil.copy2(_FF_PROFILE, tmp)
    conn = sqlite3.connect(tmp)
    rows = conn.execute(
        "SELECT host, isHttpOnly, path, isSecure, expiry, name, value "
        "FROM moz_cookies WHERE host LIKE '%edx%' ORDER BY host, name"
    ).fetchall()
    conn.close()
    os.unlink(tmp)
    with open(_FF_COOKIE_CACHE, "w") as f:
        f.write("# Netscape HTTP Cookie File\n")
        for host, _, path_, secure, expiry, name, value in rows:
            sub  = "TRUE" if host.startswith(".") else "FALSE"
            sec  = "TRUE" if secure else "FALSE"
            exp  = int(expiry) // 1000  # Firefox stores ms, Netscape wants seconds
            f.write(f"{host}\t{sub}\t{path_}\t{sec}\t{exp}\t{name}\t{value}\n")
    return _FF_COOKIE_CACHE

if os.path.exists(_FF_PROFILE):
    COOKIE_FILE = _refresh_firefox_cookies()
    print(f"[COOKIES] Profil Firefox détecté → {COOKIE_FILE}")
else:
    COOKIE_FILE = sys.argv[3] if len(sys.argv) > 3 else "edx_cookie.txt"
    print(f"[COOKIES] Fichier manuel → {COOKIE_FILE}")

# ── parse cookies.txt (Netscape format) ──────────────────────────────────────
def parse_cookies(path):
    cookies = []
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split("\t")
            if len(parts) < 7:
                continue
            domain, _, path_, secure, expires, name, value = parts[:7]
            cookies.append({
                "name":     name,
                "value":    value,
                "domain":   domain.lstrip("."),
                "path":     path_,
                "expires":  int(expires) if expires.isdigit() else -1,
                "httpOnly": False,
                "secure":   secure.upper() == "TRUE",
                "sameSite": "None",
            })
    return cookies

# ── refresh JWT via login_refresh (uses lms_sessionid) ───────────────────────
def refresh_jwt(cookie_file):
    """Call courses.edx.org/login_refresh with lms_sessionid to get a fresh JWT."""
    import http.cookiejar, urllib.request, time

    # Build a cookie jar from the file
    jar = http.cookiejar.MozillaCookieJar()
    try:
        jar.load(cookie_file, ignore_discard=True, ignore_expires=True)
    except Exception:
        return None

    opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar))
    req = urllib.request.Request(
        "https://courses.edx.org/login_refresh",
        method="POST",
        data=b"",
        headers={
            "Referer": "https://courses.edx.org/",
            "X-Requested-With": "XMLHttpRequest",
        },
    )
    try:
        with opener.open(req, timeout=15) as r:
            r.read()
        # Extract new JWT from response cookies
        header = sig = ""
        for c in jar:
            if c.name == "edx-jwt-cookie-header-payload":
                header = c.value
            elif c.name == "edx-jwt-cookie-signature":
                sig = c.value
        if header and sig:
            return f"{header}.{sig}"
    except Exception as e:
        print(f"    [WARN] login_refresh échoué : {e}")
    return None

# ── get JWT for API calls ─────────────────────────────────────────────────────
def get_jwt(cookie_file):
    # Try to refresh first (1h TTL on edX JWTs)
    fresh = refresh_jwt(cookie_file)
    if fresh:
        return fresh
    # Fallback: read from cookie file
    header = sig = ""
    with open(cookie_file) as f:
        for line in f:
            parts = line.strip().split("\t")
            if len(parts) < 7:
                continue
            name, value = parts[5], parts[6]
            if name == "edx-jwt-cookie-header-payload":
                header = value
            elif name == "edx-jwt-cookie-signature":
                sig = value
    return f"{header}.{sig}" if header and sig else ""

# ── get username from cookies ─────────────────────────────────────────────────
def get_username(cookie_file):
    with open(cookie_file) as f:
        for line in f:
            parts = line.strip().split("\t")
            if len(parts) >= 7 and parts[5] == "prod-edx-user-info":
                try:
                    # edX encodes backslash-escaped JSON — extract username via regex
                    import re
                    m = re.search(r'username.*?([A-Za-z0-9_]+)', parts[6])
                    if m:
                        return m.group(1)
                except:
                    pass
    return ""

# ── get video blocks from edX API ─────────────────────────────────────────────
def get_video_blocks(course_id, jwt, username):
    encoded = urllib.parse.quote(course_id, safe="")
    url = (f"https://courses.edx.org/api/courses/v2/blocks/"
           f"?course_id={encoded}&username={username}"
           f"&block_types_filter=video&depth=all"
           f"&requested_fields=display_name,lms_web_url")
    req = urllib.request.Request(url, headers={"Authorization": f"JWT {jwt}"})
    with urllib.request.urlopen(req, timeout=30) as r:
        data = json.loads(r.read())
    return list(data.get("blocks", {}).values())

# ── extract video URL via Playwright ─────────────────────────────────────────
def extract_video_url(page, jump_url, timeout=45):
    import re
    captured = []

    VIDEO_PATS = [
        r'https://[^\s"\'<>]+\.mp4[^\s"\'<>]*',
        r'https://[^\s"\'<>]+\.m3u8[^\s"\'<>]*',
        r'https://[^\s"\'<>]+\.webm[^\s"\'<>]*',
    ]
    SKIP = ["thumbnail", "poster", "preview", "logo", "avatar"]

    def scan(text):
        for pat in VIDEO_PATS:
            for m in re.finditer(pat, text):
                u = m.group(0).rstrip("\"',;")
                if not any(s in u for s in SKIP):
                    captured.append(u)

    def on_response(response):
        try:
            ct = response.headers.get("content-type", "")
            u  = response.url
            # Direct media response
            if any(ext in u for ext in [".mp4", ".m3u8", ".webm"]):
                if not any(s in u for s in SKIP):
                    captured.append(u)
                return
            # API JSON responses that may embed video URLs or YouTube IDs
            if "json" in ct or "javascript" in ct:
                body = response.text()
                if any(kw in body for kw in ["youtube_id", "encoded_video", ".mp4", ".m3u8", "brightcove"]):
                    scan(body)
                    # YouTube ID
                    for m in re.finditer(r'"youtube_id_1_0":\s*"([A-Za-z0-9_-]{11})"', body):
                        captured.append(f"https://www.youtube.com/watch?v={m.group(1)}")
        except Exception:
            pass

    page.on("response", on_response)
    try:
        page.goto(jump_url, wait_until="networkidle", timeout=timeout * 1000)
        # Dismiss popups
        for selector in ["button:has-text('Dismiss')", "button:has-text('Close')",
                         "button:has-text('close')", ".pgn__modal-close-container button"]:
            try:
                page.click(selector, timeout=1500)
            except Exception:
                pass
        page.wait_for_timeout(3000)
        # Try clicking the play button
        for selector in [".video-player button", "button[aria-label*='Play']",
                         ".play-button", "video", ".wc-OTPlayButton"]:
            try:
                page.click(selector, timeout=2000)
                page.wait_for_timeout(3000)
                break
            except Exception:
                pass
        page.wait_for_timeout(5000)
    except Exception as e:
        print(f"    [WARN] {e}")
    finally:
        page.remove_listener("response", on_response)

    return captured[0] if captured else None

# ── download with yt-dlp ──────────────────────────────────────────────────────
def download(url, output_path, cookie_file):
    cmd = [
        "yt-dlp",
        "--cookies", cookie_file,
        "--no-overwrites",
        "--write-subs", "--sub-langs", "fr,en",
        "--convert-subs", "srt",
        "--merge-output-format", "mkv",
        "-o", str(output_path),
        url,
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    return result.returncode == 0

# ── main ──────────────────────────────────────────────────────────────────────
def main():
    print(f"\n{'='*55}")
    print(f"  Cours   : {COURSE_ID}")
    print(f"  Sortie  : {OUTPUT_DIR}/")
    print(f"{'='*55}\n")

    jwt      = get_jwt(COOKIE_FILE)
    username = get_username(COOKIE_FILE)
    if not jwt or not username:
        print("[ERREUR] Impossible de lire JWT ou username depuis les cookies.")
        sys.exit(1)
    print(f"[AUTH] Utilisateur : {username}")

    print("[API] Récupération des blocs vidéo...")
    blocks = get_video_blocks(COURSE_ID, jwt, username)
    print(f"[API] {len(blocks)} vidéo(s) trouvée(s)\n")

    cookies = parse_cookies(COOKIE_FILE)

    ok = 0
    failed = []

    with sync_playwright() as p:
        browser = p.firefox.launch(headless=True)
        ctx = browser.new_context()
        ctx.add_cookies(cookies)
        page = ctx.new_page()

        for i, block in enumerate(blocks, 1):
            name     = block.get("display_name", f"Video_{i}")
            jump_url = block.get("lms_web_url", "")
            safe     = "".join(c if c.isalnum() or c in " -_" else "_" for c in name)
            out_path = OUTPUT_DIR / f"{i:02d} - {safe}.%(ext)s"

            print(f"[{i:02d}/{len(blocks)}] {name}")
            print(f"    URL : {jump_url}")

            video_url = extract_video_url(page, jump_url)

            if not video_url:
                print("    [SKIP] Aucune URL vidéo capturée\n")
                failed.append((i, name, jump_url))
                continue

            print(f"    [DL]  {video_url[:80]}...")
            success = download(video_url, out_path, COOKIE_FILE)
            if success:
                ok += 1
                print("    [OK]\n")
            else:
                print("    [ERREUR] yt-dlp a échoué\n")
                failed.append((i, name, video_url))

        page.close()
        ctx.close()
        browser.close()

    print(f"\n{'='*55}")
    print(f"  RÉSUMÉ : {ok}/{len(blocks)} vidéos téléchargées")
    if failed:
        print(f"  Échecs ({len(failed)}) :")
        for i, name, url in failed:
            print(f"    {i:02d}. {name}")
            print(f"        {url}")
    print(f"{'='*55}\n")

if __name__ == "__main__":
    main()
