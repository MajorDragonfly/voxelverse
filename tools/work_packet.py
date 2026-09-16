#!/usr/bin/env python3
"""Print a bounded work brief. This local catalog does not reserve work in other chats."""
import argparse
from itertools import combinations
import json
from pathlib import Path
import re
import subprocess
import sys

if __package__:
    from .check_validation_contracts import read_contracts
else:
    from check_validation_contracts import read_contracts

ROOT = Path(__file__).resolve().parents[1]
CATALOG = Path("tools/workflow/packets.json")


def read_packets(project):
    data = json.loads((project / CATALOG).read_text(encoding="utf-8"))
    if not isinstance(data, dict) or type(data.get("schema")) is not int or data["schema"] != 1:
        raise ValueError("Unsupported work packet schema")
    entries = data.get("packets")
    if not isinstance(entries, list) or not entries:
        raise ValueError("No work packets")
    registry, _ = read_contracts(project)
    contract_ids = {entry["id"] for entry in registry["contracts"]}
    packets = {}
    for item in entries:
        if not isinstance(item, dict):
            raise ValueError("Packet must be an object")
        for field in ["id", "title", "goal", "acceptance", "limits"]:
            if not isinstance(item.get(field), str) or not item[field].strip():
                raise ValueError(f"Packet needs {field}")
        name = item["id"]
        if not re.fullmatch(r"[A-Z][A-Z0-9]*(?:-[A-Z0-9]+)+", name):
            raise ValueError(f"Invalid packet ID: {name}")
        if name in packets:
            raise ValueError(f"Duplicate packet: {name}")
        for field in ["write_groups", "files", "read", "contracts"]:
            values = item.get(field)
            if not isinstance(values, list) or not values or any(not isinstance(v, str) or not v.strip() for v in values):
                raise ValueError(f"{name} needs a nonempty {field} list")
            if len(values) != len(set(values)):
                raise ValueError(f"Duplicate {field} in {name}")
        unknown = set(item["contracts"]) - contract_ids
        if unknown:
            raise ValueError(f"{name}: unknown contracts: {', '.join(sorted(unknown))}")
        for filename in item["files"] + item["read"]:
            path = (project / filename).resolve()
            if not path.is_relative_to(project.resolve()) or not path.is_file():
                raise ValueError(f"{name}: missing or external path: {filename}")
        packets[name] = item
    return packets


def conflicts(packets, names):
    """Check every pair; exact shared starting files also catch missing group labels."""
    if len(names) != len(set(names)):
        raise ValueError("The same packet was assigned more than once")
    unknown = set(names) - packets.keys()
    if unknown:
        raise ValueError("Unknown packets: " + ", ".join(sorted(unknown)))
    found = []
    for left, right in combinations(names, 2):
        groups = sorted(set(packets[left]["write_groups"]) & set(packets[right]["write_groups"]))
        files = sorted(set(packets[left]["files"]) & set(packets[right]["files"]))
        if groups or files:
            found.append({"left": left, "right": right, "groups": groups, "files": files})
    return found


def brief(packet):
    return "\n".join([
        f"# {packet['id']} — {packet['title']}", "", packet["goal"],
        "", "Schreibbereiche: " + ", ".join(packet["write_groups"]),
        "Einstiegsdateien (keine vollständige Schreibfreigabe):",
        *["- " + value for value in packet["files"]],
        "Vertiefung nur für diesen Teilauftrag:",
        *["- " + value for value in packet["read"]],
        "", "Abnahme: " + packet["acceptance"], "Grenzen: " + packet["limits"],
        "", "Prüfauswahl aus der bestehenden Registry (Umfang nach Änderung festlegen):",
        "python3 tools/validate_godot.py --contracts " + " ".join(packet["contracts"]) + " --list-tests",
        "Ausführung: --list-tests entfernen; bei reinem Fachumfang ggf. --skip-main ergänzen.",
        "Nach Änderungen den tatsächlichen Diff planen: python3 tools/validate_godot.py --changed-since BASIS_SHA --plan",
        "Der lokale Plan erfasst auch neue Dateien; unbekannte/gemeinsame Bereiche erweitern die Auswahl. --plan entfernen führt sie aus.",
        "", "Vor Start: zentrale Zuweisung, Basis-SHA und Branch aus dem Integrationschat übernehmen.",
        "Dieser Katalog reserviert nichts. Keine Netzwerkabfrage oder Prüfung wurde ausgeführt.",
    ])


def git(project, *args):
    result = subprocess.run(["git", "-C", str(project), *args], capture_output=True, text=True)
    if result.returncode:
        raise ValueError(result.stderr.strip() or "Git command failed")
    return result.stdout.strip()


