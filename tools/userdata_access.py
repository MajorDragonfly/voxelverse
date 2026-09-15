"""Cooperative, process-owned lease shared with Godot's UserdataAccess.

The sibling directory is outside the byte inventory. No clock/timeout grants
ownership: abandoned complete leases can be recovered only on the same host
after the owning PID has exited. Incomplete/foreign leases fail closed.
"""
from __future__ import annotations

from contextlib import contextmanager
import json
import os
from pathlib import Path
import secrets
import stat

if __package__:
    from .region_backup import BackupError, _require
else:
    from region_backup import BackupError, _require

FORMAT = "voxelverse_userdata_access_v1"
SUFFIX = ".voxelverse-access-v1"


def lock_path(source: Path) -> Path:
    source = source.resolve(strict=True)
    _require(source.is_dir() and source.name != "", "Expected a user-data directory")
    return source.with_name("." + source.name + SUFFIX)


def host_id() -> str:
    # Shared with Godot, deliberately not a hardware identifier. An absent or
    # different host name disables recovery; it never authorizes stealing.
    host = os.environ.get("COMPUTERNAME") or os.environ.get("HOSTNAME", "")
    if not host:
        for path in (Path("/etc/hostname"), Path("/proc/sys/kernel/hostname")):
            if path.is_file():
                host = path.read_text(encoding="utf-8").strip()
                break
    return host


def read_owner(lock: Path) -> dict:
    _require(stat.S_ISDIR(lock.lstat().st_mode), "Access lease is not a regular directory")
    _require({p.name for p in lock.iterdir()} == {"owner.json"}, "Incomplete user-data access lease")
    path = lock / "owner.json"
    _require(stat.S_ISREG(path.lstat().st_mode) and path.stat().st_size <= 4096,
             "Invalid user-data access owner")
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (ValueError, UnicodeError) as error:
        raise BackupError("Unreadable user-data access owner") from error
    _require(isinstance(value, dict) and set(value) == {"schema", "format", "pid", "host", "token", "role"}
             and type(value["schema"]) is int and value["schema"] == 1
             and value["format"] == FORMAT and type(value["pid"]) is int and 0 < value["pid"] <= 2147483647
             and isinstance(value["host"], str) and isinstance(value["token"], str)
             and len(value["token"]) == 64 and all(c in "0123456789abcdef" for c in value["token"])
             and value["role"] in ("writer", "offline"), "Unsupported user-data access owner")
    return value


def process_alive(pid: int) -> bool:
    if os.name == "nt":
        # os.kill(pid, 0) is not a portable existence check on Windows.
        import ctypes
        from ctypes import wintypes
        kernel = ctypes.WinDLL("kernel32", use_last_error=True)
        kernel.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
        kernel.OpenProcess.restype = wintypes.HANDLE
        kernel.CloseHandle.argtypes = [wintypes.HANDLE]
        kernel.GetExitCodeProcess.argtypes = [wintypes.HANDLE, ctypes.POINTER(wintypes.DWORD)]
        handle = kernel.OpenProcess(0x1000, False, pid)
        if not handle:
            return ctypes.get_last_error() != 87  # ERROR_INVALID_PARAMETER: no such PID.
        try:
            code = wintypes.DWORD()
            return not kernel.GetExitCodeProcess(handle, ctypes.byref(code)) or code.value == 259
        finally:
            kernel.CloseHandle(handle)
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except (PermissionError, OverflowError):
        return True
    return True


def recover_abandoned(lock: Path) -> bool:
    """Serialize recovery so a second recovery cannot remove a new owner's lease."""
    recovery = lock.with_name(lock.name + ".recovery")
    try:
        recovery.mkdir()
    except FileExistsError:
        return False
    try:
        if not lock.exists() and not lock.is_symlink():
            return True
        owner = read_owner(lock)
        if not host_id() or owner["host"] != host_id() or process_alive(owner["pid"]):
            return False
        (lock / "owner.json").unlink()
        lock.rmdir()
        return True
    finally:
        recovery.rmdir()


@contextmanager
def _exclusive(source: Path, role: str = "offline"):
    """Acquire before reading source bytes; hold through publication/replay."""
    _require(role in ("writer", "offline"), "Unknown access role")
    lock = lock_path(source)
    try:
        lock.mkdir()
    except FileExistsError:
        _require(recover_abandoned(lock), "User data is in use; close the game/editor and retry")
        try:
            lock.mkdir()
        except FileExistsError as error:
            raise BackupError("User data was acquired by another process; retry later") from error
    owner = {"schema": 1, "format": FORMAT, "pid": os.getpid(), "host": host_id(),
             "token": secrets.token_hex(32), "role": role}
    try:
        with (lock / "owner.json").open("x", encoding="utf-8") as stream:
            json.dump(owner, stream, sort_keys=True)
            stream.flush()
            os.fsync(stream.fileno())
    except BaseException:
        (lock / "owner.json").unlink(missing_ok=True)
        lock.rmdir()
        raise
    try:
        yield lock, owner
    finally:
        # Never remove an unexpected owner's lease. A partial owner after a hard
        # stop requires inspection; the source itself has not been modified.
        if read_owner(lock) == owner:
            (lock / "owner.json").unlink()
            lock.rmdir()


def _remove_owned(path: Path, owner: dict):
    _require(read_owner(path) == owner, "User-data access ownership changed")
    (path / "owner.json").unlink()
    path.rmdir()


def _writers_directory(lock: Path) -> Path:
    directory = lock.with_name(lock.name + ".writers")
    directory.mkdir(exist_ok=True)
    _require(stat.S_ISDIR(directory.lstat().st_mode), "Writer registry is not a regular directory")
    return directory


def _require_no_writers(directory: Path):
    # The exclusive gate prevents new registration. Existing writers may finish;
    # a disappearing marker causes a conservative retry, never a partial scan.
    with os.scandir(directory) as entries:
        for index, entry in enumerate(entries):
            _require(index < 1024, "Writer registry budget exceeded")
            path = Path(entry.path)
            owner = read_owner(path)
            _require(entry.name == owner["token"] and owner["role"] == "writer",
                     "Unexpected writer registry entry")
            _require(host_id() and owner["host"] == host_id() and not process_alive(owner["pid"]),
                     "User data is in use; close the game/editor and retry")
            _remove_owned(path, owner)


@contextmanager
def access(source: Path, role: str = "offline"):
    """Writers share registered leases; an offline scan holds the admission gate.

    This coordinates archives with existing writers. It intentionally does not
    turn concurrent game processes into a multiwriter transaction system.
    """
    if role == "offline":
        with _exclusive(source, role) as (lock, owner):
            _require_no_writers(_writers_directory(lock))
            yield owner
    else:
        _require(role == "writer", "Unknown access role")
        with _exclusive(source, role) as (lock, owner):
            marker = _writers_directory(lock) / owner["token"]
            marker.mkdir()
            try:
                with (marker / "owner.json").open("x", encoding="utf-8") as stream:
                    json.dump(owner, stream, sort_keys=True)
                    stream.flush()
                    os.fsync(stream.fileno())
            except BaseException:
                (marker / "owner.json").unlink(missing_ok=True)
                marker.rmdir()
                raise
        try:
            yield owner
        finally:
            _remove_owned(marker, owner)
