"""Render interactive resource variants using Godot's actual mesh/material path."""
import argparse
from pathlib import Path
import subprocess
import tempfile
from validation_support import isolated_env, validation_editor
from validate_godot import ERROR

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--renderer', default='gl_compatibility', choices=['gl_compatibility','forward_plus'])
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True,exist_ok=True)
    with validation_editor(args.godot) as engine, tempfile.TemporaryDirectory(prefix='resources-render-') as userdata:
        result = subprocess.run([str(engine),'--path',str(Path(__file__).resolve().parents[1]),
            '--rendering-method',args.renderer,'--audio-driver','Dummy','--resolution','1600x1000',
            '--script','res://tools/review_resource_visuals.gd','--','--capture',str(output)],
            env=isolated_env(Path(userdata)),capture_output=True,text=True,timeout=120)
    (output/'runtime.log').write_text(result.stdout+result.stderr)
    if result.returncode or ERROR.search(result.stdout+result.stderr) or 'RESOURCE_REVIEW_PASSED' not in result.stdout:
        raise RuntimeError(f'Resource render failed: {output / "runtime.log"}')
    if not all((output/name).is_file() for name in ['resource_variants.png','nest_detail.png']):
        raise RuntimeError('Missing native resource captures')
    print(f'Resource rendering passed: {output}')

if __name__ == '__main__':
    main()
