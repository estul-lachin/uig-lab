#!/usr/bin/env python3
"""Build the static showcase for lab.uig.me into site/.

Reads labs/*/lab.conf, labs/*/README.md, labs/*/screenshots/ and progress.jsonl. Never reads check.sh or
solution/ (except for the final leak check, which makes sure none of their content ended up in the output).

Usage: python3 tools/build_site.py [--progress PATH] [--out DIR]
"""

import argparse
import html
import json
import posixpath
import re
import shutil
import sys
from datetime import datetime
from pathlib import Path

import markdown

REPO_URL = "https://github.com/estul-lachin/uig-lab"
RAW_URL = "https://raw.githubusercontent.com/estul-lachin/uig-lab/main"
PROFILE_URL = "https://github.com/estul-lachin"
SITE_URL = "https://lab.uig.me"
SITE_DESCRIPTION = ("Hands-on IT labs I have built and passed, each a resettable Docker environment "
                    "with automated checks.")

ROOT = Path(__file__).resolve().parent.parent
CATEGORIES = {
    "linux": "Linux",
    "network": "Network",
    "security": "Security",
    "web": "Web",
    "db": "Databases",
    "cloud": "Cloud",
    "misc": "Misc",
}
CONF_DEFAULTS = {
    "TITLE": "", "SUMMARY": "", "CATEGORY": "misc", "TAGS": "", "SOURCE": "",
    "SERVICE": "main", "CLEANUP_CMD": "", "PUBLIC": "yes",
}
MIN_LEAK_LINE = 20  # shorter lines (fi, }, set -e ...) are too generic to compare
SCREENSHOTS = "screenshots"  # per-lab folder, copied to the site as is
IMAGE_SUFFIXES = {".png", ".jpg", ".jpeg", ".gif", ".webp"}
MAX_IMAGE_BYTES = 1024 * 1024  # larger screenshots get a warning: resize them first

e = html.escape


def fail(msg):
    print(f"build_site: error: {msg}", file=sys.stderr)
    sys.exit(1)


# ---------------------------------------------------------------- inputs

CONF_LINE = re.compile(
    r"""^\s*([A-Z_][A-Z0-9_]*)=(?:"((?:[^"\\]|\\.)*)"|'([^']*)'|([^\s"'#]*))\s*(?:#.*)?$"""
)


def parse_conf(path):
    conf = dict(CONF_DEFAULTS)
    for no, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        m = CONF_LINE.match(line)
        if not m:
            print(f"build_site: warning: {path}:{no}: ignoring line {line!r}", file=sys.stderr)
            continue
        key, dq, sq, bare = m.groups()
        if dq is not None:
            value = re.sub(r'\\([\\"$`])', r"\1", dq)
        else:
            value = sq if sq is not None else bare
        conf[key] = value
    conf["SERVICE"] = conf["SERVICE"] or "main"
    conf["PUBLIC"] = conf["PUBLIC"] or "yes"
    return conf


def parse_time(s):
    s = s.strip()
    if s.endswith("Z"):
        s = s[:-1] + "+00:00"
    s = re.sub(r"([+-]\d{2})(\d{2})$", r"\1:\2", s)  # -0600 -> -06:00
    return datetime.fromisoformat(s)


def load_progress(path):
    records = []
    if not path.exists():
        return records
    for no, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if not line.strip():
            continue
        try:
            rec = json.loads(line)
            rec["_time"] = parse_time(rec["passed_at"])
            rec["lab"] = str(rec["lab"])
        except (ValueError, KeyError, TypeError) as exc:
            fail(f"{path}:{no}: invalid progress record ({exc})")
        records.append(rec)
    return records


def load_labs(progress):
    labs = {}
    for conf_path in sorted((ROOT / "labs").glob("*/lab.conf")):
        name = conf_path.parent.name
        conf = parse_conf(conf_path)
        if conf["PUBLIC"] != "yes":
            continue
        readme = conf_path.parent / "README.md"
        passes = sorted((r for r in progress if r["lab"] == name), key=lambda r: r["_time"])
        labs[name] = {
            "name": name,
            "conf": conf,
            "readme": readme.read_text(encoding="utf-8") if readme.exists() else "",
            "passes": passes,
        }
    return labs


# ---------------------------------------------------------------- README rendering

