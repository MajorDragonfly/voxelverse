"""Conservative local Git change plan; test ownership stays in contracts.json.

Rules describe domain boundaries and direct consumers, not a complete static
dependency graph. Unknown paths or shared infrastructure require the full suite.
"""
from fnmatch import fnmatchcase
import hashlib
import json
import os
from pathlib import Path
import subprocess

if __package__:
    from .check_validation_contracts import read_contracts
else:
    from check_validation_contracts import read_contracts

RULES = Path("tools/validation/selection_rules.json")


def git(project, *arguments):
    try:
        return subprocess.check_output(["git", "-C", str(project), *arguments],
                                       stderr=subprocess.PIPE, timeout=20)
    except subprocess.CalledProcessError as error:
        raise ValueError("Cannot plan Git changes: " + error.stderr.decode("utf-8", "replace").strip()) from error


def changed_paths(project, reference):
    """Compare the actual checkout to an exact commit, including untracked files.

    --no-renames deliberately exposes both sides of a rename to the selector.
    We never fetch, resolve a merge-base implicitly, or run external diff filters.
    """
    top = Path(os.fsdecode(git(project, "rev-parse", "--show-toplevel")).strip()).resolve()
    if top != project.resolve():
        raise ValueError("--project must be the Git repository root for change planning")
    if git(project, "ls-files", "--unmerged", "-z"):
        raise ValueError("Resolve Git conflicts before planning tests")
    base = git(project, "rev-parse", "--verify", "--end-of-options", reference + "^{commit}").decode().strip()
    head = git(project, "rev-parse", "HEAD").decode().strip()
    tree = git(project, "rev-parse", "HEAD^{tree}").decode().strip()
    data = git(project, "diff", "--no-ext-diff", "--no-textconv", "--no-renames",
               "--name-status", "-z", base, "--").split(b"\0")
    changes = {}
    for index in range(0, len(data) - 1, 2):
        if index + 1 >= len(data) or not data[index + 1]:
            raise ValueError("Incomplete Git change list")
        status, path = data[index].decode(), os.fsdecode(data[index + 1])
        if status not in {"A", "M", "D", "T"}:
            raise ValueError("Unsupported Git change status: " + status)
        changes[path] = status
    for raw in git(project, "ls-files", "--others", "--exclude-standard", "-z").split(b"\0"):
        if raw:
            changes[os.fsdecode(raw)] = "?"
    rows = []
    old_symlinks = set()
    if changes:
        for entry in git(project, "ls-tree", "-r", "-z", base, "--", *changes).split(b"\0"):
            if entry:
                metadata, raw_path = entry.split(b"\t", 1)
                if metadata.startswith(b"120000 "):
                    old_symlinks.add(os.fsdecode(raw_path))
    for path, status in sorted(changes.items()):
        file = project / path
        if file.is_symlink():
            digest = hashlib.sha256(os.fsencode(os.readlink(file))).hexdigest()
        elif file.is_file():
            hasher = hashlib.sha256()
            with file.open("rb") as stream:
                for block in iter(lambda: stream.read(1024 * 1024), b""):
                    hasher.update(block)
            digest = hasher.hexdigest()
        else:
            digest = None
        rows.append({"path": path, "status": status, "sha256": digest, "symlink": file.is_symlink() or path in old_symlinks})
    return {"base_commit": base, "head_commit": head, "head_tree": tree, "changes": rows}


def read_rules(project, contracts):
    rules = json.loads((project / RULES).read_text(encoding="utf-8"))
    if not isinstance(rules, dict) or type(rules.get("schema")) is not int or rules["schema"] != 1:
        raise ValueError("Unsupported selection rule schema")
    def paths(values):
        if not isinstance(values, list) or not values or any(not isinstance(v, str) or not v or v.startswith("/") or ".." in v.split("/") for v in values):
            raise ValueError("Selection paths must be nonempty repository-relative patterns")
    for key in ("documentation", "full"):
        paths(rules.get(key))
    if not isinstance(rules.get("rules"), list) or not rules["rules"]:
        raise ValueError("No domain selection rules")
    ids = set()
    for item in rules["rules"]:
        if not isinstance(item, dict) or not isinstance(item.get("id"), str) or not item["id"] or item["id"] in ids:
            raise ValueError("Invalid or duplicate selection rule ID")
        ids.add(item["id"])
        paths(item.get("paths"))
        owners = item.get("contracts")
        if not isinstance(owners, list) or not owners or any(not isinstance(c, str) or c not in contracts for c in owners):
            raise ValueError("Unknown or empty contracts in selection rule: " + item["id"])
        if "tests" in item:
            raise ValueError("Tests belong only in contracts.json")
    return rules


def select_changes(changes, registry, owners, rules):
    by_id = {c["id"]: c["tests"] for c in registry["contracts"]}
    selected, chosen_contracts, decisions = set(), set(), []
    full = False
    for change in changes:
        path = change["path"]
        # Keep the potentially long test list once at plan level. Each path
        # carries its reason and contract references, not repeated test arrays.
        decision = dict(path=path, contracts=[], direct_tests=[], rules=[])
        if change.get("symlink") or change.get("status") == "T":
            decision["reason"] = "symlink_or_type_change_requires_full"
            full = True
        elif any(fnmatchcase(path, p) for p in rules["full"]):
            decision["reason"] = "shared_infrastructure_requires_full"
            full = True
        elif any(fnmatchcase(path, p) for p in rules["documentation"]):
            decision["reason"] = "documentation_only"
        else:
            test_path = path[:-4] if path.endswith(".uid") else path
            test = test_path[6:-3] if test_path.startswith("tests/") and test_path.endswith(".gd") else ""
            if test in owners:
                decision.update(reason="changed_registered_test", contracts=[owners[test]], direct_tests=[test])
                selected.add(test)
                chosen_contracts.add(owners[test])
            else:
                matches = [r for r in rules["rules"] if any(fnmatchcase(path, p) for p in r["paths"])]
                if matches:
                    names = {name for r in matches for name in r["contracts"]}
                    tests = {test for name in names for test in by_id[name]}
                    decision.update(reason="domain_and_direct_consumers", rules=[r["id"] for r in matches],
                                    contracts=sorted(names))
                    chosen_contracts.update(names)
                    selected.update(tests)
                else:
                    decision["reason"] = "unmapped_path_requires_full"
                    full = True
        decisions.append(decision)
    if full:
        chosen_contracts = set(by_id)
        selected = set(owners)
    return {"scope": "full" if full else "targeted" if selected else "documentation" if changes else "unchanged",
            "requires_main": full, "contracts": sorted(chosen_contracts), "selected_tests": sorted(selected),
            "registered_test_count": len(owners), "selected_test_count": len(selected), "decisions": decisions}


def build_plan(project, reference):
    registry, owners = read_contracts(project)
    rules = read_rules(project, {c["id"] for c in registry["contracts"]})
    source = changed_paths(project, reference)
    plan = select_changes(source["changes"], registry, owners, rules)
    plan.update(schema=1, kind="validation_plan", tests_executed=False, source=source,
                registry_sha256=hashlib.sha256((project / "tools/validation/contracts.json").read_bytes()).hexdigest(),
                rules_sha256=hashlib.sha256((project / RULES).read_bytes()).hexdigest(),
                limits="Conservative path rules, not a complete dependency graph or test result. Unknown paths expand to all tests. Default integration CI remains full; exports, graphics and target-PC checks stay separate.")
    return plan
