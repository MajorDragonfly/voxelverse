#!/usr/bin/env python3
"""Generate the reviewed project dashboard; optionally read live GitHub state.

No third-party dependencies, engine startup, git writes, API writes or automatic
progress inference. PR counts and development estimates are different metrics.
"""
import argparse
from datetime import date, datetime, timezone
from decimal import Decimal, ROUND_HALF_UP
import hashlib
from html import escape
import json
import os
from pathlib import Path
import re
import sys
from urllib.error import HTTPError, URLError
from urllib.parse import quote
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
DATA = Path("tools/workflow/project.json")
START = "<!-- PROJECT-DASHBOARD:START -->"
END = "<!-- PROJECT-DASHBOARD:END -->"
STATES = {"planned": "Geplant", "active": "In Arbeit", "delivered": "Geliefert",
          "integrated": "Im Kandidaten", "accepted": "Im Spieltest bestätigt"}
SHA = re.compile(r"[0-9a-f]{40}")
ID = re.compile(r"[A-Z][A-Z0-9]*(?:-[A-Z0-9]+)+")


def require(condition, message):
    if not condition:
        raise ValueError(message)


def text(value, label):
    require(isinstance(value, str) and bool(value.strip()), f"Missing {label}")
    return value


def read_project(root=ROOT):
    data = json.loads((root / DATA).read_text(encoding="utf-8"))
    require(isinstance(data, dict) and type(data.get("schema")) is int
            and data["schema"] == 1, "Unsupported project schema")
    date.fromisoformat(text(data.get("reviewed_on"), "reviewed_on"))
    require(re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", data.get("repository", "")),
            "Invalid repository")
    text(data.get("scope"), "scope")
    for field in ("campaign_summary", "remaining_summary", "coordination_note", "target_hardware", "target_goal"):
        text(data.get(field), field)
    acceptance = data.get("acceptance", {})
    require(acceptance.get("status") in ("pending", "accepted"), "Invalid target acceptance status")
    text(acceptance.get("summary"), "acceptance summary")
    if acceptance["status"] == "accepted":
        for field in ("evidence", "reviewer", "build_id"):
            text(acceptance.get(field), "acceptance " + field)
        require(SHA.fullmatch(acceptance.get("source_sha", "")), "Acceptance needs source SHA")
    require(type(data.get("scope_version")) is int and data["scope_version"] > 0,
            "Invalid scope version")
    require(type(data.get("coordination_issue")) is int and data["coordination_issue"] > 0,
            "Missing coordination issue")
    for field in ("main", "candidate"):
        ref = data.get(field, {})
        text(ref.get("branch"), field + " branch")
        require(SHA.fullmatch(ref.get("sha", "")), "Invalid " + field + " SHA")
        text(ref.get("evidence"), field + " evidence")
    require(type(data["candidate"].get("pr")) is int and data["candidate"]["pr"] > 0,
            "Invalid candidate PR")
    areas = data.get("areas")
    require(isinstance(areas, list) and bool(areas), "No progress areas")
    seen, weight = set(), 0
    for area in areas:
        key = text(area.get("id"), "area id")
        require(key not in seen, "Duplicate area: " + key)
        seen.add(key)
        text(area.get("title"), "area title")
        w = area.get("weight")
        require(type(w) is int and 0 < w <= 100, "Invalid weight: " + key)
        weight += w
        low, high = area.get("low"), area.get("high")
        require(type(low) is int and type(high) is int and 0 <= low <= high <= 100,
                "Invalid estimate: " + key)
        for name in ("achieved", "remaining", "evidence"):
            text(area.get(name), key + " " + name)
    require(weight == 100, "Area weights must sum to 100")
    seen_prs = set()
    for entry in data.get("included", []) + data.get("integration_inputs", []):
        number = entry.get("pr")
        require(type(number) is int and number > 0 and number not in seen_prs,
                "Invalid/duplicate included PR")
        seen_prs.add(number)
        require(SHA.fullmatch(entry.get("head", "")), "Included PR needs exact head")
    deliveries = data.get("deliveries", [])
    require(isinstance(deliveries, list), "Invalid deliveries")
    packets = {}
    for item in deliveries:
        key = item.get("id", "")
        require(ID.fullmatch(key) and key not in packets, "Invalid/duplicate packet: " + key)
        packets[key] = item
        require(item.get("status") in STATES, "Unknown packet status: " + key)
        require(item.get("area") in seen, "Unknown area: " + key)
        for name in ("title", "limits"):
            text(item.get(name), key + " " + name)
        require(isinstance(item.get("depends_on"), list)
                and len(set(item["depends_on"])) == len(item["depends_on"]),
                "Invalid dependencies: " + key)
        if item["status"] in ("delivered", "integrated", "accepted"):
            number = item.get("pr")
            require(type(number) is int and number > 0 and number not in seen_prs,
                    "Invalid/duplicate delivery PR")
            seen_prs.add(number)
            require(SHA.fullmatch(item.get("head", "")), "Delivery needs exact head: " + key)
            text(item.get("evidence"), key + " evidence")
        if item["status"] in ("integrated", "accepted"):
            require(SHA.fullmatch(item.get("integrated_sha", "")),
                    "Integration needs exact commit: " + key)
        if item["status"] == "accepted":
            for name in ("acceptance_evidence", "accepted_by", "build_id"):
                text(item.get(name), key + " " + name)
    visiting, done = set(), set()

    def visit(key):
        require(key in packets, "Unknown dependency: " + key)
        require(key not in visiting, "Dependency cycle: " + key)
        if key in done:
            return
        visiting.add(key)
        for dependency in packets[key]["depends_on"]:
            visit(dependency)
        visiting.remove(key)
        done.add(key)

    for key in packets:
        visit(key)
    for name in ("priorities", "blockers"):
        require(isinstance(data.get(name), list) and bool(data[name]), "Missing " + name)
        for value in data[name]:
            text(value, name)
    return data


