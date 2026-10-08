#!/usr/bin/env python3
"""Strict source-bundle restoration. Call only inside the guarded export slot.

Alternates supply known prerequisites, never evidence of physically imported
objects. Closure is measured against the actual bundle header, not an intended
exclusion list. No checkout, engine, fetch or root-index operation is used.
"""
import hashlib
import json
from pathlib import Path
import re

OID = re.compile(r"^[0-9a-f]{40}$")

def set_binding(values):
    data = "".join(value + "\n" for value in sorted(values)).encode()
    return {"count": len(values), "sha256": hashlib.sha256(data).hexdigest()}

def read_header(bundle):
    prerequisites, tips = [], {}
    with Path(bundle).open("rb") as stream:
        version = stream.readline().decode("ascii").strip()
        if version not in ("# v2 git bundle", "# v3 git bundle"):
            raise RuntimeError("Unsupported bundle header")
        while True:
            line = stream.readline()
            if line == b"\n":
                break
            if not line or len(line) > 8192:
                raise RuntimeError("Invalid or unbounded bundle header")
            text = line.decode("utf-8").rstrip("\n")
            if text.startswith("@"):
                if text != "@object-format=sha1":
                    raise RuntimeError("Unsupported bundle capability: " + text)
                continue
            if text.startswith("-"):
                oid = text[1:].split(" ", 1)[0]
                if not OID.fullmatch(oid):
                    raise RuntimeError("Invalid prerequisite object ID")
                prerequisites.append(oid)
            else:
                oid, ref = text.split(" ", 1)
                if not OID.fullmatch(oid) or ref in tips:
                    raise RuntimeError("Invalid or duplicate tip header")
                tips[ref] = oid
    if len(prerequisites) != len(set(prerequisites)):
        raise RuntimeError("Duplicate header prerequisites")
    return {"version": version, "prerequisites": prerequisites, "tips": tips}

def objects(run, bare, revisions):
    result = run(bare, "rev-list", "--objects", "--missing=print", *revisions)
    reachable, unavailable = set(), set()
    for line in result.splitlines():
        token = line.split(" ", 1)[0]
        missing = token.startswith("?")
        oid = token[1:] if missing else token
        if not OID.fullmatch(oid):
            raise RuntimeError("Unexpected object traversal output: " + token)
        reachable.add(oid)
        if missing:
            unavailable.add(oid)
    return reachable, unavailable

def verify(config, bundle, output, run):
    """run(bare, *git_args, data=None) must monitor the dual-locked host."""
    output = Path(output)
    header = read_header(bundle)
    wanted_refs = {tip["ref"]: tip["commit"] for tip in config["tips"]}
    if header["tips"] != wanted_refs:
        raise RuntimeError("Actual bundle tip header differs from all configured tips")
    if set(header["prerequisites"]) != set(config["expected_actual_header_prerequisites"]):
        raise RuntimeError("Actual header prerequisites differ; preserve and diagnose this negative")
    restore = output / "restore.git"
    if restore.exists():
        raise RuntimeError("Strict verifier requires a fresh nonexistent bare restore")
    run(None, "init", "--bare", "--quiet", str(restore))
    (restore / "objects/info/alternates").write_text("".join(path + "\n" for path in config["object_alternates"]))
    run(restore, "config", "gc.auto", "0")
    run(restore, "config", "maintenance.auto", "false")
    verified = run(restore, "bundle", "verify", str(bundle))
    (output / "bundle-verify-stdout.txt").write_text(verified)
    unbundled = run(restore, "bundle", "unbundle", str(bundle))
    (output / "bundle-unbundle-stdout.txt").write_text(unbundled)
    observed = {}
    for line in unbundled.splitlines():
        oid, ref = line.split(" ", 1)
        observed[ref] = oid
    if observed != wanted_refs:
        raise RuntimeError("Unbundle did not return every exact configured tip")
    run(restore, "update-ref", "--stdin", data="".join("create " + ref + " " + oid + "\n" for ref, oid in sorted(wanted_refs.items())).encode())
    imported = set()
    packs = sorted((restore / "objects/pack").glob("*.idx"))
    if not packs:
        raise RuntimeError("No physical imported pack; alternates are not a restoration proof")
    for idx in packs:
        physical = run(restore, "verify-pack", "-v", str(idx))
        (output / (idx.stem + "-verify-pack.txt")).write_text(physical)
        found = set()
        for line in physical.splitlines():
            fields = line.split()
            if fields and OID.fullmatch(fields[0]):
                if len(fields) < 5 or fields[1] not in ("commit", "tree", "blob", "tag"):
                    raise RuntimeError("Unknown verify-pack object row")
                found.add(fields[0])
        if not found:
            raise RuntimeError("Empty physical pack index")
        imported |= found
    exported, exported_missing = objects(run, config["export_git_dir"], list(wanted_refs.values()))
    wanted, wanted_missing = objects(run, restore, list(wanted_refs.values()))
    prerequisites, prerequisite_missing = objects(run, restore, header["prerequisites"])
    if (exported, exported_missing) != (wanted, wanted_missing):
        raise RuntimeError("Independent export/restore traversal sets differ")
    required = wanted - prerequisites
    missing = required - imported
    historic_outside = wanted_missing - prerequisites
    absent_tips = set(wanted_refs.values()) - imported
    bindings = []
    for tip in config["tips"]:
        commit = run(restore, "rev-parse", "--verify", tip["ref"] + "^{commit}").strip()
        tree = run(restore, "rev-parse", "--verify", tip["ref"] + "^{tree}").strip()
        match = commit == tip["commit"] and tree == tip["tree"]
        bindings.append({"ref": tip["ref"], "commit": commit, "tree": tree, "matches": match,
                         "tip_commit_physically_imported": commit in imported})
    result = {
        "schema": "voxelverse.qa-final-source-strict-closure.v1",
        "method": "Independent exported/restored wanted reachable sets minus only actual bundle-header prerequisite closure; subtract physically imported verify-pack IDs. Alternates never count as imported.",
        "actual_header": header, "tip_tree_bindings": bindings,
        "wanted": set_binding(wanted), "actual_header_prerequisite_closure": set_binding(prerequisites),
        "required_new": set_binding(required), "physically_imported_pack_objects": set_binding(imported),
        "wanted_unavailable_historical_objects": len(wanted_missing),
        "prerequisite_unavailable_historical_objects": len(prerequisite_missing),
        "unavailable_wanted_objects_outside_actual_prerequisite_closure": sorted(historic_outside),
        "missing_object_count": len(missing), "missing_objects": sorted(missing),
        "tip_commits_missing_from_physical_pack": sorted(absent_tips),
        "independent_export_restore_sets_equal": True,
        "old_strict_closure_preserved": config["old_strict_closure"],
        "all_tip_tree_bindings_match": all(b["matches"] for b in bindings),
        "all_tip_commits_physically_imported": not absent_tips,
        "historical_missing_covered": not historic_outside,
        "strict_pass": not missing and not historic_outside and not absent_tips and all(b["matches"] for b in bindings),
        "restore_git_dir": str(restore), "full_checkout_created": False,
    }
    (output / "strict-object-closure.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    if not result["strict_pass"]:
        raise RuntimeError("Strict closure failed; actual negative saved, no success publication")
    return result

if __name__ == "__main__":
    raise SystemExit("Use qa-final-source-bundle-export.py inside a separately Root-confirmed dual-locked slot. This module never starts an unguarded verifier.")
