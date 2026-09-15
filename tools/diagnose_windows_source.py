import json, os
from pathlib import Path
from validation_provenance import SourceRun, _signature
root=Path.cwd().resolve()
run=SourceRun(root)
print("SOURCE_SUMMARY", json.dumps(run.summary(run.start)))
print("GIT_ROOT_RAW", repr(run._git("rev-parse", "--show-toplevel")))
print("PROJECT_ROOT", repr(str(root)))
raw=run._git("ls-files","-z").split(b"\0")[0]
path=root/os.fsdecode(raw)
print("PROBE_PATH", str(path.relative_to(root)))
print("PATH_STAT", _signature(path.lstat()))
for flag in [os.O_RDONLY, os.O_RDONLY|getattr(os,"O_BINARY",0)]:
 fd=os.open(path,flag)
 try:
  print("FD_STAT",flag,_signature(os.fstat(fd)))
 finally: os.close(fd)