def score(data):
    low = sum(Decimal(a["weight"]) * a["low"] for a in data["areas"]) / 100
    high = sum(Decimal(a["weight"]) * a["high"] for a in data["areas"]) / 100
    middle = ((low + high) / 2).quantize(Decimal("1"), rounding=ROUND_HALF_UP)
    return low, high, middle


def number(value):
    value = format(value, "f").rstrip("0").rstrip(".") if "." in format(value, "f") else str(value)
    return value.replace(".", ",")


def md(value):
    # Never turn untrusted PR titles into links, mentions, HTML or new table rows.
    value = escape(str(value), quote=False).replace("\r", " ").replace("\n", " ")
    for char in ("\\", "|", "[", "]", "`", "*", "_", "#"):
        value = value.replace(char, "\\" + char)
    return value.replace("@", "&#64;")


def url(data, path):
    return f"https://github.com/{data['repository']}/{path}"


def acceptance_line(data):
    a = data["acceptance"]
    result = a["summary"]
    if a["status"] == "accepted":
        result += f" [Abnahmebeleg]({a['evidence']}) · Build `{a['build_id']}` · "
        result += f"Quelle `{a['source_sha']}` · Abnehmer: {md(a['reviewer'])}."
    return result


def compact(data):
    low, high, middle = score(data)
    return "\n".join([
        "### Projektfortschritt", "",
        "[![Geschätzter Entwicklungsumfang](docs/dashboard/progress.svg)](docs/PROJECT_DASHBOARD.md)", "",
        f"**Rund {middle} % entwickelt** · Schätzkorridor {number(low)}–{number(high)} % · "
        f"Bewertet am {data['reviewed_on']} · Zielumfang v{data['scope_version']}.", "",
        "Die Schätzung umfasst veröffentlichte Fachlieferungen. Integration und Spieltest-Abnahme "
        "werden separat geführt; PR-Zahl und Testanzahl erhöhen den Prozentwert nicht.", "",
        f"[Dashboard und nächste Prioritäten](docs/PROJECT_DASHBOARD.md) · "
        f"[Zentrale Chat-Koordination]({url(data, 'issues/' + str(data['coordination_issue']))}) · "
        f"[Spieltest-Kandidat #{data['candidate']['pr']}]({url(data, 'pull/' + str(data['candidate']['pr']))})",
    ])


