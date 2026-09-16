#!/usr/bin/env python3
"""Build and exercise a release package outside the source project directory."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
import zipfile

from validate_godot import ERROR
from validation_provenance import SourceRun
from validation_support import isolated_env

PACKAGED_TESTS = ['body_identity_test', 'far_simulation_test', 'village_navigation_budget_test', 'campaign_scaling_test', 'creature_builder_v7_test', 'modular_assembly_framework_test', 'gameplay_acceptance_test', 'meta_runtime_test', 'planet_sphere_contract_test', 'behavior_skill_tree_test', 'creature_behavior_gameplay_test', 'development_path_test', 'tribal_age_test', 'tribal_age_supply_test', 'tribal_age_world_test', 'creature_parts_studio_test', 'creature_joint_studio_test', 'research_goals_test', 'species_comparison_test', 'input_preferences_test', 'save_slots_test', 'onboarding_test', 'creature_scan_test', 'resource_visuals_test']
PRESETS = {"linux": ("Linux Desktop", "voxelverse.x86_64"),
           "windows": ("Windows Desktop", "voxelverse.exe")}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--platform", choices=PRESETS, default="windows" if os.name == "nt" else "linux")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--skip-import", action="store_true")
    args = parser.parse_args()
    try:
        return validate(args)
    except ValueError as error:
        parser.error(str(error))


def validate(args):
    args.godot = str(Path(shutil.which(args.godot) or args.godot).expanduser().resolve())
    args.project = args.project.expanduser().resolve()
    args.output = args.output.expanduser().resolve()
    if args.output.is_relative_to(args.project):
        raise ValueError("Export reports must be outside the source project")
    if args.output.exists() and (not args.output.is_dir() or any(args.output.iterdir())):
        raise ValueError("Choose a new output directory to preserve previous export evidence")
    args.output.mkdir(parents=True, exist_ok=True)
    with (args.output / "run-owner.json").open("x", encoding="utf-8") as stream:
        json.dump({"pid": os.getpid(), "started_unix": time.time()}, stream)
    logs = args.output / "logs"
    logs.mkdir()
    source_run = SourceRun(args.project)
    source_run.begin_report(args.output)
    results = []
    summary = {"godot": None, "platform": args.platform, "source": SourceRun.summary(source_run.start),
               "checks": results, "probes": [], "complete": False, "passed": False}
    archive_path = args.output / f"voxelverse-{args.platform}-x86_64.zip"
    pending_archive = archive_path.with_suffix(".zip.pending")

    def observe(phase, force=False):
        observation = source_run.observe(phase, force=force)
        if source_run.blocked:
            raise RuntimeError(f"Export source changed or became unavailable: {phase}")
        return observation

    def run(name, command, cwd, env=None, timeout=120):
        observe("before_" + name)
        started = time.monotonic()
        try:
            process = subprocess.run(command, cwd=cwd, env=env, stdout=subprocess.PIPE,
                                     stderr=subprocess.STDOUT, text=True, encoding="utf-8",
                                     errors="replace", timeout=timeout)
            text, status = process.stdout, process.returncode
        except subprocess.TimeoutExpired as error:
            data = error.stdout or b""
            text = data.decode(errors="replace") if isinstance(data, bytes) else data
            text += "\nERROR: exported runtime timed out\n"
            status = 124
        except (OSError, KeyboardInterrupt) as error:
            text = f"ERROR: export process interrupted: {error}\n"
            status = 130 if isinstance(error, KeyboardInterrupt) else 127
        failed = status != 0 or ERROR.search(text) is not None
        log_path = logs / f"{name}.log"
        log_path.write_text(text, encoding="utf-8")
        observation = source_run.observe(name)
        result = {"name": name, "process_passed": not failed, "passed": not failed and not source_run.blocked,
                  "exit_code": status, "seconds": round(time.monotonic() - started, 3),
                  "command": command, "source_status": observation["status"],
                  "source_sha256": observation["source"].get("source_sha256"),
                  "log_sha256": hashlib.sha256(log_path.read_bytes()).hexdigest()}
        results.append(result)
        print(json.dumps(result), flush=True)
        if not result["passed"]:
            print(text[-12000:], flush=True)
            raise RuntimeError(f"Export validation failed: {name}")

    try:
        if source_run.blocked:
            raise RuntimeError("Export source identity unavailable before validation")
        version = subprocess.check_output([args.godot, "--version"], text=True, timeout=20).strip()
        summary["godot"] = version
        if not version.startswith("4.6.3."):
            raise ValueError(f"Expected Godot 4.6.3, got {version}")
        native_platform = "windows" if os.name == "nt" else "linux"
        if args.platform != native_platform:
            raise ValueError("Export acceptance must run the target platform's native binary.")
        observe("engine_version")
        with tempfile.TemporaryDirectory(prefix="voxelverse-export-") as temporary:
            root = Path(temporary).resolve()
            if root.is_relative_to(args.project):
                raise RuntimeError("Export test sandbox must be outside the source checkout.")
            package = root / "package"
            package.mkdir()
            qa = root / "qa"
            qa.mkdir()
            # Production exports omit test fixtures. Keep the historical save
            # beside the external development-path probe, as its fallback expects.
            shutil.copy2(args.project / "tests/fixtures/home_group_pr20.json", qa / "home_group_pr20.json")
            if not args.skip_import:
                run("import", [args.godot, "--headless", "--path", str(args.project), "--import"], args.project, timeout=240)
            preset, executable_name = PRESETS[args.platform]
            executable = package / executable_name
            run("release_export", [args.godot, "--headless", "--path", str(args.project),
                                    "--export-release", preset, str(executable)], args.project, timeout=240)
            summary["export_source"] = SourceRun.summary(source_run.current)
            if not executable.is_file() or not executable.with_suffix(".pck").is_file():
                raise RuntimeError("Export did not produce both executable and PCK.")
            # No project.godot, source paths or project --path are supplied here.
            run("packaged_main", [str(executable), "--headless", "--verbose", "--", "--runtime-exit-frames", "300"],
                package, isolated_env(root / "main-userdata"))
            run("packaged_planet_lab", [str(executable), "--headless", "--verbose", "--", "--planet-lab", "--runtime-exit-frames", "600"],
                package, isolated_env(root / "lab-userdata"))
            if "PLANET_LAB_READY" not in (logs / "packaged_planet_lab.log").read_text():
                raise RuntimeError("Native executable did not enter the planet lab through the gameplay transition.")
            run("packaged_menu_input", [str(executable), "--headless", "--verbose", "--", "--input-smoke"],
                package, isolated_env(root / "menu-userdata"))
            if "MENU_INPUT_PASSED" not in (logs / "packaged_menu_input.log").read_text():
                raise RuntimeError("Native executable did not pass the actual menu-click/F4 acceptance.")
            run("packaged_frontend", [str(executable), "--headless", "--verbose", "--", "--frontend-smoke"],
                package, isolated_env(root / "frontend-userdata"), timeout=240)
            if "FRONTEND_PASSED" not in (logs / "packaged_frontend.log").read_text():
                raise RuntimeError("Native executable did not pass title/pause/save-slot acceptance.")
            run("packaged_spherical_campaign", [str(executable), "--headless", "--verbose", "--", "--sphere-smoke"],
                package, isolated_env(root / "sphere-userdata"), timeout=240)
            if "SPHERICAL_CAMPAIGN_RUNTIME_PASSED" not in (logs / "packaged_spherical_campaign.log").read_text():
                raise RuntimeError("Native executable did not pass spherical migration/new-game/fresh-process acceptance.")
            for name, flag, marker, timeout in [
                ("spherical_creature", "--sphere-creature-smoke", "SPHERICAL_CREATURE_PASSED", 180),
                ("spherical_gameplay", "--sphere-gameplay-smoke", "SPHERICAL_GAMEPLAY_PASSED", 900),
                ("body_travel", "--body-travel-smoke", "BODY_TRAVEL_PASSED", 420),
            ]:
                run(f"packaged_{name}", [str(executable), "--headless", "--verbose", "--", flag],
                    package, isolated_env(root / f"{name}-userdata"), timeout=timeout)
                if marker not in (logs / f"packaged_{name}.log").read_text():
                    raise RuntimeError(f"Native executable did not complete {name} acceptance.")
            run("packaged_spherical_egg_production", [str(executable), "--headless", "--verbose", "--",
                                                       "--sphere-gameplay-smoke", "--egg-production"],
                package, isolated_env(root / "egg-production-userdata"), timeout=900)
            if "SPHERICAL_EGG_PRODUCTION_PASSED" not in (logs / "packaged_spherical_egg_production.log").read_text():
                raise RuntimeError("Native executable did not complete real egg transport, meal and restart acceptance.")
            # Official 4.6.3 release templates disable --script. Keep that intact:
            # use the editor to instrument the exact release PCK, after starting
            # the untouched release executable above. Neither sees source files.
            # Run instruments without the installer's portable _sc_ marker:
            # each probe must honor its isolated user-directory environment.
            instrument_dir = root / "instrument"
            instrument_dir.mkdir()
            instrument = instrument_dir / Path(args.godot).name
            for binary in Path(args.godot).parent.iterdir():
                if binary.is_file() and binary.name.startswith("Godot") and binary.suffix not in [".zip", ".tpz"]:
                    shutil.copy2(binary, instrument_dir / binary.name)
            if not instrument.exists():
                shutil.copy2(args.godot, instrument)
            pack_command = [str(instrument), "--headless", "--main-pack", str(executable.with_suffix(".pck"))]
            for name in PACKAGED_TESTS:
                probe = qa / f"{name}.gd"
                shutil.copy2(args.project / "tests" / f"{name}.gd", probe)
                probe_args = ["--script", str(probe)]
                if name in ["body_identity_test", "far_simulation_test"]:
                    probe_args += ["--", "--restart-pack", str(executable.with_suffix(".pck"))]
                if name == "research_goals_test":
                    # Godot consumes --main-pack before exposing runtime args.
                    # Pass the exact PCK to the independent reload process too.
                    probe_args += ["--", "--research-pack", str(executable.with_suffix(".pck"))]
                if name == "resource_visuals_test":
                    probe_args += ["--", "--resource-restart-pack", str(executable.with_suffix(".pck"))]
                run(f"packaged_{name}", [*pack_command, *probe_args],
                    package, isolated_env(root / name))
                if name == "tribal_age_world_test":
                    run("packaged_tribal_cold_restart", [*pack_command, "--script", str(probe), "--", "--restart-check"],
                        package, isolated_env(root / name))
            probe = qa / "export_runtime_probe.gd"
            shutil.copy2(args.project / "tools/export_runtime_probe.gd", probe)
            notices_path = qa / "GODOT_NOTICES.txt"
            for seed, family in [(15838, "verdant"), (63352, "autumn"), (23757, "violet")]:
                report = logs / f"planet_{seed}.json"
                userdata = root / f"seed-{seed}"
                run(f"packaged_planet_{seed}", [*pack_command, "--script", str(probe),
                                               "--", str(seed), str(report), str(notices_path)],
                    package, isolated_env(userdata))
                data = json.loads(report.read_text(encoding="utf-8"))
                if not data["passed"] or data["loaded_meshes"] != 63 or data["flora_color_family"] != family:
                    raise RuntimeError(f"Packaged seed {seed} did not meet its acceptance contract.")
                if not Path(data["user_data_dir"]).resolve().is_relative_to(userdata):
                    raise RuntimeError("Export test used a non-isolated save directory.")
                # The Windows editor console wrapper starts the sibling GUI exe.
                if Path(data["executable"]).resolve().parent != instrument_dir:
                    raise RuntimeError("Probe ran an unexpected Godot installation.")
                summary["probes"].append(data)
            shutil.copy2(notices_path, package / "GODOT_NOTICES.txt")
            observe("package_acceptance", force=True)
            (package / "README.txt").write_text(
                "Voxelverse development build\n\n"
                f"Start {executable_name} with its .pck and any adjacent libraries kept together.\n"
                "WASD: laufen. Leertaste: springen. E: Scanmodus; Tier im Fadenkreuz halten. Q/Rechtsklick: Beissen.\n"
                "K opens the skill tree. J or its Entdeckungsbuch button opens the shared discovery book. Esc closes it.\n"
                "N: Heimatgruppe. Stammeszeitalter bewusst bestaetigen, dann Bewohner waehlen und Gruppenauftraege erteilen.\n"
                "F2: Kreaturenwerkstatt. Esc/F8: Menue/Einstellungen, dort Ton und Musik.\n"
                "F4: Planetenlabor/Galaxiekatalog; Tab: Boden/Orbit, M: Koerperwechsel.\n"
                "This build passed headless release acceptance. Visual/GPU acceptance is still pending.\n",
                encoding="utf-8")
            (package / "BUILD_INFO.json").write_text(json.dumps({
                "source": summary["source"], "export_source": summary["export_source"],
                "validation_source": SourceRun.summary(source_run.current),
                "source_inputs_complete": source_run.start["complete"] and source_run.current["complete"],
                "godot": version, "platform": args.platform,
                "acceptance": "native_headless_release_and_exact_pck", "checks_passed": len(results),
                "target_pc_acceptance": False}, indent=2) + "\n", encoding="utf-8")
            # Publish a named release archive only after the final source gate.
            with zipfile.ZipFile(pending_archive, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
                for path in sorted(package.rglob("*")):
                    if path.is_file():
                        archive.write(path, Path("voxelverse") / path.relative_to(package))
            with pending_archive.open("rb") as archive:
                checksum = hashlib.file_digest(archive, "sha256").hexdigest()
            summary["complete"] = True
    except (OSError, RuntimeError, ValueError, KeyError, subprocess.SubprocessError, KeyboardInterrupt) as error:
        summary["error"] = str(error)
        print(str(error), file=sys.stderr)
    finally:
        source_run.observe("finish", force=True)
        summary["provenance"] = source_run.write_report(args.output)
        summary["passed"] = (summary["complete"] and "error" not in summary and not source_run.blocked
                             and all(result["passed"] for result in results))
        summary["provenance"]["reusable"] &= summary["passed"]
        results.append({"name": "source_integrity", "kind": "source_provenance", "passed": not source_run.blocked,
                        "status": summary["provenance"]["status"]})
        try:
            if summary["passed"]:
                pending_archive.replace(archive_path)
                (args.output / "SHA256SUMS.txt").write_text(f"{checksum}  {archive_path.name}\n")
                summary["archive"] = {"name": archive_path.name, "bytes": archive_path.stat().st_size,
                                      "sha256": checksum}
        except OSError as error:
            summary.update(passed=False, error=str(error))
            summary["provenance"]["reusable"] = False
            archive_path.unlink(missing_ok=True)
            (args.output / "SHA256SUMS.txt").unlink(missing_ok=True)
        finally:
            pending_archive.unlink(missing_ok=True)
            temporary_report = args.output / "results.json.tmp"
            temporary_report.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
            temporary_report.replace(args.output / "results.json")
        print(json.dumps({"source_integrity": summary["provenance"]["status"], "passed": summary["passed"]}), flush=True)
    return 0 if summary["passed"] else 1


if __name__ == "__main__":
    sys.exit(main())
