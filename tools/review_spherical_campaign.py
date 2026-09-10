"""Capture the real spherical creature/editor/water flow in a graphical session."""
import argparse
from pathlib import Path
import subprocess
import tempfile

from validation_support import isolated_env, validation_editor
from validate_godot import ERROR


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--renderer", choices=["forward_plus", "gl_compatibility"], required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    project = Path(__file__).resolve().parents[1]
    with validation_editor(args.godot) as editor, tempfile.TemporaryDirectory(prefix="sphere-review-") as userdata:
        result = subprocess.run([
            str(editor), "--path", str(project), "--rendering-method", args.renderer,
            "--audio-driver", "Dummy", "--resolution", "1280x720",
            "--script", "res://tests/spherical_creature_test.gd", "--", "--capture", str(output),
        ], env=isolated_env(Path(userdata)), stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            text=True, encoding="utf-8", errors="replace", timeout=240)
    (output / "runtime.log").write_text(result.stdout, encoding="utf-8")
    if result.returncode or ERROR.search(result.stdout) or "SPHERICAL_CREATURE_PASSED" not in result.stdout:
        print(result.stdout, flush=True)
        raise RuntimeError(f"Spherical graphical acceptance failed; inspect {output / 'runtime.log'}")
    if len(list(output.glob("*.png"))) != 3:
        raise RuntimeError("Graphical acceptance did not produce all three actual scene captures.")
    print(f"Spherical graphics passed in {args.renderer}: {output}")


if __name__ == "__main__":
    main()