def render_markdown(data):
    low, high, middle = score(data)
    digest = hashlib.sha256(json.dumps(data, sort_keys=True, ensure_ascii=False).encode()).hexdigest()[:12]
    lines = ["# Voxelverse – Projektübersicht", "",
             f"<!-- Generated by tools/project_dashboard.py; data {digest}. -->",
             f"Stand der Bewertung: **{data['reviewed_on']}** · Zielumfang **v{data['scope_version']}**.", "",
             "![Geschätzter Entwicklungsumfang](dashboard/progress.svg)", "",
             f"**Rund {middle} % entwickelt**, gewichteter Korridor **{number(low)}–{number(high)} %**.", "",
             data["scope"], "",
             "Manuelle Planungsschätzung einschließlich veröffentlichter Fachzweige. "
             "Keine Zeitprognose und keine Release-Abnahme. Lokale, unveröffentlichte Arbeit ist nicht erfasst. "
             "Teilaufträge innerhalb eines Bereichs erhöhen dessen Gewicht nicht.", "",
             "## Umfang und Fortschritt", "",
             "| Bereich | Gewicht | Schätzung | Vorhanden | Nächste Grenze |",
             "|---|---:|---:|---|---|"]
    for a in data["areas"]:
        lines.append(f"| [{md(a['title'])}]({a['evidence']}) | {a['weight']} % | "
                     f"{a['low']}–{a['high']} % | {md(a['achieved'])} | {md(a['remaining'])} |")
    lines += ["", "Berechnung: Summe aus Bereichsgewicht × Bereichsschätzung / 100. "
              "Der Mittelwert wird auf ganze Prozent gerundet. Neue Wünsche ändern zunächst den "
              "versionierten Zielumfang; ARCH-Pakete sind keine zusätzlichen Spielphasen.", "",
              "## Gemeinsamer Stand und Abnahme", ""]
    for name, label in (("main", "Veröffentlichtes main beim Abgleich"),
                        ("candidate", "Gemeinsamer Spieltest-Kandidat")):
        r = data[name]
        lines.append(f"- **{label}:** [{r['sha'][:12]}]({url(data, 'commit/' + r['sha'])}) "
                     f"auf `{r['branch']}`. [Übergabe]({r['evidence']}).")
    lines += ["- **Ziel-PC-Abnahme:** " + acceptance_line(data),
              "- **Referenzhardware:** " + data["target_hardware"] + ". " + data["target_goal"],
              "- **CI/Build:** [aktuelle Läufe](" + url(data, "actions") + "). "
              "Ein grüner Fachlauf ist nur ein Nachweis für dessen Quelle und Prüfumfang.", "",
              "Der Kandidat ist kein Alias für main. Die festen Referenzen oben sind ein "
              "datierter Abgleich. `python3 tools/project_dashboard.py live` erkennt veränderte Köpfe "
              "und zeigt offene PRs; es erteilt keine Freigabe.", "",
              "## Nächste drei Prioritäten", ""]
    lines += [f"{i}. {value}" for i, value in enumerate(data["priorities"][:3], 1)]
    lines += ["", "## Offene Grenzen", ""] + ["- " + x for x in data["blockers"]]
    lines += ["", "## Veröffentlichte Folgepakete", "",
              "Datierter Ausschnitt nach dem Spieltest-Kandidaten; keine Live-Belegung und keine "
              "Zählgrundlage für den Prozentwert. Abhängigkeiten beziehen sich auf diese Pakete; "
              "gemeinsame Basis ist der Kandidat oben.", "",
              "| Paket | Status | PR / fester Lieferstand | Zuerst | Offene Abnahme / Grenze |",
              "|---|---|---|---|---|"]
    for d in data["deliveries"]:
        link = f"[#{d['pr']}]({url(data, 'pull/' + str(d['pr']))}) / `{d['head'][:12]}`" if d.get("pr") else "—"
        lines.append(f"| {md(d['id'])} | {STATES[d['status']]} | {link} | "
                     f"{md(', '.join(d['depends_on'])) or '—'} | {md(d['limits'])} |")
    lines += ["", f"Bereits im festen Kandidaten enthalten: **{len(data['included'])} dokumentierte Eingänge** "
              "laut zentraler Statusdatei. Ihre offenen Fach-PRs werden bei identischem Kopf "
              "im Live-Bericht als bereits enthalten gekennzeichnet. Nachlieferungen bleiben sichtbar.", "",
              "## Effizient übergeben", "",
              f"1. [Zentrale Koordination]({url(data, 'issues/' + str(data['coordination_issue']))}) "
              "einmal zum Paketstart lesen; genau ein Integrationsbesitzer vergibt die gemeinsame Runde.",
              "2. `python3 tools/work_packet.py start PAKET-ID --owner CHAT` gibt einen kurzen Startauftrag "
              "aus dem vorhandenen Paketbrief aus. Ein lokaler Aufruf reserviert nichts.",
              "3. Nur Paketdateien und direkte Verbraucher lesen. Bei Fortsetzung denselben Kontext weiterverwenden.",
              "4. `python3 tools/validate_godot.py --changed-since BASIS_SHA --plan` bestimmt die bestehende "
              "Prüfauswahl; bei Tooling/Dokumentation den beschriebenen Fachumfang verwenden.",
              "5. `python3 tools/work_packet.py handoff PAKET-ID --base BASIS_SHA` erzeugt eine "
              "Übergabe mit tatsächlichem Branch, Commit, Tree und Diff. Ergebnisse und Grenzen ergänzen.", "",
              "Statusdaten: [`tools/workflow/project.json`](../tools/workflow/project.json). "
              "Nur der Integrationsbesitzer pflegt Bewertung/Referenzen nach einer Lieferung. "
              "`python3 tools/project_dashboard.py render` erzeugt Dashboard, README-Block und Grafik. "
              "CI prüft die Übereinstimmung und liefert zusätzlich einen Live-Bericht. "
              "Fachchats liefern ihre Evidenz im PR; sie pflegen keine Kopien der zentralen Dateien.", "",
              "Details: [Arbeitsablauf](PARALLEL_WORKFLOW.md) · [Statuspflege](PROJECT_TRACKING.md).", ""]
    return "\n".join(lines)


