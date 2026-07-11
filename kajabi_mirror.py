#!/usr/bin/env python3
"""
Mirror les pages HTML/CSS d'un cours Kajabi et remplace les embeds Wistia
par des balises <video> pointant vers les fichiers locaux.

Usage: python3 kajabi_mirror.py <URL_produit> <dossier_mirror> <dossier_videos> <cookies.txt>
"""
import sys, os, re, time, shutil, urllib.request, http.cookiejar
from pathlib import Path

PRODUCT_URL = sys.argv[1]
MIRROR_DIR  = Path(sys.argv[2])
VIDEO_DIR   = Path(sys.argv[3])
COOKIE_FILE = sys.argv[4]
BASE        = "https://stageacademy.mykajabi.com"

MIRROR_DIR.mkdir(parents=True, exist_ok=True)

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
                return r.read()
        except Exception as e:
            if i == retries - 1:
                print(f"    [ERREUR] {url}: {e}")
                return None
            time.sleep(2)

def sanitize(name):
    return re.sub(r'[\\/:*?"<>|]', "-", name).strip()

def get_all_lesson_urls(opener, product_url):
    """Returns [(post_url, title, wistia_id), ...] in order."""
    html = fetch(opener, product_url)
    if not html:
        return []
    html = html.decode("utf-8", errors="ignore")

    tokens = re.findall(
        r'<h[1-6][^>]*>(.*?)</h[1-6]>'
        r'|href="(/products/[^"]+/categories/\d+/posts/\d+)"',
        html, re.S
    )

    categories = []
    current_cat = "Introduction"
    current_posts = []
    seen_urls = set()

    for heading_raw, post_path in tokens:
        if heading_raw:
            heading = re.sub(r"<[^>]+>", "", heading_raw) \
                        .replace("&amp;", "&").replace("&#39;", "'") \
                        .replace("&nbsp;", " ").strip()
            if heading and 3 < len(heading) < 120 and "lessons completed" not in heading.lower():
                if current_posts:
                    categories.append((current_cat, current_posts))
                current_cat = heading
                current_posts = []
        elif post_path and post_path not in seen_urls:
            seen_urls.add(post_path)
            current_posts.append(BASE + post_path)

    if current_posts:
        categories.append((current_cat, current_posts))

    return categories

def get_lesson_info(opener, post_url):
    """Returns (title, wistia_id, html_bytes)."""
    html_bytes = fetch(opener, post_url)
    if not html_bytes:
        return None, None, None
    html = html_bytes.decode("utf-8", errors="ignore")

    m = re.search(r'<h1[^>]*>(.*?)</h1>', html, re.S)
    title = re.sub(r"<[^>]+>", "", m.group(1)).strip() if m else ""

    m = re.search(r'class=["\']wistia_([a-z0-9]{5,15})["\']', html)
    if not m:
        m = re.search(r'wistia_async_([a-z0-9]{5,15})', html)
    wistia_id = m.group(1) if m else None

    return title, wistia_id, html_bytes

def find_local_video(wistia_id, title):
    """Find the local MP4 file matching this lesson."""
    # Search by title similarity
    title_clean = sanitize(title).lower()
    for mp4 in VIDEO_DIR.rglob("*.mp4"):
        if title_clean[:20] in mp4.stem.lower() or mp4.stem.lower() in title_clean[:30]:
            return mp4
    return None

def build_video_map():
    """Map wistia_id → local mp4 path by matching from the kajabi script log."""
    mp4s = sorted(VIDEO_DIR.rglob("*.mp4"))
    return mp4s

def patch_html(html_bytes, wistia_id, video_rel_path, css_rel_path):
    """Replace Wistia embed with <video> tag and fix CSS path."""
    html = html_bytes.decode("utf-8", errors="ignore")

    # Fix CSS link
    html = re.sub(
        r'href="https://kajabi-app-assets\.kajabi-cdn\.com/assets/[^"]+\.css"',
        f'href="{css_rel_path}"',
        html
    )

    # Remove all external JS/CSS that won't work offline
    html = re.sub(r'<script[^>]+src="https://[^"]*"[^>]*>.*?</script>', '', html, flags=re.S)
    html = re.sub(r'<link[^>]+href="https://[^"]*"[^>]*/?>', '', html)
    html = re.sub(r'<script[^>]+type="module"[^>]*>.*?</script>', '', html, flags=re.S)

    if wistia_id and video_rel_path:
        video_tag = f'''<video controls style="width:100%;max-width:960px;margin:2rem 0" preload="metadata">
  <source src="{video_rel_path}" type="video/mp4">
</video>'''
        # Replace the wistia div
        html = re.sub(
            r'<div[^>]+wistia_' + wistia_id + r'[^>]*>.*?</div>',
            video_tag, html, flags=re.S
        )
        # Also replace any wistia async container if the above didn't match
        if wistia_id in html:
            html = re.sub(
                r'<div[^>]+class="[^"]*wistia[^"]*"[^>]*>.*?</div>',
                video_tag, html, flags=re.S, count=1
            )

    return html.encode("utf-8")

