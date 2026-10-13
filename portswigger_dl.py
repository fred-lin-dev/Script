#!/usr/bin/env python3
"""
portswigger_dl.py — Mirror hors-ligne de la Web Security Academy (PortSwigger).

Récupère les pages de cours (/web-security/**), les 273+ pages de labs, les
learning paths, puis réécrit les liens et les assets pour une lecture 100%
hors-ligne. Génère un index.html de navigation.

Particularité du site : certaines sections (listes de labs, learning paths)
sont injectées côté client via POST /api/widgets. Le script résout ces widgets
et recoud le HTML dans la page avant sauvegarde.

Usage : python3 portswigger_dl.py [dossier_sortie] [cookies.txt]
Exemple : python3 portswigger_dl.py ./portswigger portswigger.net_cookies.txt
"""

import sys, os, re, json, time, html, http.cookiejar, urllib.request, urllib.error
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor

BASE = "https://portswigger.net"
UA = ("Mozilla/5.0 (X11; Linux x86_64; rv:128.0) "
      "Gecko/20100101 Firefox/128.0")

OUT_DIR = Path(sys.argv[1] if len(sys.argv) > 1 else "portswigger").resolve()
COOKIE_FILE = sys.argv[2] if len(sys.argv) > 2 else None

# Pages d'amorçage : index officiels qui référencent tout le reste
SEEDS = [
    "/web-security",
    "/web-security/all-topics",
    "/web-security/all-materials",
    "/web-security/all-materials/detailed",
    "/web-security/all-labs",
    "/web-security/learning-paths",
    "/web-security/getting-started",
]

# Widgets à supprimer hors-ligne (invites de connexion, suivi de progression)
WIDGETS_DROP = {"academy-accountstatus", "academy-registration-footer"}

WORKERS = 4
DELAY = 0.15          # pause entre requêtes, par worker
MAX_WIDGETS = 40      # taille de lot pour /api/widgets


# ── HTTP ──────────────────────────────────────────────────────────────────────
def make_opener():
    handlers = []
    if COOKIE_FILE:
        if not os.path.isfile(COOKIE_FILE):
            sys.exit(f"[ERREUR] Fichier cookies introuvable : {COOKIE_FILE}")
        jar = http.cookiejar.MozillaCookieJar()
        jar.load(COOKIE_FILE, ignore_discard=True, ignore_expires=True)
        handlers.append(urllib.request.HTTPCookieProcessor(jar))
    opener = urllib.request.build_opener(*handlers)
    opener.addheaders = [("User-Agent", UA),
                         ("Accept-Language", "en-US,en;q=0.9")]
    return opener


OPENER = None  # initialisé dans main()


def fetch(url, retries=3, data=None, headers=None):
    """Retourne les octets de la réponse, ou None en cas d'échec."""
    for attempt in range(retries):
        try:
            req = urllib.request.Request(url, data=data)
            for k, v in (headers or {}).items():
                req.add_header(k, v)
            with OPENER.open(req, timeout=30) as r:
                return r.read()
        except urllib.error.HTTPError as e:
            if e.code in (404, 403, 410):
                return None
        except Exception:
            pass
        if attempt < retries - 1:
            time.sleep(1.5 * (attempt + 1))
    return None


# ── Widgets côté serveur ──────────────────────────────────────────────────────
WIDGET_RE = re.compile(r'<div\s+(widget-id="[^"]*"[^>]*)>\s*</div>', re.I)
ATTR_RE = re.compile(r'([a-z-]+)="([^"]*)"', re.I)