def render_svg(data):
    low, high, middle = score(data)
    # Fixed layout and escaped labels; standalone SVG works in GitHub's image proxy.
    rows = [("Gesamtes Ziel", low, high)] + [(a["title"], Decimal(a["low"]), Decimal(a["high"])) for a in data["areas"]]
    height = 100 + 42 * len(rows)
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="900" height="{height}" viewBox="0 0 900 {height}" role="img" aria-labelledby="title desc">',
             f'<title id="title">Voxelverse: rund {middle} Prozent entwickelt</title>',
             '<desc id="desc">Gewichtete Planungsschätzung. Dunkle Balken zeigen die Untergrenze, helle den Schätzbereich. Keine Release-Abnahme.</desc>',
             f'<rect width="900" height="{height}" rx="14" fill="#101c30"/>',
             '<g font-family="sans-serif" fill="#edf4ff">',
             '<text x="24" y="33" font-size="20" font-weight="bold">VOXELVERSE · ENTWICKLUNGSSTAND</text>',
             f'<text x="24" y="57" font-size="13" fill="#becce0">{data["reviewed_on"]} · Zielumfang v{data["scope_version"]} · Schätzung einschließlich Fachlieferungen</text>']
    for i, (label, lo, hi) in enumerate(rows):
        y = 82 + i * 42
        parts += [f'<text x="24" y="{y+17}" font-size="14">{escape(label)}</text>',
                  f'<rect x="425" y="{y}" width="360" height="24" rx="4" fill="#28364d"/>',
                  f'<rect x="425" y="{y}" width="{hi*Decimal("3.6"):.1f}" height="24" rx="4" fill="#83d6c8"/>',
                  f'<rect x="425" y="{y}" width="{lo*Decimal("3.6"):.1f}" height="24" rx="4" fill="#279b89"/>',
                  f'<text x="802" y="{y+17}" font-size="14">{number(lo)}–{number(hi)} %</text>']
    parts.append(f'<text x="24" y="{height-12}" font-size="11" fill="#becce0">Dunkel: Untergrenze · Hell: Schätzbereich · Integration und Spieltest separat</text>')
    parts += ['</g></svg>\n']
    return "\n".join(parts)