def handoff(project, packet_id, base):
    """Describe the exact local source; never manufacture test success."""
    if not re.fullmatch(r"[A-Z][A-Z0-9]*(?:-[A-Z0-9]+)+", packet_id):
        raise ValueError("Invalid packet ID")
    if not re.fullmatch(r"[0-9a-f]{40}", base):
        raise ValueError("Use the full assigned base SHA")
    git(project, "cat-file", "-e", base + "^{commit}")
    git(project, "merge-base", "--is-ancestor", base, "HEAD")
    status = git(project, "status", "--porcelain", "--untracked-files=all")
    if status:
        raise ValueError("Working tree has uncommitted/untracked changes. Commit the delivery before generating a handoff.")
    branch = git(project, "branch", "--show-current")
    if not branch or branch == "main":
        raise ValueError("Use a named feature branch, not main or detached HEAD")
    commit = git(project, "rev-parse", "HEAD")
    tree = git(project, "rev-parse", "HEAD^{tree}")
    files = git(project, "diff", "--name-status", "--no-renames", base, "HEAD")
    stat = git(project, "diff", "--stat", base, "HEAD")
    return "\n".join([
        f"## {packet_id}", "", f"Basis: `{base}`", f"Branch: `{branch}`",
        f"Liefercommit: `{commit}`", f"Tree: `{tree}`", "Arbeitsstand: sauber (lokal beobachtet).", "",
        "### Ergebnis", "", "[Sichtbares Verhalten und konkrete Umfangsgrenze ergänzen.]", "",
        "### Abhängigkeiten und gemeinsame Anschlüsse", "",
        "[Vorgänger-PRs, gemeinsame Schreibbereiche und direkte Verbraucher ergänzen.]", "",
        "### Prüfung", "",
        "[Befehl, Engine/Umgebung, tatsächlich geprüftes Commit/Tree, Ergebnis und Evidenzlink ergänzen.]",
        "Dieser Generator hat keine Spielprüfung ausgeführt und keinen Prüferfolg abgeleitet.", "",
        "### Offen", "", "[Konkrete Restgrenzen, Ziel-PC-/Grafikabnahme und Folgeauftrag ergänzen.]", "",
        "<details><summary>Tatsächlicher Dateiumfang</summary>", "", "```text", stat, "", files, "```", "", "</details>", "",
        "Bei Veröffentlichung über einen anderen Git-Commit die Tree-Gleichheit belegen und beide IDs nennen.",
    ])


def start_brief(packet, data, owner):
    candidate = data["candidate"]
    return "\n".join([
        f"Besitzer/Chat: {owner}",
        f"Basisvorschlag aus Statusabgleich {data['reviewed_on']}: {candidate['sha']}",
        f"Gemeinsamer Kandidat: {candidate['branch']} (PR #{candidate['pr']})",
        f"Zentrale Vergabe: https://github.com/{data['repository']}/issues/{data['coordination_issue']}",
        "Eine neuere explizite Zuweisung hat Vorrang. Aktuelles Ticket einmal lesen:",
        "python3 tools/project_dashboard.py round", "",
        brief(packet), "", "Abschluss auf sauberem Fachbranch:",
        f"python3 tools/work_packet.py handoff {packet['id']} --base {candidate['sha']}",
    ])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=ROOT)
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("list")
    sub.add_parser("check")
    sub.add_parser("show").add_argument("packet")
    sub.add_parser("conflicts").add_argument("packets", nargs="+")
    start = sub.add_parser("start")
    start.add_argument("packet")
    start.add_argument("--owner", required=True)
    delivery = sub.add_parser("handoff")
    delivery.add_argument("packet")
    delivery.add_argument("--base", required=True)
    args = parser.parse_args()
    try:
        if args.command == "handoff":
            print(handoff(args.project.resolve(), args.packet, args.base))
            return 0
        packets = read_packets(args.project.resolve())
        if args.command == "list":
            print("Teilauftragskatalog — keine Live-Belegung; Zuweisung über Integrationschat")
            for item in packets.values():
                print(f"{item['id']}: {item['title']} [{', '.join(item['write_groups'])}]")
        elif args.command in ("show", "start"):
            if args.packet not in packets:
                raise ValueError("Unknown packet: " + args.packet)
            if args.command == "show":
                print(brief(packets[args.packet]))
            else:
                if __package__:
                    from .project_dashboard import read_project
                else:
                    from project_dashboard import read_project
                print(start_brief(packets[args.packet], read_project(args.project.resolve()), args.owner))
        elif args.command == "conflicts":
            found = conflicts(packets, args.packets)
            for item in found:
                print(f"CONFLICT {item['left']} / {item['right']}: "
                      + ", ".join(item["groups"] + item["files"]))
            if found:
                return 1
            print("Keine deklarierten Schreibkonflikte; zentrale Zuweisung und neue Dateien separat prüfen.")
        else:
            print(f"WORK_PACKETS_PASSED: {len(packets)} briefs; references valid (no gameplay executed)")
    except (OSError, ValueError) as error:
        print(str(error), file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