def resolve_widgets(page_path, raw_html):
    """Remplace les <div widget-id=...></div> par le HTML rendu par l'API."""
    matches = list(WIDGET_RE.finditer(raw_html))
    if not matches:
        return raw_html, 0

    specs = []           # (match, widgetId, payload) pour les widgets à résoudre
    for m in matches:
        attrs = dict(ATTR_RE.findall(m.group(1)))
        wid = attrs.get("widget-id", "")
        extra = {k: v for k, v in attrs.items()
                 if k.startswith("widget") and k != "widget-id"}
        specs.append((m, wid, {"widgetId": wid, "additionalData": extra}))

    rendered = {}        # index du match -> HTML
    todo = [(i, s) for i, (m, wid, s) in enumerate(specs) if wid not in WIDGETS_DROP]

    for start in range(0, len(todo), MAX_WIDGETS):
        batch = todo[start:start + MAX_WIDGETS]
        body = json.dumps([s for _, s in batch]).encode()
        data = fetch(f"{BASE}/api/widgets", data=body,
                     headers={"Content-Type": "application/json",
                              "Widget-Source": page_path})
        if not data:
            continue
        try:
            results = json.loads(data)
        except json.JSONDecodeError:
            continue
        # L'API renvoie les widgets dans l'ordre d'envoi
        for (idx, _), res in zip(batch, results):
            if isinstance(res, dict) and res.get("Html"):
                rendered[idx] = res["Html"]

    # Reconstruit la page en remplaçant de la fin vers le début
    out = raw_html
    for i in range(len(specs) - 1, -1, -1):
        m, wid, _ = specs[i]
        repl = rendered.get(i, "")        # widget non résolu ou droppé -> retiré
        out = out[:m.start()] + repl + out[m.end():]
    return out, len(rendered)


# ── Normalisation d'URL ───────────────────────────────────────────────────────
def normalize(href, from_path):
    """href -> chemin absolu du site (ex: /web-security/sql-injection), ou None."""
    if not href:
        return None
    href = html.unescape(href.strip())
    if href.startswith(("mailto:", "javascript:", "tel:", "data:", "#")):
        return None
    if href.startswith("//"):
        href = "https:" + href
    if href.startswith("http"):
        if not href.startswith(BASE + "/") and href != BASE:
            return None                   # lien externe
        href = href[len(BASE):] or "/"
    elif not href.startswith("/"):        # relatif
        href = os.path.normpath(os.path.join(os.path.dirname(from_path), href))
    href = href.split("#")[0]
    if not href.startswith("/"):
        return None
    if href.endswith("/index.html"):
        href = href[: -len("/index.html")]
    if len(href) > 1:
        href = href.rstrip("/")
    return href or "/"


def is_course_page(path):
    """Pages de cours à mirrorer : /web-security/** hors étapes de learning path."""
    if not (path == "/web-security" or path.startswith("/web-security/")):
        return False
    if re.search(r"\.(css|js|png|jpe?g|svg|gif|woff2?|ico|pdf|zip|json)$", path, re.I):
        return False
    # /web-security/learning-paths/<path> : on garde l'aperçu, pas les étapes
    # (contenu dupliqué des pages de thème, et navigation verrouillée par progression)
    parts = path.strip("/").split("/")
    if len(parts) > 3 and parts[1] == "learning-paths":
        return False
    if path.startswith("/web-security/dashboard"):
        return False
    return True


# ── Correspondance chemin de site -> fichier local ───────────────────────────
def local_page(path):
    """/web-security/sql-injection -> <OUT>/web-security/sql-injection.html"""
    return OUT_DIR / (path.strip("/") + ".html")


def local_asset(path):
    """/content/pswebsecacademy.css -> <OUT>/content/pswebsecacademy.css"""
    return OUT_DIR / path.split("?")[0].strip("/")


def rel(target: Path, from_file: Path):
    return os.path.relpath(target, from_file.parent).replace(os.sep, "/")


# ── Extraction de liens et d'assets ──────────────────────────────────────────
LINK_RE = re.compile(r'<a\b[^>]*?href="([^"]*)"', re.I)
ASSET_RE = re.compile(
    r'(?:href|src)="(/[^"]+?\.(?:css|js|png|jpe?g|gif|svg|woff2?|ico))(\?[^"]*)?"', re.I)
CSS_URL_RE = re.compile(r'url\(\s*["\']?([^"\')]+)["\']?\s*\)', re.I)