def replace_block(original, block):
    require(original.count(START) == original.count(END) == 1, "README needs exactly one dashboard marker pair")
    begin, end = original.index(START), original.index(END)
    require(begin < end, "Reversed README dashboard markers")
    return original[:begin] + START + "\n" + block + "\n" + original[end:]


def render_status(data):
    c, m = data["candidate"], data["main"]
    return "\n".join([
        "# Aktueller Projektstand", "",
        "<!-- Generated by tools/project_dashboard.py from tools/workflow/project.json. -->",
        f"Bewertet am **{data['reviewed_on']}**. Kurzer Einstieg für Fachchats; "
        "der Integrationsbesitzer aktualisiert die gemeinsame Quelle einmal je Runde.", "",
        f"- Gemeinsamer Kandidat: `{c['branch']}`, fester Commit `{c['sha']}` "
        f"([PR #{c['pr']}]({url(data, 'pull/' + str(c['pr']))})).",
        f"- main beim Abgleich: `{m['sha']}`. Kandidat und main sind getrennte Stände.",
        "- Godot **4.6.3**, Forward+, Jolt. Regulärer Einstieg: "
        "`ui/frontend/main_menu.tscn` → `main/spherical_campaign.tscn`.",
        f"- [Zentrale Chat-Zuweisung]({url(data, 'issues/' + str(data['coordination_issue']))}): "
        "einmal zum Paketstart lesen, bestehende Nutzerzuweisungen erhalten. Fehlender Eintrag bedeutet nicht frei.", "",
        "## Enthalten und offen", "",
        data["campaign_summary"] + " Die veröffentlichten Folgepakete sowie "
        "ihre festen Köpfe stehen ausschließlich im [Dashboard](PROJECT_DASHBOARD.md).", "",
        "**Enthaltener Code ist nicht automatisch vollständig abgenommen.** "
        "Fachtests, gemeinsamer Kandidat, native Exporte und Lars' Spieltest getrennt belegen. "
        + data["remaining_summary"], "",
        "Referenz-PC: " + data["target_hardware"] + ". " + data["target_goal"], "",
        "Ziel-PC-Abnahme: " + acceptance_line(data), "",
        "## Nächster Fachauftrag", "",
        "`python3 tools/work_packet.py list` zeigt vorbereitete Vorschläge. "
        "`start PAKET-ID --owner CHAT` erzeugt den kurzen Startauftrag. "
        "Nur Paketdateien und direkte Verbraucher lesen; bei Fortsetzung denselben Kontext nutzen.", "",
        "[Dashboard](PROJECT_DASHBOARD.md) · [Nächste Runde](NEXT_PARALLEL_WORK.md) · "
        "[Arbeitsablauf](PARALLEL_WORKFLOW.md) · [Statuspflege](PROJECT_TRACKING.md) · "
        "[Zielbild](../ROADMAP.md). Historische Integrationsberichte bleiben Nachweise ihres jeweiligen Stands.", ""])


