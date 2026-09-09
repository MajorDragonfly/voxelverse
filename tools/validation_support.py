"""Keep desktop validation away from existing Godot settings and saves."""
from contextlib import contextmanager
import os
from pathlib import Path
import shutil
import tempfile


def isolated_env(directory):
    env = os.environ.copy()
    for variable in ["XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME", "APPDATA", "LOCALAPPDATA"]:
        path = directory / variable.lower()
        path.mkdir(parents=True, exist_ok=True)
        env[variable] = str(path.resolve())
    return env


@contextmanager
def validation_editor(command):
    executable = Path(shutil.which(command) or command).expanduser().resolve()
    if not executable.is_file():
        raise FileNotFoundError(f"Godot executable not found: {command}")
    if not any((executable.parent / name).exists() for name in ["_sc_", "._sc_"]):
        yield executable
        return
    # Self-contained Godot ignores the user-directory environment. Run a copy
    # without its marker, preserving the installed toolchain and editor_data.
    with tempfile.TemporaryDirectory(prefix="voxelverse-validation-editor-") as temporary:
        directory = Path(temporary)
        for source in executable.parent.iterdir():
            if source.is_file() and (
                source == executable
                or (source.name.startswith("Godot") and source.suffix not in {".zip", ".tpz"})
                or source.suffix in {".dll", ".so", ".dylib"}
            ):
                shutil.copy2(source, directory / source.name)
        yield directory / executable.name