def page_links(path, body):
    return {p for p in (normalize(h, path) for h in LINK_RE.findall(body)) if p}


def page_assets(body):
    return {m.group(1) for m in ASSET_RE.finditer(body)}


# ── Nettoyage et réécriture du HTML ──────────────────────────────────────────
JUNK_SCRIPT_RE = re.compile(
    r'<script\b[^>]*\bsrc="(?:https?:)?//(?!portswigger\.net)[^"]*"[^>]*>\s*</script>',
    re.I)
INLINE_JUNK_RE = re.compile(
    r'<script\b[^>]*>(?:(?!</script>).)*?'
    r'(?:googletagmanager|posthog|hotjar|gtag\(|dataLayer|_paq|clarity|'
    r'piwik|munchkin|6sc\.co|zdassets)'
    r'(?:(?!</script>).)*?</script>', re.I | re.S)
NOSCRIPT_IFRAME_RE = re.compile(
    r'<noscript>\s*<iframe[^>]*(?:googletagmanager|facebook)[^>]*>.*?</noscript>',
    re.I | re.S)
PRECONNECT_RE = re.compile(
    r'<link\b[^>]*\brel="(?:preconnect|dns-prefetch)"[^>]*>', re.I)


def rewrite(path, body, mirrored_pages, mirrored_assets):
    """Nettoie les scripts tiers et pointe tous les liens/assets vers le local."""
    me = local_page(path)

    body = JUNK_SCRIPT_RE.sub("", body)
    body = INLINE_JUNK_RE.sub("", body)
    body = NOSCRIPT_IFRAME_RE.sub("", body)
    body = PRECONNECT_RE.sub("", body)

    def fix_asset(m):
        url = m.group(1)
        attr = m.group(0).split("=", 1)[0]
        if url in mirrored_assets:
            return f'{attr}="{rel(local_asset(url), me)}"'
        return f'{attr}="{BASE}{url}{m.group(2) or ""}"'

    body = ASSET_RE.sub(fix_asset, body)

    def fix_link(m):
        raw = m.group(1)
        frag = ""
        unescaped = html.unescape(raw)
        if "#" in unescaped and not unescaped.startswith("#"):
            frag = "#" + unescaped.split("#", 1)[1]
        target = normalize(raw, path)
        if target is None:
            return m.group(0)                      # externe ou ancre : inchangé
        if target in mirrored_pages:
            new = rel(local_page(target), me) + frag
        else:
            new = BASE + target + frag             # hors périmètre : lien en ligne
        return m.group(0).replace(f'href="{raw}"', f'href="{new}"')

    body = LINK_RE.sub(fix_link, body)

    banner = (
        '<div style="background:#f0f3f5;border-bottom:1px solid #d4dde3;'
        'padding:8px 16px;font:14px/1.4 sans-serif;color:#2c3a47">'
        f'Copie hors-ligne &mdash; <a href="{BASE}{path}" style="color:#06c">'
        'voir la page en ligne</a></div>')
    return body.replace("<body", banner + "<body", 1) if "<body" in body else banner + body


# ── Learning paths : reconstruction du sommaire ───────────────────────────────
def key(text):
    """Clé de rapprochement titre <-> ancre, insensible à la ponctuation.

    « Accessing an object's prototype using __proto__ » et l'ancre
    « accessing-an-object-s-prototype-using-proto » donnent la même clé.
    Retire aussi la numérotation d'étape et le suffixe « - Continued »,
    utilisés par les learning paths pour découper une section en deux.
    """
    t = html.unescape(re.sub(r"<[^>]+>", "", text)).lower().strip()
    t = re.sub(r"^\s*\d+\s*[-.]\s*", "", t)
    t = re.sub(r"\s*-\s*continued\s*$", "", t)
    return re.sub(r"[^a-z0-9]+", "-", t).strip("-")