def render_next(data):
    queued = [item for item in data["deliveries"] if item["status"] == "planned"]
    return "\n".join([
        "# Nächste Voxelverse-Arbeiten", "",
        "<!-- Generated by tools/project_dashboard.py from tools/workflow/project.json. -->",
        f"Bewertet am {data['reviewed_on']}. Basis und veröffentlichte Lieferungen: "
        "[Projektübersicht](PROJECT_DASHBOARD.md).", "",
        "## Prioritäten", "",
        *[f"{i}. {value}" for i, value in enumerate(data["priorities"][:3], 1)], "",
        "## Vorbereitete Pakete", "",
        "| Paket | Ergebnis | Voraussetzung |", "|---|---|---|",
        *[f"| `{item['id']}` | {md(item['title'])} | {md(', '.join(item['depends_on'])) or 'Zuweisung in #137'} |" for item in queued], "",
        "## Abgegrenzte Zuweisung", "",
        f"Die verbindliche Runde wird in [Issue #{data['coordination_issue']}]"
        f"({url(data, 'issues/' + str(data['coordination_issue']))}) geführt. "
        + data["coordination_note"], "",
        "`python3 tools/work_packet.py list` zeigt den aktuellen ausführbaren Katalog; "
        "`show PAKET-ID` oder `start PAKET-ID --owner CHAT` liefert Dateien, Grenzen und Prüfverträge. "
        "Der Integrationsbesitzer ergänzt neue kleine Briefe und prüft `conflicts` vor paralleler Zuweisung.", "",
        "Bereits gelieferte Pakete nicht neu beginnen. Der [Live-Abgleich](PROJECT_TRACKING.md) "
        "erkennt bekannte identische PR-Köpfe im Kandidaten; ein offener PR ist keine neue Lieferung. "
        "Vollständige Ziele bleiben in der Roadmap. Fachchats liefern kurze PR-Übergaben, "
        "die zentrale Quelle pflegt nur der Integrationsbesitzer.", ""])


def render(root, data, check=False):
    outputs = {Path("docs/PROJECT_DASHBOARD.md"): render_markdown(data),
               Path("docs/dashboard/progress.svg"): render_svg(data),
               Path("docs/PROJECT_STATUS.md"): render_status(data),
               Path("docs/NEXT_PARALLEL_WORK.md"): render_next(data),
               Path("README.md"): replace_block((root / "README.md").read_text(encoding="utf-8"), compact(data))}
    stale = [str(p) for p, content in outputs.items()
             if not (root / p).exists() or (root / p).read_text(encoding="utf-8") != content]
    if check:
        require(not stale, "Stale dashboard outputs: " + ", ".join(stale) + "; run python3 tools/project_dashboard.py render")
    else:
        for p, content in outputs.items():
            (root / p).parent.mkdir(parents=True, exist_ok=True)
            (root / p).write_text(content, encoding="utf-8")
    return stale


