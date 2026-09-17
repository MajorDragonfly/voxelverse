#!/usr/bin/env python3
"""Bounded package-start context; offline by default, never a reservation or test run."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import sys
from urllib.parse import quote

if __package__:
    from . import project_dashboard, work_packet
else:
    import project_dashboard
    import work_packet

ROOT = Path(__file__).resolve().parents[1]
MAX_AGE_SECONDS = 1800
MAX_PAGES = 20
MAX_SNAPSHOT_BYTES = 4_000_000
SHA = re.compile(r"[0-9a-f]{40}")


def require(condition, message):
    if not condition:
        raise ValueError(message)


def bounded(value, limit=240):
    value = " ".join(str(value).split())
    return value if len(value) <= limit else value[:limit - 1] + "…"


def digest(value):
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def timestamp(value):
    require(isinstance(value, str), "Snapshot timestamp must be a string")
    parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    require(parsed.tzinfo is not None, "Snapshot timestamp needs a timezone")
    return parsed


def local_state(project):
    git = lambda *args: work_packet.git(project, *args)
    changed = git("status", "--porcelain", "--untracked-files=all").splitlines()
    return {"head": git("rev-parse", "HEAD"),
            "branch": git("branch", "--show-current") or "(detached)",
            "dirty": bool(changed), "changed_count": len(changed)}


def source_digest(project):
    return digest("\n".join((project / path).read_text(encoding="utf-8")
                            for path in (project_dashboard.DATA, work_packet.CATALOG)))


def validate_observation(observation, data):
    require(isinstance(observation, dict), "Invalid snapshot observation")
    timestamp(observation.get("observed_at"))
    require(isinstance(observation.get("main_sha"), str)
            and SHA.fullmatch(observation["main_sha"]), "Invalid observed main SHA")
    issue = observation.get("issue")
    require(isinstance(issue, dict), "Missing coordination issue")
    expected_url = f"https://github.com/{data['repository']}/issues/{data['coordination_issue']}"
    require(issue.get("url") == expected_url, "Wrong coordination issue URL")
    timestamp(issue.get("updated_at"))
    body = issue.get("body")
    require(isinstance(body, str) and len(body) <= 100_000, "Invalid coordination issue body")
    require(issue.get("body_sha256") == digest(body), "Coordination issue body hash mismatch")
    pulls = observation.get("pulls")
    require(isinstance(pulls, list) and len(pulls) < MAX_PAGES * 100,
            "Invalid/incomplete open PR inventory")
    seen = set()
    for pull in pulls:
        require(isinstance(pull, dict), "Invalid open PR metadata")
        number = pull.get("number")
        require(type(number) is int and number > 0 and number not in seen,
                "Invalid/duplicate open PR number")
        seen.add(number)
        require(pull.get("state") == "open" and type(pull.get("draft")) is bool,
                "Invalid open PR state")
        require(isinstance(pull.get("head"), str) and SHA.fullmatch(pull["head"]),
                "Invalid open PR SHA")
        for name in ("title", "branch", "base"):
            require(isinstance(pull.get(name), str) and len(pull[name]) <= 300,
                    "Invalid open PR " + name)
    return observation


def fetch_observation(data, get=None, now=None):
    """Read only main, central issue and open PR pages. Never infer issue assignments."""
    get = get or project_dashboard.api_get
    started_at = now or datetime.now(timezone.utc)
    repo = data["repository"]
    main = get(repo, "branches/" + quote(data["main"]["branch"], safe=""))
    issue = get(repo, "issues/" + str(data["coordination_issue"]))
    pulls, seen = [], set()
    for page in range(1, MAX_PAGES + 1):
        entries = get(repo, f"pulls?state=open&sort=created&direction=asc&per_page=100&page={page}")
        require(isinstance(entries, list) and len(entries) <= 100, "Invalid open PR page")
        for pull in entries:
            require(isinstance(pull, dict), "Invalid open PR metadata")
            number = pull.get("number")
            require(type(number) is int and number > 0 and number not in seen,
                    "Duplicate/invalid PR across pages; retry the observation")
            seen.add(number)
            pulls.append({"number": number, "title": pull["title"],
                          "state": pull["state"], "draft": pull["draft"],
                          "head": pull["head"]["sha"], "branch": pull["head"]["ref"],
                          "base": pull["base"]["ref"]})
        if len(entries) < 100:
            break
    else:
        raise ValueError("Open PR page limit reached; refusing an incomplete inventory")
    body = issue.get("body") or ""
    observation = {"observed_at": started_at.isoformat(timespec="seconds"),
                   "main_sha": main["commit"]["sha"],
                   "issue": {"url": issue["html_url"], "updated_at": issue["updated_at"],
                             "body": body, "body_sha256": digest(body)}, "pulls": pulls}
    return validate_observation(observation, data)


def save_snapshot(path, observation, data, local, sources, context_id):
    validate_observation(observation, data)
    snapshot = {"schema": 1, "purpose": "package-start-observation", "context_id": context_id,
                "repository": data["repository"], "branch": data["main"]["branch"],
                "local_head": local["head"], "sources_sha256": sources, "observation": observation}
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(snapshot, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def read_snapshot(path, data, local, sources, context_id, now=None):
    require(path.stat().st_size <= MAX_SNAPSHOT_BYTES, "Snapshot exceeds size limit")
    snapshot = json.loads(path.read_text(encoding="utf-8"))
    require(isinstance(snapshot, dict) and type(snapshot.get("schema")) is int
            and snapshot["schema"] == 1 and snapshot.get("purpose") == "package-start-observation",
            "Unsupported snapshot schema/purpose")
    for key, expected in (("context_id", context_id), ("repository", data["repository"]),
                          ("branch", data["main"]["branch"]), ("local_head", local["head"]),
                          ("sources_sha256", sources)):
        require(snapshot.get(key) == expected, "Snapshot mismatch: " + key)
    observation = validate_observation(snapshot.get("observation"), data)
    age = ((now or datetime.now(timezone.utc)) - timestamp(observation["observed_at"])).total_seconds()
    require(0 <= age <= MAX_AGE_SECONDS,
            "Snapshot expired or future-dated; take a new explicit --live observation")
    return observation


def packet_rows(packets, data, observation=None, exclude=(), busy=()):
    unknown = (set(exclude) | set(busy)) - packets.keys()
    require(not unknown, "Unknown excluded/busy catalog packets: " + ", ".join(sorted(unknown)))
    deliveries = {item["id"]: item for item in data["deliveries"]}
    rows = []
    for key, packet in packets.items():
        delivery = deliveries.get(key, {})
        status = delivery.get("status", "unrecorded")
        dependencies = [{"id": name, "recorded_status": deliveries.get(name, {}).get("status", "unrecorded")}
                        for name in delivery.get("depends_on", [])]
        reasons = []
        if status != "planned":
            reasons.append("recorded_status:" + status)
        if key in exclude:
            reasons.append("explicitly_excluded")
        if key in busy:
            reasons.append("explicitly_busy")
        if any(item["recorded_status"] not in ("integrated", "accepted") for item in dependencies):
            reasons.append("unintegrated_recorded_dependencies")
        overlaps = []
        for other in sorted(set(busy) - {key}):
            overlaps.extend(work_packet.conflicts(packets, [key, other]))
        if overlaps:
            reasons.append("declared_write_conflict")
        matching_prs = []
        issue_reference = False
        if observation:
            token = re.compile(r"(?<![A-Z0-9-])" + re.escape(key) + r"(?![A-Z0-9-])", re.IGNORECASE)
            matching_prs = [pull["number"] for pull in observation["pulls"]
                            if pull["number"] == delivery.get("pr")
                            or token.search(pull["title"]) or token.search(pull["branch"])]
            if matching_prs:
                reasons.append("open_pr_exact_reference")
            issue_reference = bool(token.search(observation["issue"]["body"]))
            if issue_reference:
                reasons.append("central_issue_exact_reference_requires_review")
        rows.append({"id": key, "title": bounded(packet["title"]), "recorded_status": status,
                     "assignment": "unknown", "candidate": not reasons, "reasons": reasons,
                     "depends_on": dependencies, "write_groups": packet["write_groups"],
                     "conflicts": overlaps, "open_pr_references": matching_prs,
                     "central_issue_reference": issue_reference})
    return rows


def make_report(project, data, packets, local, args, observation, mode):
    rows = packet_rows(packets, data, observation, args.exclude, args.busy)
    candidates = [row for row in rows if row["candidate"]]
    if args.command == "show":
        require(args.packet in packets, "Unknown packet: " + args.packet)
        selected = [row for row in rows if row["id"] == args.packet]
    else:
        selected = candidates[:args.limit]
    recorded = {"reviewed_on": data["reviewed_on"], "main_sha": data["main"]["sha"],
                "matches_local_head": data["main"]["sha"] == local["head"],
                "freshness": "not_verified_against_current_main"}
    if observation:
        recorded["freshness"] = ("matches_observed_main" if data["main"]["sha"] == observation["main_sha"]
                                 else "differs_from_observed_main")
    result = {"command": args.command, "local": local, "recorded": recorded,
              "coordination_url": f"https://github.com/{data['repository']}/issues/{data['coordination_issue']}",
              "observation": {"mode": mode}, "priorities": [bounded(x) for x in data["priorities"][:3]],
              "candidate_count": len(candidates), "packets": selected,
              "excluded_count": len(rows) - len(candidates),
              "excluded": [row for row in rows if not row["candidate"]][:20],
              "limits": ["Planning candidates in catalog order, not verified free assignments.",
                         "Read the central issue and reconcile current user assignments once at package start.",
                         "Missing assignments/PRs do not mean free. Exact PR references only; no fuzzy status inference.",
                         "No reservation, git fetch, test, CI query or project-status write performed."]}
    if observation:
        issue = observation["issue"]
        age = max(0, int((datetime.now(timezone.utc) - timestamp(observation["observed_at"])).total_seconds()))
        result["observation"].update({"observed_at": observation["observed_at"], "age_seconds": age,
                                      "main_sha": observation["main_sha"], "open_pr_count": len(observation["pulls"]),
                                      "issue": {k: issue[k] for k in ("url", "updated_at", "body_sha256")},
                                      "snapshot": str(args.snapshot or args.save_snapshot) if args.snapshot or args.save_snapshot else None,
                                      "scope": "Point-in-time read; not a lock or an atomic GitHub snapshot."})
    if args.command == "show":
        result["brief"] = work_packet.brief(packets[args.packet]).replace(
            "Keine Netzwerkabfrage oder Prüfung wurde ausgeführt.",
            "Der Paketbrief führt keine Prüfung aus; Beobachtungsmodus siehe oben.")[:8000]
    return result


def human_report(report):
    local, recorded, observed = report["local"], report["recorded"], report["observation"]
    lines = [f"Lokal: {local['branch']} @ {local['head']} (uncommitted: {local['changed_count']})",
             f"Bewerteter Stand {recorded['reviewed_on']}: {recorded['main_sha']} [{recorded['freshness']}]",
             f"Beobachtung: {observed['mode']}; Zuweisung ungeprüft: {report['coordination_url']}"]
    if observed["mode"] != "offline":
        lines += [f"main beobachtet: {observed['main_sha']} um {observed['observed_at']} "
                  f"({observed['age_seconds']} s alt); offene PRs: {observed['open_pr_count']}",
                  f"Issue aktualisiert: {observed['issue']['updated_at']}; SHA256: {observed['issue']['body_sha256']}"]
        if observed["snapshot"]:
            lines.append("Issue-Text im Snapshot unter observation.issue.body: " + observed["snapshot"])
    lines += ["Prioritäten (datierter Projektstand):", *["- " + p for p in report["priorities"]],
              "Planungskandidaten in Katalogreihenfolge; kein Paket ist damit als frei bestätigt:"]
    for row in report["packets"]:
        deps = ", ".join(f"{d['id']}={d['recorded_status']}" for d in row["depends_on"]) or "keine vermerkt"
        lines.append(f"- {row['id']}: {row['title']} [{row['recorded_status']}; assignment=unknown] "
                     f"Bereiche: {', '.join(row['write_groups'])}; Abhängigkeiten: {deps}")
    if not report["packets"]:
        lines.append("- Keine passenden Planungskandidaten; Katalog/aktuelle Vergabe abgleichen.")
    for row in report["excluded"]:
        details = [", ".join(row["reasons"])]
        if row["depends_on"]:
            details.append("Abhängigkeiten " + ", ".join(f"{d['id']}={d['recorded_status']}" for d in row["depends_on"]))
        if row["open_pr_references"]:
            details.append("PR " + ", ".join("#" + str(n) for n in row["open_pr_references"]))
        for conflict in row["conflicts"]:
            details.append(conflict["right"] + ": " + ", ".join(conflict["groups"] + conflict["files"]))
        lines.append(f"Ausgeschlossen: {row['id']} — " + "; ".join(details))
    if report.get("brief"):
        lines += ["", report["brief"]]
    lines += ["", "Fehlende Einträge bedeuten nicht frei. Keine Reservierung, Tests oder Statusänderung ausgeführt."]
    return "\n".join(lines)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=ROOT)
    sub = parser.add_subparsers(dest="command", required=True)
    for name in ("next", "show"):
        command = sub.add_parser(name)
        if name == "show":
            command.add_argument("packet")
        command.add_argument("--limit", type=int, default=3, help="Maximum candidate rows (1–10)")
        command.add_argument("--exclude", nargs="+", default=[], help="Explicitly exclude catalog IDs")
        command.add_argument("--busy", nargs="+", default=[], help="Known busy catalog IDs; check declared overlaps")
        command.add_argument("--json", action="store_true")
        source = command.add_mutually_exclusive_group()
        source.add_argument("--live", action="store_true", help="Read main, central issue and open PR metadata once")
        source.add_argument("--snapshot", type=Path, help="Reuse an observation for this same package start (max 30 min)")
        command.add_argument("--save-snapshot", type=Path, help="With --live: save raw observation outside tracked files")
        command.add_argument("--context-id", help="Same package-start identifier when saving/reusing a snapshot")
    args = parser.parse_args(argv)
    try:
        require(1 <= args.limit <= 10, "--limit must be between 1 and 10")
        require(not args.save_snapshot or args.live, "--save-snapshot requires --live")
        require(not (args.snapshot or args.save_snapshot) or bool(args.context_id and args.context_id.strip()),
                "Saving/reusing a snapshot requires --context-id for this same package start")
        project = args.project.resolve()
        data, packets = project_dashboard.read_project(project), work_packet.read_packets(project)
        local, sources = local_state(project), source_digest(project)
        observation, mode = None, "offline"
        if args.live:
            observation, mode = fetch_observation(data), "live_observation"
        elif args.snapshot:
            observation = read_snapshot(args.snapshot, data, local, sources, args.context_id)
            mode = "cached_observation"
        report = make_report(project, data, packets, local, args, observation, mode)
        if args.save_snapshot:
            require(not args.save_snapshot.resolve().is_relative_to(project),
                    "Save temporary snapshots outside the tracked project (also supports git worktrees)")
            save_snapshot(args.save_snapshot, observation, data, local, sources, args.context_id)
        print(json.dumps(report, ensure_ascii=False, indent=2) if args.json else human_report(report))
    except (OSError, ValueError, KeyError, TypeError) as error:
        print(f"WORK_CONTEXT_FAILED: {error}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