PATH_HEADER_RE = re.compile(
    r'<span class="label[^"]*"[^>]*>(.*?)</span>.*?'
    r'<h2[^>]*>(.*?)</h2>\s*'
    r'(?:<p class="font-size-16"[^>]*>(.*?)</p>)?', re.S)


def parse_path_header(body, fallback):
    """(titre, niveau, description) d'une page de learning path.

    Ces pages titrent en <h2> (pas <h1>), précédé du badge de niveau.
    """
    m = PATH_HEADER_RE.search(body)
    if not m:
        return fallback, "", ""
    strip = lambda s: html.unescape(re.sub(r"<[^>]+>", "", s or "")).strip()
    return strip(m.group(2)) or fallback, strip(m.group(1)), strip(m.group(3))[:400]


def parse_path_contents(body):
    """[(titre_section, [(titre_étape, niveau), ...]), ...] depuis une page de path."""
    sections = []
    for det in re.findall(r"<details\b.*?</details>", body, re.S):
        m = re.search(r"<summary\b.*?<strong>(.*?)</strong>", det, re.S)
        if not m:
            continue
        section = html.unescape(re.sub(r"<[^>]+>", "", m.group(1))).strip()
        items = []
        for item in re.findall(
                r'<div class="expandable-progress-container-item.*?</div>', det, re.S):
            p = re.search(r"<p\b[^>]*>(.*?)</p>", item, re.S)
            if not p:
                continue
            inner = p.group(1)
            lvl = re.search(r'<span class="label[^"]*"[^>]*>(.*?)</span>', inner, re.S)
            level = html.unescape(re.sub(r"<[^>]+>", "", lvl.group(1))).strip() if lvl else ""
            title = re.sub(r"<span\b.*?</span>", "", inner, flags=re.S)
            title = re.sub(r"<a\b.*?</a>", "", title, flags=re.S)
            title = html.unescape(re.sub(r"<[^>]+>", "", title)).strip()
            if title:
                items.append((title, level))
        if items:
            sections.append((section, items))
    return sections


HEADING_ID_RE = re.compile(r'<h[1-6][^>]*\bid="([^"]+)"', re.I)
HEADING_RE = re.compile(r"<(h[1-6])\b[^>]*>(.*?)</\1>", re.I | re.S)
LAB_LINK_RE = re.compile(
    r'<div class="widgetcontainer-lab-link[^"]*".*?<a href="([^"]+)">(.*?)</a>', re.S)


def build_lookup(pages):
    """Index reliant un titre d'étape de learning path à une cible locale.

    Quatre sources, par ordre de précision décroissante : titre de lab,
    titre de page (h1), ancre de section, texte de titre sans ancre.
    """
    labs, titles, anchors, headings = {}, {}, {}, {}
    for path, body in pages.items():
        for hid in HEADING_ID_RE.findall(body):
            anchors.setdefault(key(hid), (path, hid))
        for tag, txt in HEADING_RE.findall(body):
            k = key(txt)
            if not k:
                continue
            (titles if tag.lower() == "h1" else headings).setdefault(k, path)
        for href, title in LAB_LINK_RE.findall(body):
            tgt = normalize(href, path)
            k = key(title)
            if k and tgt:
                labs.setdefault(k, tgt)
    return {"labs": labs, "titles": titles, "anchors": anchors, "headings": headings}


def resolve_step(title, pages, lookup):
    """Titre d'étape -> (chemin_site, ancre) le plus probable, ou (None, None)."""
    k = key(title)
    tgt = lookup["labs"].get(k)
    if tgt and tgt in pages:
        return tgt, ""
    tgt = lookup["titles"].get(k)
    if tgt:
        return tgt, ""
    if k in lookup["anchors"]:
        path, hid = lookup["anchors"][k]
        return path, "#" + hid
    tgt = lookup["headings"].get(k)
    if tgt:
        return tgt, ""
    direct = "/web-security/" + k
    return (direct, "") if direct in pages else (None, None)


