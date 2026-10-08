#!/usr/bin/env python3
"""Export and strictly restore source refs only after a separate Root slot/GO.

PREPARED script: no pack exists until the explicit execution flag is supplied.
The slot URL records approval; a local lock alone does not grant a host slot.
Only a dedicated bare export and fresh bare restore are mutated.
"""
import argparse
import contextlib
import fcntl
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import signal
import socket
import subprocess
import time

BASE = Path(__file__).resolve().parent
OID = re.compile(r"^[0-9a-f]{40}$")
SLOT_PREFIX = "https://github.com/MajorDragonfly/voxelverse/issues/137#issuecomment-"

def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result

def checksum(path, monitor=None):
    digest = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for data in iter(lambda: stream.read(1024 * 1024), b""):
            if monitor is not None:
                monitor()
            digest.update(data)
    return digest.hexdigest()

def validate(config):
    assert config["schema"] == "voxelverse.qa-final-source-refs.v1"
    assert len(config["tips"]) == config["tip_count"]
    assert len({t["ref"] for t in config["tips"]}) == len(config["tips"])
    assert all(OID.fullmatch(t["commit"]) and OID.fullmatch(t["tree"]) and t["ref"].startswith("refs/heads/qa-source/") for t in config["tips"])
    assert all(OID.fullmatch(p) for p in config["exclude_prerequisites"])
    assert set(config["expected_actual_header_prerequisites"]) == set(config["exclude_prerequisites"])
    root = Path(config["root_git_dir"]).resolve()
    export = Path(config["export_git_dir"]).resolve()
    assert export != root and root not in export.parents
    assert export == BASE / "qa-final-export.git", "Export destination is restricted to the separately prepared bare"
    assert (export / "HEAD").is_file()
    assert (export / "objects/info/alternates").read_text().splitlines() == config["object_alternates"]
    assert len(config["object_alternates"]) == 2 and all(Path(p).is_dir() for p in config["object_alternates"])
    assert config["guard"]["locks"] == ["/tmp/voxelverse-heavy.lock", "/tmp/voxelverse-r32-db514e109ac6-heavy.lock"]
    assert checksum(config["guard"]["module"]) == config["guard"]["sha256"]
    return export

