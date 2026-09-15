#!/usr/bin/env python3
"""Print a bounded work brief. This local catalog does not reserve work in other chats."""
import argparse
from itertools import combinations
import json
from pathlib import Path
import re
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
        if not re.fullmatch(r"ARCH-[0-9]{2}-[A-Z0-9-]+", name):
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
        "", "Vor Start: zentrale Zuweisung, Basis-SHA und Branch aus dem Integrationschat übernehmen.",
        "Dieser Katalog reserviert nichts. Keine Netzwerkabfrage oder Prüfung wurde ausgeführt.",
    ])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=ROOT)
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("list")
    sub.add_parser("check")
    sub.add_parser("show").add_argument("packet")
    sub.add_parser("conflicts").add_argument("packets", nargs="+")
    args = parser.parse_args()
    try:
        packets = read_packets(args.project.resolve())
        if args.command == "list":
            print("Teilauftragskatalog — keine Live-Belegung; Zuweisung über Integrationschat")
            for item in packets.values():
                print(f"{item['id']}: {item['title']} [{', '.join(item['write_groups'])}]")
        elif args.command == "show":
            if args.packet not in packets:
                raise ValueError("Unknown packet: " + args.packet)
            print(brief(packets[args.packet]))
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