def clean_readme(text):
    text = re.sub(r"<!--.*?-->", "", text, flags=re.S)
    lines = text.splitlines()
    for i, line in enumerate(lines):  # drop the first H1: the page header shows the title
        if line.strip():
            if re.match(r"#\s", line):
                del lines[i]
            break
    # Drop "## " sections with an empty body (e.g. "My notes" before I write them).
    out, section = [], []
    for line in lines + ["## "]:
        if line.startswith("## "):
            if section and (not section[0].startswith("## ") or any(l.strip() for l in section[1:])):
                out.extend(section)
            section = [line]
        else:
            section.append(line)
    text = "\n".join(out)
    # Let markdown render inside <details> (hint lists), keeping it collapsible.
    text = re.sub(r"<details(?![^>]*markdown=)([^>]*)>", r'<details markdown="1"\1>', text)
    return text


def rewrite_links(body, name):
    """Point relative links in a lab README at the repo on GitHub.

    Links into the lab's screenshots/ folder stay relative: that folder is copied next to the page.
    Other relative images point at the raw file, since a GitHub blob URL is an HTML page, not an image.
    """
    def fix(m):
        attr, url = m.group(1), m.group(2)
        if re.match(r"^([a-z][a-z0-9+.-]*:|#|/)", url, re.I):
            return m.group(0)
        path = posixpath.normpath(posixpath.join("labs", name, html.unescape(url)))
        if path.startswith(".."):
            return m.group(0)
        if path.startswith(f"labs/{name}/{SCREENSHOTS}/"):
            return m.group(0)
        if attr == "src":
            return f'{attr}="{e(f"{RAW_URL}/{path}")}"'
        kind = "tree" if url.endswith("/") or path == f"labs/{name}" else "blob"
        return f'{attr}="{e(f"{REPO_URL}/{kind}/main/{path}")}"'
    return re.sub(r'\b(href|src)="([^"]*)"', fix, body)


def copy_screenshots(name, out):
    """Copy labs/<name>/screenshots/ images to the lab's page folder."""
    src = ROOT / "labs" / name / SCREENSHOTS
    if not src.is_dir():
        return
    for f in sorted(src.rglob("*")):
        if not f.is_file() or f.name.startswith("."):
            continue
        rel = f.relative_to(ROOT).as_posix()
        if f.suffix.lower() not in IMAGE_SUFFIXES:
            print(f"build_site: warning: {rel}: not an image ({', '.join(sorted(IMAGE_SUFFIXES))}), skipped",
                  file=sys.stderr)
            continue
        if f.stat().st_size > MAX_IMAGE_BYTES:
            print(f"build_site: warning: {rel} is {f.stat().st_size // 1024} KB; "
                  f"shrink it (./lab shot does that)", file=sys.stderr)
        dest = out / "labs" / name / SCREENSHOTS / f.relative_to(src)
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(f, dest)


def render_readme(text, name):
    md = markdown.Markdown(extensions=["extra", "sane_lists"], output_format="html")
    return rewrite_links(md.convert(clean_readme(text)), name)


# ---------------------------------------------------------------- pages

def fmt_date(dt):
    return dt.strftime("%Y-%m-%d")


def page(title, body, depth, current="", path="", description=SITE_DESCRIPTION):
    # depth = how deep the page sits below the site root; None = absolute links (404 page,
    # which GitHub Pages serves at any missing URL). path = the page's URL path, for link previews.
    rel = "/" if depth is None else "../" * depth
    nav = [("Labs", rel or "./", "home"),
           ("Timeline", f"{rel}timeline/", "timeline")]
    links = "".join(
        f'<a href="{href}"{" aria-current=\"page\"" if key == current else ""}>{label}</a>'
        for label, href, key in nav
    )
    full_title = "uig-lab" if title == "uig-lab" else f"{title} · uig-lab"
    return f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{e(full_title)}</title>
<meta name="description" content="{e(description)}">
<meta property="og:type" content="website">
<meta property="og:site_name" content="uig-lab">
<meta property="og:title" content="{e(full_title)}">
<meta property="og:description" content="{e(description)}">
<meta property="og:url" content="{e(f"{SITE_URL}/{path}")}">
<meta name="twitter:card" content="summary">
<link rel="stylesheet" href="{rel}style.css">
</head>
<body>
<header class="site-header">
  <div class="wrap">
    <a class="brand" href="{rel or './'}">uig-lab</a>
    <nav>{links}</nav>
  </div>
