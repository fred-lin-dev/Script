#!/usr/bin/env python3
"""
Télécharge un cours Kajabi via Wistia.
Usage: python3 kajabi_dl.py <URL_produit> <dossier_sortie> <cookies.txt>
"""
import sys, os, re, json, time, subprocess, urllib.request, http.cookiejar
from pathlib import Path

PRODUCT_URL = sys.argv[1]
OUTPUT_DIR  = Path(sys.argv[2])
COOKIE_FILE = sys.argv[3]
BASE        = "https://stageacademy.mykajabi.com"

OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

def make_opener():
    jar = http.cookiejar.MozillaCookieJar()
    jar.load(COOKIE_FILE, ignore_discard=True, ignore_expires=True)
    opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar))
    opener.addheaders = [("User-Agent",
        "Mozilla/5.0 (X11; Linux x86_64; rv:128.0) Gecko/20100101 Firefox/128.0")]
    return opener

def fetch(opener, url, retries=3):
    for i in range(retries):
        try:
            with opener.open(url, timeout=20) as r:
                return r.read().decode("utf-8", errors="ignore")
        except Exception as e:
            if i == retries - 1:
                raise
            time.sleep(2)

def sanitize(name):
    return re.sub(r'[\\/:*?"<>|]', "-", name).strip()

def get_lesson_structure(opener, product_url):
    """Returns list of (category_name, [(post_url, lesson_title), ...])"""
    html = fetch(opener, product_url)

    # Find all headings and links in order
    # Build a mapping: heading → following post links
    tokens = re.findall(
        r'<h[1-6][^>]*>(.*?)</h[1-6]>'
        r'|href="(/products/[^"]+/categories/\d+/posts/\d+)"[^>]*>([^<]*)',
        html, re.S
    )

    categories = []
    current_cat = "Introduction"
    current_posts = []
    seen_urls = set()

    for heading_raw, post_path, post_text in tokens:
        if heading_raw:
            heading = re.sub(r"<[^>]+>", "", heading_raw).replace("&amp;", "&").replace("&#39;", "'").replace("&nbsp;", " ").strip()
            if heading and 3 < len(heading) < 120 and not any(x in heading.lower() for x in ["lessons completed", "instructor"]):
                if current_posts:
                    categories.append((current_cat, current_posts))
                current_cat = heading
                current_posts = []
        elif post_path:
            url = BASE + post_path
            title = post_text.strip() or post_path.split("/")[-1]
            if url not in seen_urls:
                seen_urls.add(url)
                current_posts.append((url, title))

    if current_posts:
        categories.append((current_cat, current_posts))

    return categories

def get_wistia_id(opener, post_url):
    html = fetch(opener, post_url)
    # Primary pattern: class="wistia_<id>"
    m = re.search(r'class=["\']wistia_([a-z0-9]{5,15})["\']', html)
    if m:
        return m.group(1)
    # Fallback: wistia_async_<id>
    m = re.search(r'wistia_async_([a-z0-9]{5,15})', html)
    if m:
        return m.group(1)
    # Fallback: hashed_id JSON
    m = re.search(r'"hashed_id":\s*"([a-z0-9]{5,15})"', html)
    if m:
        return m.group(1)
    return None

def get_lesson_title(opener, post_url):
    html = fetch(opener, post_url)
    # h1 is always set; <title> is JS-rendered and often absent
    m = re.search(r'<h1[^>]*>(.*?)</h1>', html, re.S)
    if m:
        return re.sub(r'<[^>]+>', '', m.group(1)).strip()
    m = re.search(r'<title>(.*?)</title>', html)
    if m:
        t = m.group(1).strip()
        return re.sub(r'\s*[|–-].*$', '', t).strip()
    return None

def download(wistia_id, output_path):
    url = f"https://fast.wistia.com/medias/{wistia_id}"
    cmd = [
        "yt-dlp", "--no-update",
        "--cookies", COOKIE_FILE,
        "-f", "hd_mp4-1080p/bestvideo[height<=1080]+bestaudio/best",
        "--merge-output-format", "mp4",
        "--no-overwrites",
        "-o", str(output_path),
        url,
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        for line in result.stderr.splitlines():
            if "ERROR" in line or "WARNING" in line:
                print(f"    [yt-dlp] {line.strip()}")
    return result.returncode == 0

# ── Main ──────────────────────────────────────────────────────────────────────
opener = make_opener()

print(f"\n{'='*60}")
print(f"  Cours   : {PRODUCT_URL}")
print(f"  Sortie  : {OUTPUT_DIR}/")
print(f"{'='*60}\n")

print("[*] Récupération de la structure du cours...")
categories = get_lesson_structure(opener, PRODUCT_URL)
total = sum(len(posts) for _, posts in categories)
print(f"[*] {len(categories)} catégories, {total} leçons\n")

ok_count = 0
fail_count = 0
failures = []

global_idx = 0
for cat_idx, (cat_name, posts) in enumerate(categories, 1):
    cat_dir = OUTPUT_DIR / f"{cat_idx:02d} - {sanitize(cat_name)}"
    cat_dir.mkdir(parents=True, exist_ok=True)
    print(f"\n── {cat_name} ({len(posts)} leçons)")

    for lesson_idx, (post_url, raw_title) in enumerate(posts, 1):
        global_idx += 1
        # Try to get better title from page
        try:
            page_title = get_lesson_title(opener, post_url) or raw_title
        except Exception:
            page_title = raw_title

        title = sanitize(page_title or f"Lesson {lesson_idx}")
        output_path = cat_dir / f"{lesson_idx:02d} - {title}.mp4"

        print(f"  [{global_idx:03d}/{total}] {title[:60]}")

        if output_path.exists():
            print(f"    [SKIP] Déjà téléchargé")
            ok_count += 1
            continue

        # Get Wistia ID
        try:
            wistia_id = get_wistia_id(opener, post_url)
        except Exception as e:
            print(f"    [ERREUR] Fetch page: {e}")
            fail_count += 1
            failures.append((global_idx, title, post_url))
            continue

        if not wistia_id:
            print(f"    [SKIP] Pas de vidéo Wistia (PDF/texte?)")
            continue

        print(f"    [DL] wistia:{wistia_id}...")
        if download(wistia_id, output_path):
            print(f"    [OK]")
            ok_count += 1
        else:
            print(f"    [ECHEC]")
            fail_count += 1
            failures.append((global_idx, title, post_url))

        time.sleep(0.5)

print(f"\n{'='*60}")
print(f"  RÉSUMÉ : {ok_count}/{total} leçons téléchargées")
if failures:
    print(f"  Échecs ({len(failures)}) :")
    for idx, title, url in failures:
        print(f"    {idx:03d}. {title}")
        print(f"        {url}")
print(f"{'='*60}\n")