# ── Index local ───────────────────────────────────────────────────────────────
INDEX_CSS = """
:root{color-scheme:light}
*{box-sizing:border-box}
body{margin:0;font:16px/1.55 -apple-system,Segoe UI,Roboto,sans-serif;color:#1c2b36;background:#fff}
header{background:#14212b;color:#fff;padding:2rem 1.5rem}
header h1{margin:0 0 .4rem;font-size:1.7rem}
header p{margin:0;opacity:.75;font-size:.95rem}
main{max-width:1100px;margin:0 auto;padding:1.5rem}
nav.toc{display:flex;gap:.5rem;flex-wrap:wrap;margin:0 0 2rem}
nav.toc a{background:#eef2f5;border-radius:4px;padding:.4rem .8rem;font-size:.9rem;
  text-decoration:none;color:#14212b}
nav.toc a:hover{background:#d8e2e9}
h2{margin:2.4rem 0 1rem;padding-bottom:.45rem;border-bottom:2px solid #e6ecf0;font-size:1.3rem}
h3{margin:1.6rem 0 .5rem;font-size:1.05rem}
a{color:#0a66c2}
ul{margin:.3rem 0 1rem;padding-left:1.2rem}
li{margin:.18rem 0}
.lvl{display:inline-block;font-size:.68rem;font-weight:700;letter-spacing:.03em;
  padding:.1rem .4rem;border-radius:3px;margin-left:.4rem;vertical-align:1px}
.APPRENTICE{background:#d8f2d8;color:#1d6b1d}
.PRACTITIONER{background:#ffe7c7;color:#8a4b00}
.EXPERT{background:#ffd9d9;color:#9b1c1c}
.missing{color:#7a8a99}
.cols{columns:2;column-gap:2.5rem}
@media(max-width:700px){.cols{columns:1}}
footer{padding:2rem 1.5rem;color:#6b7a89;font-size:.85rem;border-top:1px solid #e6ecf0;
  margin-top:2rem}
"""