</header>
<main class="wrap">
{body}
</main>
<footer class="site-footer">
  <div class="wrap">
    <a href="{PROFILE_URL}">github.com/estul-lachin</a> ·
    <a href="{REPO_URL}">source</a>
  </div>
</footer>
</body>
</html>
"""


def tags_html(conf):
    tags = conf["TAGS"].split()
    if not tags:
        return ""
    return '<ul class="tags">' + "".join(f"<li>{e(t)}</li>" for t in tags) + "</ul>"


def category_name(cat):
    return CATEGORIES.get(cat, cat.capitalize() or "Misc")


def build_home(labs):
    passed = [l for l in labs.values() if l["passes"]]
    parts = [
        '<section class="intro">',
        "<h1>Hands-on IT labs</h1>",
        "<p>Every skill I learn becomes a small Docker lab with automated checks, which I can reset and "
        "redo at any time. A lab appears here once I have passed it myself.</p>",
        "</section>",
    ]
    latest = max((p["_time"] for l in passed for p in l["passes"]), default=None)
    stats = [f'<div class="stat"><span class="num">{len(passed)}</span>'
             f'<span class="label">{"lab" if len(passed) == 1 else "labs"} passed</span></div>']
    if latest:
        stats.append(f'<div class="stat"><span class="num">{fmt_date(latest)}</span>'
                     f'<span class="label">latest pass</span></div>')
    parts.append('<section class="stats">' + "".join(stats) + "</section>")

    # Only passed labs count; unpassed labs are never shown or counted.
    cats = sorted({l["conf"]["CATEGORY"] for l in passed},
                  key=lambda c: list(CATEGORIES).index(c) if c in CATEGORIES else 99)
    rows = []
    for cat in cats:
        done = sum(1 for l in passed if l["conf"]["CATEGORY"] == cat)
        rows.append(f'<li><a href="#cat-{e(cat)}">{e(category_name(cat))}</a>'
                    f'<span class="count">{done}</span></li>')
    if rows:
        parts.append('<section><h2 class="small-heading">Passed by category</h2>'
                     '<ul class="by-category">' + "".join(rows) + "</ul></section>")

    if not passed:
        parts.append('<p class="empty">No labs passed yet. Check back soon.</p>')
    for cat in cats:
        in_cat = sorted((l for l in passed if l["conf"]["CATEGORY"] == cat),
                        key=lambda l: l["passes"][0]["_time"], reverse=True)
        if not in_cat:
            continue
        cards = []
        for l in in_cat:
            c, n = l["conf"], len(l["passes"])
            times = f' · {n} passes' if n > 1 else ""
            cards.append(
                f'<article class="card"><h3><a href="labs/{e(l["name"])}/">{e(c["TITLE"] or l["name"])}</a></h3>'
                f'<p>{e(c["SUMMARY"])}</p>{tags_html(c)}'
                f'<p class="status">✓ Passed {fmt_date(l["passes"][0]["_time"])}{times}</p></article>'
            )
        parts.append(f'<section class="category" id="cat-{e(cat)}"><h2>{e(category_name(cat))}</h2>'
                     f'<div class="cards">{"".join(cards)}</div></section>')
    return page("uig-lab", "\n".join(parts), 0, "home")


def build_lab(lab):
    c, passes, name = lab["conf"], lab["passes"], lab["name"]
    latest = passes[-1]
    meta = [f'<span>{e(category_name(c["CATEGORY"]))}</span>']
    if c["SOURCE"]:
        meta.append(f'<span>Learned from: {e(c["SOURCE"])}</span>')
    checks = "".join(f"<li>{e(str(d))}</li>" for d in latest.get("checks", []))
    body = f"""<article class="lab">
<header class="lab-header">
  <p class="meta">{" · ".join(meta)}</p>
  <h1>{e(c["TITLE"] or name)}</h1>
  <p class="summary">{e(c["SUMMARY"])}</p>
  {tags_html(c)}
