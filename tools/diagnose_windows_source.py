import json, os, subprocess, sys, unittest
from pathlib import Path
from validation_provenance import SourceRun
from validation_support import isolated_env, validation_editor
sys.path.insert(0,str(Path.cwd()/"tests/tooling"))
suite=unittest.TestSuite()
for name in ["test_windows_path_and_handle_ctime_can_use_different_clocks","test_windows_different_file_handle_is_still_rejected","test_windows_handle_ctime_change_during_read_is_still_rejected"]:
    suite.addTests(unittest.defaultTestLoader.loadTestsFromName("validation_provenance_test.SourceObservationTest."+name))
if not unittest.TextTestRunner(verbosity=2).run(suite).wasSuccessful(): raise SystemExit(1)
run=SourceRun(Path.cwd())
print("SOURCE_BEFORE",json.dumps(run.summary(run.start)),flush=True)
if run.blocked: raise SystemExit(1)
with validation_editor(sys.argv[1]) as editor:
    result=subprocess.run([str(editor),"--headless","--path",str(Path.cwd()),"--import"],env=isolated_env(Path(os.environ["RUNNER_TEMP"])/"windows-provenance-data"),capture_output=True,text=True,encoding="utf-8",errors="replace",timeout=240)
    print("IMPORT_RESULT",result.returncode,result.stdout[-1800:],result.stderr[-1800:],flush=True)
    observation=run.observe("import")
    print("IMPORT_SOURCE",json.dumps(observation),flush=True)
run.observe("finish",force=True)
print("SOURCE_AFTER",json.dumps(run.summary(run.current)),flush=True)
print("WINDOWS_SOURCE_IMPORT_PASSED",not run.blocked and result.returncode==0,flush=True)
raise SystemExit(1 if run.blocked or result.returncode else 0)