def build_index(pages, paths_contents, lookup, stats):
    idx = OUT_DIR / "index.html"

    def link(path, label, extra=""):
        if path in pages:
            return f'<a href="{rel(local_page(path), idx)}{extra}">{html.escape(label)}</a>'
        return f'<span class="missing">{html.escape(label)}</span>'

    out = ["<!DOCTYPE html><html lang=fr><head><meta charset=utf-8>",
           "<meta name=viewport content='width=device-width,initial-scale=1'>",
           "<title>Web Security Academy — copie hors-ligne</title>",
           f"<style>{INDEX_CSS}</style></head><body>",
           "<header><h1>Web Security Academy</h1>",
           f"<p>Copie hors-ligne &middot; {stats['pages']} pages &middot; "
           f"{stats['labs']} labs &middot; {stats['paths']} learning paths &middot; "
           f"{time.strftime('%d/%m/%Y')}</p></header><main>",
           "<nav class=toc>",
           "<a href='#paths'>Learning paths</a>",
           "<a href='#topics'>Tous les thèmes</a>",
           "<a href='#labs'>Tous les labs</a>",
           "<a href='#pages'>Index des pages</a></nav>"]

    # Learning paths, avec sommaire reconstruit
    out.append("<h2 id=paths>Learning paths</h2>")
    for p_path, title, level, desc, sections in paths_contents:
        badge = f"<span class='lvl {html.escape(level)}'>{html.escape(level)}</span>" \
            if level else ""
        out.append(f"<h3>{link(p_path, title)}{badge}</h3>")
        if desc:
            out.append(f"<p style='margin:.2rem 0 .6rem;color:#5b6b7a;font-size:.9rem'>"
                       f"{html.escape(desc)}</p>")
        for section, items in sections:
            out.append(f"<p style='margin:.6rem 0 .1rem'><strong>{html.escape(section)}"
                       "</strong></p><ul>")
            for step_title, level in items:
                tgt, frag = resolve_step(step_title, pages, lookup)
                badge = f"<span class='lvl {html.escape(level)}'>{html.escape(level)}</span>" \
                    if level else ""
                if tgt:
                    out.append(f"<li>{link(tgt, step_title, frag)}{badge}</li>")
                else:
                    out.append(f"<li><span class=missing>{html.escape(step_title)}"
                               f"</span>{badge}</li>")
            out.append("</ul>")

    # Pages d'index officielles
    out.append("<h2 id=topics>Index officiels</h2><ul>")
    for p, label in [("/web-security", "Accueil Web Security Academy"),
                     ("/web-security/getting-started", "Getting started"),
                     ("/web-security/all-topics", "Tous les thèmes"),
                     ("/web-security/all-materials", "Tous les supports"),
                     ("/web-security/all-materials/detailed", "Tous les supports (vue détaillée)"),
                     ("/web-security/all-labs", "Tous les labs"),
                     ("/web-security/learning-paths", "Learning paths")]:
        out.append(f"<li>{link(p, label)}</li>")
    out.append("</ul>")

    # Labs regroupés par thème
    lab_pages = sorted(p for p in pages if re.search(r"/lab-", p))
    out.append(f"<h2 id=labs>Labs ({len(lab_pages)})</h2>")
    by_topic = {}
    for p in lab_pages:
        by_topic.setdefault("/".join(p.strip("/").split("/")[1:-1]) or "divers", []).append(p)
    for topic in sorted(by_topic):
        out.append(f"<h3>{html.escape(topic)}</h3><ul>")
        for p in by_topic[topic]:
            m = re.search(r"<h1[^>]*>(.*?)</h1>", pages[p], re.S)
            label = html.unescape(re.sub(r"<[^>]+>", "", m.group(1))).strip() if m \
                else p.split("/")[-1]
            out.append(f"<li>{link(p, label)}</li>")
        out.append("</ul>")

    # Index brut de toutes les pages
    other = sorted(p for p in pages if p not in lab_pages)
    out.append(f"<h2 id=pages>Toutes les pages de cours ({len(other)})</h2><div class=cols><ul>")
    for p in other:
        m = re.search(r"<h1[^>]*>(.*?)</h1>", pages[p], re.S)
        label = html.unescape(re.sub(r"<[^>]+>", "", m.group(1))).strip() if m else p
        out.append(f"<li>{link(p, label or p)}</li>")
    out.append("</ul></div>")

    out.append("<footer>Contenu &copy; PortSwigger Ltd. Copie personnelle hors-ligne. "
               "Les labs interactifs nécessitent une connexion : les liens "
               "&laquo;&nbsp;Access the lab&nbsp;&raquo; restent en ligne.</footer>")
    out.append("</main></body></html>")
    idx.write_text("\n".join(out), encoding="utf-8")
    return idx


# ── Programme principal ──────────────────────────────────────────────────────
def banner(title):
    print(f"\n{'=' * 60}\n {title}\n{'=' * 60}\n")


