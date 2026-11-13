"""Generate a public, immutable catalog of shipped code; never scan user data."""
import hashlib
import json
import pathlib
import re
import sys

desktop = pathlib.Path(__file__).resolve().parents[1] / 'desktop'
installed = pathlib.Path(sys.argv[1]).resolve()
distribution = desktop.parent
assert hashlib.sha256((installed / 'manifest.json').read_bytes()).digest() == hashlib.sha256((distribution / 'manifest.json').read_bytes()).digest()
sources = {}
identifiers = set()
for subtree in ('eeglab2026.1.0', 'dependencies'):
    for path in (installed / subtree).rglob('*.m'):
        relative = path.relative_to(installed).as_posix().lower()
        sources['s' + hashlib.sha256(relative.encode('utf-8')).hexdigest()[:32]] = relative
        identifiers.update(re.findall(r"['\"]([A-Za-z][A-Za-z0-9_]*(?::[A-Za-z][A-Za-z0-9_]*)+)['\"]", path.read_text(encoding='utf-8', errors='replace')))
for path in list(distribution.glob('*.m')) + list(desktop.glob('*.m')):
    relative = path.name.lower()
    sources['s' + hashlib.sha256(relative.encode('utf-8')).hexdigest()[:32]] = relative
    identifiers.update(re.findall(r"['\"]([A-Za-z][A-Za-z0-9_]*(?::[A-Za-z][A-Za-z0-9_]*)+)['\"]", path.read_text(encoding='utf-8', errors='replace')))
catalog = {'schemaVersion': 1, 'release': json.loads((desktop / 'release.json').read_text(encoding='utf-8'))['version'], 'sources': sources}
catalog_path = desktop / 'diagnostic-sources.json'
previous = []
if catalog_path.exists():
    old = json.loads(catalog_path.read_text(encoding='utf-8'))
    previous = old.get('previous', [])
    if old['release'] != catalog['release']:
        previous = [{'schemaVersion': 1, 'release': old['release'], 'sources': old['sources']}] + previous
catalog['previous'] = previous
manifest = json.loads((distribution / 'manifest.json').read_text(encoding='utf-8-sig'))
components = sorted(set(['desktop', manifest['base']['name']] + [p['name'] for p in manifest['plugins'] + manifest['dependencies']]))
catalog['components'] = components
catalog['identifiers'] = sorted(identifiers)
for prior in previous:
    prior['components'] = components
    prior['identifiers'] = sorted(identifiers)
(desktop / 'diagnostic-sources.json').write_text(json.dumps(catalog, ensure_ascii=True, separators=(',', ':')) + '\n', encoding='utf-8')
(pathlib.Path(__file__).parent / 'diagnostic-sources.json').write_text(json.dumps(catalog, ensure_ascii=True, separators=(',', ':')) + '\n', encoding='utf-8')
print(f'Cataloged {len(sources)} shipped MATLAB source files; no recordings scanned.')
