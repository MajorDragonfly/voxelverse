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
from validation_support import isolated_env

PACKAGED_TESTS = ['body_identity_test', 'far_simulation_test', 'village_navigation_budget_test', 'campaign_scaling_test', 'creature_builder_v7_test', 'modular_assembly_framework_test', 'gameplay_acceptance_test', 'meta_runtime_test', 'planet_sphere_contract_test', 'behavior_skill_tree_test', 'creature_behavior_gameplay_test', 'development_path_test', 'tribal_age_test', 'tribal_age_supply_test', 'tribal_age_world_test', 'creature_parts_studio_test', 'creature_joint_studio_test', 'research_goals_test', 'species_comparison_test', 'input_preferences_test', 'save_slots_test', 'onboarding_test', 'creature_scan_test']
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
    args.godot = str(Path(shutil.which(args.godot) or args.godot).expanduser().resolve())
    args.project = args.project.resolve()
    args.output = args.output.resolve()
    args.output.mkdir(parents=True, exist_ok=True)
    logs = args.output / "logs"
    logs.mkdir(exist_ok=True)
    version = subprocess.check_output([args.godot, "--version"], text=True).strip()
    if not version.startswith("4.6.3."):
        sys.exit(f"Expected Godot 4.6.3, got {version}")
    native_platform = "windows" if os.name == "nt" else "linux"
    if args.platform != native_platform:
        sys.exit("Export acceptance must run the target platform's native binary.")
    results = []

    def run(name, command, cwd, env=None, timeout=120):
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
        failed = status != 0 or ERROR.search(text) is not None
        result = {"name": name, "passed": not failed, "exit_code": status,
                  "seconds": round(time.monotonic() - started, 3)}
        results.append(result)
        (logs / f"{name}.log").write_text(text, encoding="utf-8")
        print(json.dumps(result), flush=True)
        if failed:
            print(text[-12000:], flush=True)
            raise RuntimeError(f"Export validation failed: {name}")

    summary = {"godot": version, "platform": args.platform, "checks": results, "probes": []}
    try:
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
            archive_path = args.output / f"voxelverse-{args.platform}-x86_64.zip"
            with zipfile.ZipFile(archive_path, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
                for path in sorted(package.rglob("*")):
                    if path.is_file():
                        archive.write(path, Path("voxelverse") / path.relative_to(package))
            with archive_path.open("rb") as archive:
                checksum = hashlib.file_digest(archive, "sha256").hexdigest()
            (args.output / "SHA256SUMS.txt").write_text(f"{checksum}  {archive_path.name}\n")
            summary["archive"] = {"name": archive_path.name, "bytes": archive_path.stat().st_size,
                                  "sha256": checksum}
    except (OSError, RuntimeError, ValueError, KeyError) as error:
        summary["error"] = str(error)
        print(str(error), file=sys.stderr)
    summary["passed"] = "error" not in summary and all(result["passed"] for result in results)
    (args.output / "results.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    return 0 if summary["passed"] else 1


if __name__ == "__main__":
    sys.exit(main())