def main():
    global OPENER
    OPENER = make_opener()
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    banner(f"PortSwigger Web Security Academy -> {OUT_DIR}")
    if COOKIE_FILE:
        print(f"[INFO] Cookies : {COOKIE_FILE}")
    else:
        print("[INFO] Sans cookies (le contenu de l'Academy est public).")

    # ÉTAPE 1 — Crawl : découverte + téléchargement + résolution des widgets
    banner("ÉTAPE 1/4 — Crawl des pages de cours")
    pages = {}                       # chemin_site -> html (widgets résolus)
    assets = set()
    queue = [p for p in SEEDS]
    seen = set(queue)
    done = 0

    def grab(path):
        data = fetch(BASE + path)
        time.sleep(DELAY)
        if not data:
            return path, None, 0
        body = data.decode("utf-8", "ignore")
        body, nw = resolve_widgets(path, body)
        return path, body, nw

    with ThreadPoolExecutor(max_workers=WORKERS) as pool:
        while queue:
            batch, queue = queue[:WORKERS * 4], queue[WORKERS * 4:]
            for path, body, nw in pool.map(grab, batch):
                done += 1
                if body is None:
                    print(f"  [{done:3d}] {path}  [ÉCHEC]")
                    continue
                pages[path] = body
                assets |= page_assets(body)
                new = 0
                for link_path in page_links(path, body):
                    if link_path not in seen and is_course_page(link_path):
                        seen.add(link_path)
                        queue.append(link_path)
                        new += 1
                flag = f" +{new}" if new else ""
                wid = f" ({nw}w)" if nw else ""
                print(f"  [{done:3d}/{len(seen):3d}] {path[:64]}{wid}{flag}")

    print(f"\n[OK] {len(pages)} pages récupérées, {len(assets)} assets référencés.")

    # ÉTAPE 2 — Assets (CSS, images, polices) + url() dans les CSS
    banner("ÉTAPE 2/4 — Téléchargement des assets")
    saved_assets = set()

    def grab_asset(url):
        data = fetch(BASE + url)
        time.sleep(DELAY)
        if not data:
            return url, None
        return url, data

    pending, depth = set(assets), 0
    while pending and depth < 3:
        with ThreadPoolExecutor(max_workers=WORKERS) as pool:
            results = list(pool.map(grab_asset, sorted(pending)))
        nxt = set()
        for url, data in results:
            if data is None:
                print(f"  [SKIP] {url}")
                continue
            dest = local_asset(url)
            dest.parent.mkdir(parents=True, exist_ok=True)
            if url.lower().endswith(".css"):
                css = data.decode("utf-8", "ignore")
                for ref in CSS_URL_RE.findall(css):
                    sub = normalize(ref, url)
                    if sub and re.search(r"\.(woff2?|ttf|eot|png|jpe?g|gif|svg)$", sub, re.I):
                        if sub not in saved_assets:
                            nxt.add(sub)
                        css = css.replace(ref, rel(local_asset(sub), dest))
                data = css.encode("utf-8")
            dest.write_bytes(data)
            saved_assets.add(url)
            print(f"  [OK] {url}")
        pending = nxt - saved_assets
        depth += 1

    print(f"\n[OK] {len(saved_assets)} assets enregistrés.")

    # ÉTAPE 3 — Réécriture et écriture des pages
    banner("ÉTAPE 3/4 — Réécriture des liens et écriture sur disque")
    mirrored = set(pages)
    for path, body in pages.items():
        dest = local_page(path)
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text(rewrite(path, body, mirrored, saved_assets), encoding="utf-8")
    print(f"[OK] {len(pages)} pages écrites sous {OUT_DIR}/")

    # ÉTAPE 4 — Index de navigation avec sommaire des learning paths
    banner("ÉTAPE 4/4 — Génération de l'index")
    lookup = build_lookup(pages)

    paths_contents = []
    for p in sorted(x for x in pages
                    if x.startswith("/web-security/learning-paths/")):
        body = pages[p]
        title, level, desc = parse_path_header(body, p.split("/")[-1])
        paths_contents.append((p, title, level, desc, parse_path_contents(body)))
    paths_contents.sort(key=lambda x: (
        ["APPRENTICE", "PRACTITIONER", "EXPERT"].index(x[2])
        if x[2] in ("APPRENTICE", "PRACTITIONER", "EXPERT") else 3, x[1].lower()))

    stats = {"pages": len(pages),
             "labs": sum(1 for p in pages if "/lab-" in p),
             "paths": len(paths_contents)}
    idx = build_index(pages, paths_contents, lookup, stats)

    banner("RÉSUMÉ")
    total = sum(f.stat().st_size for f in OUT_DIR.rglob("*") if f.is_file())
    print(f" Pages de cours   : {stats['pages']}")
    print(f" dont labs        : {stats['labs']}")
    print(f" Learning paths   : {stats['paths']}")
    print(f" Assets           : {len(saved_assets)}")
    print(f" Taille totale    : {total / 1024 / 1024:.1f} Mo")
    print(f"\n Ouvre : file://{idx}\n")


if __name__ == "__main__":
    main()