def api_get(repo, path):
    require(re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", repo), "Invalid repository")
    headers = {"Accept": "application/vnd.github+json", "X-GitHub-Api-Version": "2022-11-28",
               "User-Agent": "voxelverse-project-dashboard"}
    token = os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN")
    if token:
        headers["Authorization"] = "Bearer " + token
    request = Request(f"https://api.github.com/repos/{repo}/{path}", headers=headers)
    with urlopen(request, timeout=15) as response:
        return json.load(response)


def check_summary(repo, sha, get=api_get):
    checks = []
    for page in range(1, 11):
        result = get(repo, f"commits/{sha}/check-runs?filter=latest&per_page=100&page={page}")
        batch = result["check_runs"]
        require(isinstance(batch, list), "Invalid check run response")
        checks.extend(batch)
        if len(checks) >= result["total_count"]:
            break
        require(bool(batch), "Incomplete check run inventory")
    else:
        raise ValueError("More than 1000 checks; refusing incomplete CI status")
    failed = [c["name"] for c in checks if c.get("conclusion") in
              ("failure", "cancelled", "timed_out", "action_required", "stale", "startup_failure")]
    pending = [c["name"] for c in checks if c.get("status") != "completed" or
               c.get("conclusion") not in ("success", "neutral", "skipped") and c["name"] not in failed]
    status = "Fehlgeschlagen" if failed else "Läuft" if pending else "Grün" if checks else "Ausstehend"
    return {"status": status, "count": len(checks), "failed": failed, "pending": pending}


def fetch_live(data, get=api_get, checks=False):
    repo = data["repository"]
    pulls = []
    for page in range(1, 21):
        items = get(repo, f"pulls?state=open&per_page=100&page={page}")
        require(isinstance(items, list), "Invalid pull request response")
        pulls.extend(items)
        if len(items) < 100:
            break
    else:
        raise ValueError("More than 2000 open PRs; refusing an incomplete inventory")
    main = get(repo, "branches/" + quote(data["main"]["branch"], safe=""))
    candidate = get(repo, "pulls/" + str(data["candidate"]["pr"]))
    expected, actual = data["candidate"]["sha"], candidate["head"]["sha"]
    metadata_only = False
    if actual != expected:
        # A status commit cannot embed its own hash. Verify the exact forward
        # comparison before accepting a later status/evidence-only publication.
        comparison = get(repo, "compare/" + expected + "..." + actual)
        files = comparison.get("files", [])
        metadata_only = (comparison.get("status") == "ahead"
                         and comparison.get("merge_base_commit", {}).get("sha") == expected
                         and 0 < len(files) < 300  # GitHub truncates at 300 files.
                         and all(tracking_path(f.get("filename", ""))
                                 and tracking_path(f.get("previous_filename", f.get("filename", "")))
                                 for f in files))
    result = {"observed_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
            "main_sha": main["commit"]["sha"], "candidate_sha": candidate["head"]["sha"],
            "candidate_metadata_only": metadata_only,
            "candidate_state": candidate["state"], "candidate_merged": candidate.get("merged", False),
            "pulls": [{"number": p["number"], "title": p["title"], "draft": p["draft"],
                       "head": p["head"]["sha"], "branch": p["head"]["ref"],
                       "head_repo": (p["head"].get("repo") or {}).get("full_name"),
                       "base": p["base"]["ref"]} for p in pulls]}
    if checks:
        by_sha = {}
        for pull in result["pulls"]:
            if pull["head"] not in by_sha:
                by_sha[pull["head"]] = check_summary(repo, pull["head"], get)
            pull["checks"] = by_sha[pull["head"]]
    return result


def tracking_path(path):
    if path in {"README.md", "tools/workflow/project.json"}:
        return True
    return (path.startswith("docs/") and ".." not in path.split("/")
            and Path(path).suffix.lower() in {".md", ".json", ".svg", ".gz", ".zip"})


def live_markdown(data, live):
    require(isinstance(live.get("pulls"), list), "Missing live pull request list")
    included = {i["pr"]: i["head"] for i in data["included"] + data.get("integration_inputs", [])}
    included.update({i["pr"]: i["head"] for i in data.get("deliveries", [])
                     if i["status"] in ("integrated", "accepted")})
    candidate_matches = (live["candidate_sha"] == data["candidate"]["sha"]
                         or live.get("candidate_metadata_only", False))
    lines = ["# Voxelverse – Live-Lieferübersicht", "", "Abgerufen: " + md(live["observed_at"]), "",
             f"Offene PRs: **{len(live['pulls'])}**. Dies ist kein Fertigstellungsprozentsatz und keine Reservierung.", "",
             f"main: `{live['main_sha']}` · Kandidat #{data['candidate']['pr']}: `{live['candidate_sha']}` "
             f"({md(live['candidate_state'])}, merged={live['candidate_merged']}).", ""]
    if live.get("candidate_metadata_only", False):
        lines += ["Der aktuelle Kandidatenkopf ergänzt ausschließlich Status-/Nachweisdateien "
                  "gegenüber dem festen Quellstand. Vorwärtsabstammung und vollständiger "
                  "Dateivergleich wurden gelesen; Spielcode und Abnahmestatus bleiben unverändert.", ""]
    if live["main_sha"] != data["main"]["sha"] or not candidate_matches:
        lines += ["**Basis hat sich geändert.** Der Integrationsbesitzer muss die feste Statusbewertung "
                  "abgleichen. Prozentwerte und Abnahmen werden nicht automatisch hochgesetzt.", ""]
    branches = {p["branch"]: p["number"] for p in live["pulls"] if p.get("head_repo") == data["repository"]}
    lines += ["| PR | Titel | Lieferung | Gestapelt auf | CI am aktuellen Kopf |", "|---|---|---|---|---|"]
    for p in sorted(live["pulls"], key=lambda x: x["number"], reverse=True):
        status = "Entwurf" if p["draft"] else "Offen"
        if p["number"] == data["candidate"]["pr"]:
            status = "Gemeinsamer Spieltest-Kandidat"
        if p["number"] in included:
            status = "Im festen Kandidaten enthalten" if candidate_matches and included[p["number"]] == p["head"] else "Nachlieferung / Kandidatenabgleich nötig"
        if p["number"] in data.get("alternatives", []):
            status = "Alternative; nicht zusätzlich übernehmen"
        parent = branches.get(p["base"])
        dependency = f"[#{parent}]({url(data, 'pull/' + str(parent))})" if parent and parent != p["number"] else md(p["base"])
        checks = p.get("checks")
        ci = (checks["status"] + f" ({checks['count']})" if checks else "Nicht abgefragt")
        if checks and checks["failed"]:
            ci += ": " + ", ".join(checks["failed"])
        lines.append(f"| [#{p['number']}]({url(data, 'pull/' + str(p['number']))}) | "
                     f"{md(p['title'])} | {status} | {dependency} | {md(ci)} |")
    lines += ["", "Branch-Abhängigkeiten werden über das PR-Ziel erkannt. Weitere fachliche Abhängigkeiten "
              "stehen in der Übergabe. Fehlende PRs beweisen weder freie Arbeit noch eine erfolgte Abnahme.", ""]
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=ROOT)
    sub = parser.add_subparsers(dest="command", required=True)
    render_parser = sub.add_parser("render")
    render_parser.add_argument("--check", action="store_true")
    sub.add_parser("check")
    live_parser = sub.add_parser("live")
    live_parser.add_argument("--output", type=Path)
    live_parser.add_argument("--checks", action="store_true", help="Include the latest checks for each exact open PR head")
    sub.add_parser("round")
    args = parser.parse_args()
    try:
        data = read_project(args.project.resolve())
        if args.command in ("render", "check"):
            render(args.project.resolve(), data, args.command == "check" or args.check)
            print("PROJECT_DASHBOARD_PASSED: source, weights, dependencies and generated views consistent; no gameplay executed")
        elif args.command == "round":
            issue = api_get(data["repository"], "issues/" + str(data["coordination_issue"]))
            print(f"{issue['html_url']} (updated {issue['updated_at']})\n\n{issue.get('body') or ''}")
        else:
            live = fetch_live(data, checks=args.checks)
            report = live_markdown(data, live)
            if args.output:
                args.output.mkdir(parents=True, exist_ok=True)
                (args.output / "live.json").write_text(json.dumps(live, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
                (args.output / "live.md").write_text(report, encoding="utf-8")
            print(report)
    except (OSError, ValueError, KeyError, TypeError, HTTPError, URLError) as error:
        print(f"PROJECT_DASHBOARD_FAILED: {error}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
