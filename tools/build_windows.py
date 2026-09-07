"""Export, exercise the actual Windows executable, and package a player release."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--godot', required=True, help='Godot 4.7.1 console executable')
    args = parser.parse_args()
    godot = str(Path(args.godot).resolve())
    output = ROOT / 'delivery/windows'
    output.mkdir(parents=True, exist_ok=True)
    (ROOT / 'delivery/.gdignore').touch()
    (output / 'captures').mkdir(exist_ok=True)
    logs = ROOT / '.runtime/windows-build'
    logs.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    env['APPDATA'] = str(logs / 'userdata')
    Path(env['APPDATA']).mkdir(exist_ok=True)

    def run(exe, arguments, name, marker=None, cwd=ROOT):
        log = logs / (name + '.log')
        if log.exists():
            log.write_text('', encoding='utf-8')
        print('RUN', name, flush=True)
        completed = subprocess.run([exe, '--log-file', str(log), *arguments], cwd=cwd,
                                   env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                   timeout=600)
        text = log.read_text(encoding='utf-8', errors='replace') if log.exists() else ''
        text += completed.stdout.decode('utf-8', errors='replace')
        # Existing scene tests leave references alive during forced tree shutdown.
        # Keep that specific teardown diagnostic in logs, but reject all other errors.
        checked = re.sub(r'(?m)^ERROR: \d+ resources still in use at exit.*$', '', text) if marker else text
        if completed.returncode or re.search(r'SCRIPT ERROR|Parse Error|Failed to export|ERROR:', checked):
            print(text[-18000:])
            raise RuntimeError(name + ' failed')
        if marker and not re.search(marker + r' passed=\d+ failed=0', text):
            print(text[-18000:])
            raise RuntimeError(name + ' did not report passing checks')
        if marker:
            print(re.search(marker + r' passed=\d+ failed=0', text).group(), flush=True)

    run(godot, ['--headless', '--editor', '--import', '--path', str(ROOT)], 'import')
    run(godot, ['--headless', '--path', str(ROOT), '--export-release', 'Windows Desktop',
                str(output / 'RAINROT.exe')], 'export')
    exe = output / 'RAINROT.exe'
    if exe.read_bytes()[:2] != b'MZ' or not (output / 'RAINROT.pck').is_file():
        raise RuntimeError('Missing Windows executable or resource pack')
    for flag, marker in [('--test', 'TEST_RESULT'), ('--enemy-test', 'ENEMY_TEST_RESULT')]:
        run(str(exe), ['--headless', '--fixed-fps', '60', '--', flag], flag[2:], marker, output)

    shutil.copyfile(ROOT / 'docs/WINDOWS_PLAYER_README.txt', output / 'README_开始游戏.txt')
    for name in ['LICENSE', 'ASSET_LICENSES.md']:
        shutil.copyfile(ROOT / name, output / name)
    shutil.copyfile(ROOT / 'assets/fonts/OFL.txt', output / 'NOTO_OFL.txt')
    for name in ['GODOT_LICENSE.txt', 'GODOT_COPYRIGHT.txt']:
        shutil.copyfile(ROOT / '.runtime/windows-toolchain' / name, output / name)
    package_files = [exe, output / 'RAINROT.pck', output / 'README_开始游戏.txt',
                     output / 'LICENSE', output / 'ASSET_LICENSES.md', output / 'NOTO_OFL.txt',
                     output / 'GODOT_LICENSE.txt', output / 'GODOT_COPYRIGHT.txt']
    package_files += sorted(output.glob('*.dll'))
    archive_path = ROOT / 'delivery/RAINROT-Windows-x64.zip'
    with zipfile.ZipFile(archive_path, 'w', zipfile.ZIP_DEFLATED, compresslevel=7) as archive:
        for path in package_files:
            archive.write(path, 'RAINROT/' + path.name)
    with zipfile.ZipFile(archive_path) as archive:
        if archive.testzip() is not None:
            raise RuntimeError('ZIP integrity check failed')
    digest = hashlib.sha256(archive_path.read_bytes()).hexdigest()
    archive_path.with_suffix('.zip.sha256').write_text(digest + '  ' + archive_path.name + '\n', encoding='ascii')
    print(json.dumps({'package':str(archive_path), 'MiB':round(archive_path.stat().st_size / 1048576, 1),
                      'sha256':digest}, indent=2), flush=True)


if __name__ == '__main__':
    main()