class HostRun:
    def __init__(self, guard, log):
        self.guard, self.log = guard, log
        self.foreign_seen = False
        self.commands = 0

    def event(self, value):
        self.log.write(json.dumps(value, ensure_ascii=False) + "\n")
        self.log.flush()

    def inventory(self, phase):
        snapshot = self.guard.snapshot()
        active = [p for p in snapshot["processes"] if p["name"].lower().startswith("godot") and p["state"] != "Z"]
        self.event({"event": "host_inventory", "phase": phase, "time_unix": snapshot["time_unix"],
                    "loadavg": snapshot["loadavg"], "active_godot": active})
        if active:
            self.foreign_seen = True
            raise RuntimeError("Active Godot entered the exclusive bundle slot; no further Git work")
        return snapshot

    def git(self, bare, *args, data=None):
        self.inventory("before_git")
        command = ["git"] + (["--git-dir=" + str(bare)] if bare is not None else []) + list(args)
        env = dict(os.environ, GIT_OPTIONAL_LOCKS="0")
        for name in ("GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE", "GIT_COMMON_DIR", "GIT_OBJECT_DIRECTORY", "GIT_ALTERNATE_OBJECT_DIRECTORIES"):
            env.pop(name, None)
        self.commands += 1
        self.event({"event": "git_start", "ordinal": self.commands, "command": command, "time_unix": time.time()})
        process = subprocess.Popen(command, stdin=subprocess.PIPE if data is not None else subprocess.DEVNULL,
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=env, start_new_session=True)
        pending = data
        try:
            while True:
                try:
                    stdout, stderr = process.communicate(pending, timeout=0.25)
                    break
                except subprocess.TimeoutExpired:
                    pending = None
                    self.inventory("git_running")
        except BaseException:
            if process.poll() is None:
                os.killpg(process.pid, signal.SIGTERM)
                try:
                    process.communicate(timeout=3)
                except subprocess.TimeoutExpired:
                    os.killpg(process.pid, signal.SIGKILL)
                    process.communicate()
            raise
        self.event({"event": "git_end", "ordinal": self.commands, "exit_code": process.returncode,
                    "stderr": stderr.decode(errors="replace"), "time_unix": time.time()})
        self.inventory("after_git")
        if process.returncode:
            raise RuntimeError("Git failed (" + str(process.returncode) + "): " + stderr.decode(errors="replace"))
        return stdout.decode("utf-8")

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--refs-config", type=Path, default=BASE / "qa-final-source-refs.json")
    parser.add_argument("--output-directory", type=Path)
    parser.add_argument("--slot-comment-url")
    parser.add_argument("--slot-start-utc")
    parser.add_argument("--execute-root-confirmed-slot", action="store_true")
    parser.add_argument("--prepare-check", action="store_true", help="Validate tiny configuration only; no graph walk or pack")
    parser.add_argument("--verify-bundle", type=Path, help="Instead of exporting, strictly restore this existing bundle under the same guard")
    args = parser.parse_args()
    config_bytes = args.refs_config.read_bytes()
    config = json.loads(config_bytes)
    export = validate(config)
    if args.prepare_check:
        if args.execute_root_confirmed_slot:
            parser.error("Preparation and execution are separate modes")
        print(json.dumps({"prepared_only": True, "tips": config["tip_count"], "config_sha256": hashlib.sha256(config_bytes).hexdigest(), "pack_invoked": False}))
        return 0
    if not args.execute_root_confirmed_slot or not args.output_directory or not args.slot_comment_url or not args.slot_start_utc:
        parser.error("A separate Root slot/GO, explicit execution flag, START UTC, comment URL and new output directory are required")
    if not args.slot_comment_url.startswith(SLOT_PREFIX) or not args.slot_comment_url[len(SLOT_PREFIX):].isdigit():
        parser.error("Expected the existing confirmed #137 START comment URL")
    if not re.fullmatch(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z", args.slot_start_utc):
        parser.error("START UTC must be explicit ISO8601 Z")
    output = args.output_directory.resolve()
    if output.exists() or output.parent != BASE or not re.fullmatch(r"qa-final-source-export-[A-Za-z0-9_-]+", output.name):
        parser.error("Output must be a fresh evidence-staging/qa-final-source-export-* directory")
    guard = module("qa_final_a6_host_guard", config["guard"]["module"])
    verifier = module("qa_final_strict_verifier", BASE / "qa-final-source-bundle-verify.py")
    metadata = {"label": "final-qa-source-export-strict-restore", "host": socket.gethostname(),
                "operator_supplied_root_go": True, "slot_comment_url": args.slot_comment_url,
                "slot_start_utc": args.slot_start_utc, "config_sha256": hashlib.sha256(config_bytes).hexdigest(),
                "exporter_sha256": checksum(__file__), "verifier_sha256": checksum(BASE / "qa-final-source-bundle-verify.py"),
                "guard_sha256": config["guard"]["sha256"], "pid_namespace": os.readlink("/proc/self/ns/pid"),
                "namespace_pid": os.getpid(), "export_git_dir": str(export), "tip_count": config["tip_count"]}
    error, result, hostrun = None, None, None
    with guard.exclusive_locks([Path(p) for p in config["guard"]["locks"]], metadata):
        # Acquiring both locks is necessary but does not confer authorization.
        output.mkdir(parents=True, exist_ok=False)
        (output / "refs-config-used.json").write_bytes(config_bytes)
        with (output / "host-slot.jsonl").open("x") as log:
            hostrun = HostRun(guard, log)
            hostrun.event({"event": "start", **metadata, "both_locks_held": True, "time_unix": time.time()})
            try:
                hostrun.inventory("start")
                if list((export / "objects/pack").glob("*.pack")):
                    raise RuntimeError("Prepared export store unexpectedly has a physical pack")
                hostrun.git(export, "update-ref", "--stdin", data="".join("update " + t["ref"] + " " + t["commit"] + "\n" for t in config["tips"]).encode())
                for tip in config["tips"]:
                    if hostrun.git(export, "rev-parse", "--verify", tip["ref"] + "^{commit}").strip() != tip["commit"]:
                        raise RuntimeError("Export tip commit binding mismatch")
                    if hostrun.git(export, "rev-parse", "--verify", tip["ref"] + "^{tree}").strip() != tip["tree"]:
                        raise RuntimeError("Export tip tree binding mismatch")
                bundle = args.verify_bundle.resolve() if args.verify_bundle else output / "qa-final-source.bundle"
                if not args.verify_bundle:
                    hostrun.git(export, "bundle", "create", str(bundle), *[t["ref"] for t in config["tips"]],
                                *["^" + p for p in config["exclude_prerequisites"]])
                result = verifier.verify(config, bundle, output, hostrun.git)
                result.update({"bundle": str(bundle), "bundle_bytes": bundle.stat().st_size,
                               "bundle_sha256": checksum(bundle, lambda: hostrun.inventory("bundle_sha256")),
                               "status": "strictly_verified", "slot": metadata, "engine_invoked": False,
                               "root_index_or_refs_changed_by_exporter": False, "frozen_sources_changed_by_exporter": False})
                hostrun.inventory("end")
            except BaseException as failure:
                error = type(failure).__name__ + ": " + str(failure)
                (output / "actual-failure.json").write_text(json.dumps({"status": "actual_negative", "error": error, "slot": metadata}, indent=2) + "\n")
            finally:
                current = guard.processes()
                active = [p for p in current if p["name"].lower().startswith("godot") and p["state"] != "Z"]
                hostrun.foreign_seen |= bool(active)
                if active and error is None:
                    error = "Active Godot present at actual END"
                unchanged = args.refs_config.read_bytes() == config_bytes
                if not unchanged and error is None:
                    error = "Refs configuration changed during the section"
                if result is not None:
                    result["strict_closure_math_pass"] = result["strict_pass"]
                    result["strict_pass"] = result["strict_pass"] and error is None
                    result["host_valid"] = error is None
                    result["status"] = "strictly_verified" if error is None else "actual_negative"
                    result["error"] = error
                    (output / "qa-final-source-bindings.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
                if error is not None:
                    (output / "actual-failure.json").write_text(json.dumps({"status": "actual_negative", "error": error, "slot": metadata}, indent=2) + "\n")
                hostrun.event({"event": "end", "time_unix": time.time(), "exit_code": 0 if error is None else 1,
                               "error": error, "active_godot": active, "foreign_godot_observed": hostrun.foreign_seen or bool(active),
                               "refs_config_unchanged": unchanged, "both_locks_held": True})
    # Nonblocking reacquisition reports release; it never grants another slot.
    locks_free = True
    with contextlib.ExitStack() as stack:
        for path in config["guard"]["locks"]:
            lock = stack.enter_context(Path(path).open("a+"))
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                locks_free = False
                break
    post_active = [p for p in guard.processes() if p["name"].lower().startswith("godot") and p["state"] != "Z"]
    hostrun.foreign_seen |= bool(post_active)
    if not locks_free:
        error = (error + "; " if error else "") + "Post-release locks are not both nonblocking free"
    if post_active:
        error = (error + "; " if error else "") + "Active Godot at post-release END receipt"
    if result is not None:
        result["strict_pass"] = result["strict_closure_math_pass"] and error is None
        result["host_valid"] = error is None
        result["status"] = "strictly_verified" if error is None else "actual_negative"
        result["error"] = error
        (output / "qa-final-source-bindings.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    if error is not None:
        (output / "actual-failure.json").write_text(json.dumps({"status": "actual_negative", "error": error, "slot": metadata}, indent=2) + "\n")
    receipt = {"exit_code": 0 if error is None else 1, "error": error, "both_locks_released_and_nonblocking_free": locks_free,
               "host_godot_active_zero": not post_active,
               "foreign_godot_observed": hostrun.foreign_seen if hostrun else None,
               "strict_closure_pass": bool(result and result["strict_pass"] and error is None), "output": str(output)}
    (output / "actual-end-receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
    print(json.dumps(receipt))
    return receipt["exit_code"]

if __name__ == "__main__":
    raise SystemExit(main())
