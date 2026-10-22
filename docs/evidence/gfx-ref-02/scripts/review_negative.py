import importlib.util, sys, types, unittest
from pathlib import Path
root=Path(__file__).resolve().parent/'review-source'
module=types.ModuleType('build_benchmark');module.__file__=str(root/'tools/art/build_benchmark.py')
sys.modules['build_benchmark']=module
exec(compile((root.parent/'old-builder.py').read_bytes(),module.__file__,'exec'),module.__dict__)
spec=importlib.util.spec_from_file_location('groundcover_negative',root/'tests/tooling/foliage_authoring_test.py')
test=importlib.util.module_from_spec(spec);spec.loader.exec_module(test)
result=unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(test.GroundcoverAuthoringTest))
assert result.testsRun==2 and len(result.failures)==1 and len(result.errors)==1
assert 'Retained flowers moved' in result.failures[0][1]
assert 'IndexError: list index out of range' in result.errors[0][1]
print('EXPECTED NEGATIVE: both new regressions detect the old builder')