</header>
<aside class="record">
  <dl>
    <div><dt>First pass</dt><dd>{fmt_date(passes[0]["_time"])}</dd></div>
    <div><dt>Latest pass</dt><dd>{fmt_date(latest["_time"])}</dd></div>
    <div><dt>Passes</dt><dd>{len(passes)}</dd></div>
  </dl>
  <a href="{e(f"{REPO_URL}/tree/main/labs/{name}")}">View the lab on GitHub →</a>
</aside>
<div class="readme">
{render_readme(lab["readme"], name)}
</div>
<section class="checks">
  <h2>Checks passed</h2>
  <p class="note">From my latest pass on {fmt_date(latest["_time"])}: {latest.get("pass", len(latest.get("checks", [])))}/{latest.get("total", "?")}</p>
  <ul>{checks}</ul>
</section>
</article>"""
    return page(c["TITLE"] or name, body, 2, path=f"labs/{name}/",
                description=c["SUMMARY"] or SITE_DESCRIPTION)


def build_timeline(labs):
    events = sorted(((p, l) for l in labs.values() for p in l["passes"]),
                    key=lambda x: x[0]["_time"], reverse=True)
    if not events:
        items = '<p class="empty">No passes yet.</p>'
    else:
        rows = []
        for p, l in events:
            rows.append(
                f'<li><time datetime="{e(p["passed_at"])}">{fmt_date(p["_time"])}</time>'
                f'<a href="../labs/{e(l["name"])}/">{e(l["conf"]["TITLE"] or l["name"])}</a>'
                f'<span class="count">{e(str(p.get("pass", "")))}/{e(str(p.get("total", "")))} checks</span></li>'
            )
        items = '<ol class="timeline">' + "".join(rows) + "</ol>"
    body = f'<h1>Timeline</h1>\n<p class="lead">Every lab pass, newest first. Redoing a lab counts too.</p>\n{items}'
    return page("Timeline", body, 1, "timeline", path="timeline/")


def build_404():
    body = '<h1>Not found</h1><p>That page does not exist. <a href="/">Back to the labs</a>.</p>'
    return page("Not found", body, None)


# ---------------------------------------------------------------- leak check

def leak_check(out):
    """Fail if any line of a check.sh or solution/ file appears in the built site."""
    secrets = set()
    for f in list((ROOT / "labs").glob("*/check.sh")) + list((ROOT / "labs").glob("*/solution/**/*")):
        if f.is_file():
            for line in f.read_text(encoding="utf-8", errors="replace").splitlines():
                line = line.strip()
                if len(line) >= MIN_LEAK_LINE:
                    secrets.add(line)
    problems = []
    for f in out.rglob("*"):
        rel = f.relative_to(out).as_posix()
        if f.name == "check.sh" or "solution/" in rel + "/":
            problems.append(f"{rel}: forbidden file")
        if f.is_file() and f.suffix.lower() not in IMAGE_SUFFIXES:
            raw = f.read_text(encoding="utf-8", errors="replace")
            text = raw + "\n" + html.unescape(raw)
            for s in secrets:
                if s in text:
                    problems.append(f"{rel}: contains {s!r}")
    if problems:
        fail("check or solution content would be published:\n  " + "\n  ".join(problems))


# ---------------------------------------------------------------- main

def write(path, content):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def main():
    ap = argparse.ArgumentParser(description="Build the lab.uig.me showcase.")
    ap.add_argument("--progress", type=Path, default=ROOT / "progress.jsonl",
                    help="progress file to read (default: progress.jsonl)")
    ap.add_argument("--out", type=Path, default=ROOT / "site", help="output directory (default: site/)")
    args = ap.parse_args()

    labs = load_labs(load_progress(args.progress))
    out = args.out.resolve()
    if out == ROOT or ROOT.is_relative_to(out):
        fail(f"refusing to write into {out}")
    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True)

    write(out / "index.html", build_home(labs))
    write(out / "timeline" / "index.html", build_timeline(labs))
    write(out / "404.html", build_404())
    shutil.copyfile(ROOT / "tools" / "site.css", out / "style.css")
    passed = [l for l in labs.values() if l["passes"]]
    for lab in passed:
        write(out / "labs" / lab["name"] / "index.html", build_lab(lab))
        copy_screenshots(lab["name"], out)

    leak_check(out)
    print(f"Built {out}: {len(passed)} of {len(labs)} public labs passed, "
          f"{sum(len(l['passes']) for l in labs.values())} passes.")


if __name__ == "__main__":
    main()
