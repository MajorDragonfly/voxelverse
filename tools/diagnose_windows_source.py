import inspect, json
from pathlib import Path
import validation_provenance as module
original=module._signature
history=[]
def observe(info):
    signature=original(info)
    frame=inspect.currentframe().f_back
    history.append({"line":frame.f_lineno,"path":str(frame.f_locals.get("path","")),"signature":signature})
    del history[:-12]
    return signature
module._signature=observe
for attempt in range(2):
    history.clear()
    run=module.SourceRun(Path.cwd())
    print("SOURCE_SUMMARY",attempt,json.dumps(run.summary(run.start)))
    print("SIGNATURE_HISTORY",json.dumps(history))