def build_index(categories_structure):
    """Generate an index.html listing all modules and lessons."""
    rows = []
    for cat_idx, (cat_name, lessons) in enumerate(categories_structure, 1):
        rows.append(f'<h2>{cat_idx:02d}. {cat_name}</h2><ol>')
        for lesson_idx, (post_url, html_path, title, has_video) in enumerate(lessons, 1):
            icon = "🎬" if has_video else "📄"
            link = html_path.name if html_path else "#"
            rows.append(f'  <li><a href="{html_path.relative_to(MIRROR_DIR) if html_path else "#"}">'
                        f'{icon} {title}</a></li>')
        rows.append("</ol>")

    content = "\n".join(rows)
    return f"""<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8">
<title>STAGE Academy — Offline</title>
<link rel="stylesheet" href="assets/core.css">
<style>
  body {{ max-width: 900px; margin: 2rem auto; padding: 0 1rem; font-family: sans-serif; }}
  h2 {{ margin-top: 2rem; border-bottom: 2px solid #eee; padding-bottom: .5rem; }}
  ol {{ line-height: 2; }}
  a {{ color: #1a73e8; text-decoration: none; }}
  a:hover {{ text-decoration: underline; }}
</style>
</head>
<body>
<h1>STAGE Academy</h1>
{content}
</body>
</html>"""

# ── Main ──────────────────────────────────────────────────────────────────────
opener = make_opener()

print(f"\n{'='*60}")
print(f"  Mirror : {PRODUCT_URL}")
print(f"  Sortie : {MIRROR_DIR}/")
print(f"{'='*60}\n")

# 1. Télécharger le CSS principal
print("[1/3] Téléchargement du CSS Kajabi...")
main_html = fetch(opener, PRODUCT_URL)
if main_html:
    css_url = re.search(
        r'href="(https://kajabi-app-assets\.kajabi-cdn\.com/assets/[^"]+\.css)"',
        main_html.decode("utf-8", errors="ignore")
    )
    assets_dir = MIRROR_DIR / "assets"
    assets_dir.mkdir(exist_ok=True)
    css_path = assets_dir / "core.css"

    if css_url:
        css_data = fetch(opener, css_url.group(1))
        if css_data:
            css_path.write_bytes(css_data)
            print(f"    [OK] {css_url.group(1)[-50:]}")
    else:
        print("    [WARN] CSS non trouvé, page basique seulement")

# 2. Récupérer la structure et mirror toutes les pages de leçons
print("\n[2/3] Mirror des pages de leçons...")
categories = get_all_lesson_urls(opener, PRODUCT_URL)
total = sum(len(posts) for _, posts in categories)
print(f"    {len(categories)} modules, {total} leçons\n")

# Build ordered list of all local videos for mapping
all_videos = sorted(VIDEO_DIR.rglob("*.mp4"))
video_idx = 0

index_structure = []
global_idx = 0

for cat_idx, (cat_name, post_urls) in enumerate(categories, 1):
    cat_dir = MIRROR_DIR / f"{cat_idx:02d} - {sanitize(cat_name)}"
    cat_dir.mkdir(exist_ok=True)
    index_lessons = []

    for lesson_idx, post_url in enumerate(post_urls, 1):
        global_idx += 1
        title, wistia_id, html_bytes = get_lesson_info(opener, post_url)
        if not title:
            title = f"Leçon {lesson_idx}"

        html_file = cat_dir / f"{lesson_idx:02d} - {sanitize(title)}.html"
        print(f"  [{global_idx:03d}/{total}] {title[:55]}", end="")

        # Find matching local video
        local_video = None
        if wistia_id and video_idx < len(all_videos):
            local_video = all_videos[video_idx]
            video_idx += 1

        if html_bytes:
            video_rel = os.path.relpath(local_video, html_file.parent) if local_video else None
            css_rel   = os.path.relpath(css_path, html_file.parent)
            patched   = patch_html(html_bytes, wistia_id, video_rel, css_rel)
            html_file.write_bytes(patched)
            print(f" → {'🎬' if local_video else '📄'} [OK]")
        else:
            print(" [SKIP]")

        index_lessons.append((post_url, html_file, title, bool(local_video)))
        time.sleep(0.3)

    index_structure.append((cat_name, index_lessons))

# 3. Générer l'index
print("\n[3/3] Génération de l'index...")
index_path = MIRROR_DIR / "index.html"
index_path.write_text(build_index(index_structure), encoding="utf-8")
print(f"    [OK] {index_path}")

print(f"\n{'='*60}")
print(f"  RÉSUMÉ : {global_idx} pages mirrorées")
print(f"  Ouvre : {index_path}")
print(f"{'='*60}\n")
