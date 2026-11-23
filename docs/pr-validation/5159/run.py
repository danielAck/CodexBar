#!/usr/bin/env python3
"""Opt-in, synthetic response-boundary proof; never installs or launches the app."""
from pathlib import Path
import argparse
import os
import shutil
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--repo', type=Path, required=True)
parser.add_argument('--plugin-ref', help='Use only the bundled JS from this Git revision for a baseline comparison')
args = parser.parse_args()
repo = args.repo.resolve()
assets = Path(__file__).resolve().parent
jar = repo / 'Sources/CodexBarCore/Plugins/ProviderPluginCookieJar.swift'
plugin = repo / 'Sources/CodexBarCore/Resources/Plugins/gemini-web.js'
core = repo / 'Sources/CodexBarCore/Plugins/GeminiBoundaryProofProtocol.swift'
test = repo / 'TestsPlugin/GeminiBoundaryProofTests.swift'
if core.exists() or test.exists():
    raise SystemExit('Refusing to overwrite existing proof files')
for path in (jar, plugin):
    if subprocess.check_output(['git', 'status', '--porcelain', '--', str(path)], cwd=repo):
        raise SystemExit('Refusing to overlay modified source: ' + str(path.relative_to(repo)))
jar_original = jar.read_bytes()
plugin_original = plugin.read_bytes()
config = '        configuration.httpCookieStorage = nil'
branch = '        if let client = self.base as? ProviderHTTPClient, client === ProviderHTTPClient.shared {'
source = jar_original.decode()
if source.count(config) != 1 or source.count(branch) != 1:
    raise SystemExit('Production transport shape changed; inspect before updating the overlay')
env = dict(os.environ, CODEXBAR_SUPPRESS_TEST_KEYCHAIN_ACCESS='1')
with tempfile.TemporaryDirectory(prefix='gemini-boundary-proof-') as backup_dir:
    backup = Path(backup_dir)
    (backup / 'ProviderPluginCookieJar.swift').write_bytes(jar_original)
    (backup / 'gemini-web.js').write_bytes(plugin_original)
    try:
        shutil.copy2(assets / core.name, core)
        shutil.copy2(assets / test.name, test)
        source = source.replace(config, '        configuration.protocolClasses = [GeminiBoundaryProofProtocol.self]\n' + config)
        source = source.replace(branch, branch + '\n            GeminiBoundaryProofProtocol.enteredProductionTransport()')
        jar.write_text(source)
        if args.plugin_ref:
            plugin.write_bytes(subprocess.check_output(
                ['git', 'show', args.plugin_ref + ':' + str(plugin.relative_to(repo))], cwd=repo))
        result = subprocess.run(['swift', 'test', '--filter', 'GeminiBoundaryProofTests'], cwd=repo, env=env)
    finally:
        jar.write_bytes(jar_original)
        plugin.write_bytes(plugin_original)
        core.unlink(missing_ok=True)
        test.unlink(missing_ok=True)
raise SystemExit(result.returncode)
