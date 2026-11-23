# CodexBar PR validation artifacts

These artifacts accompany steipete/CodexBar PRs #5158, #5159, and #5160. They distinguish observed runtime behavior, controlled fault injection, and remaining evidence gaps. No real account identifiers, credentials, redirect queries, or private endpoints are included.

## #5158: selected family display

- Functional source: PR e0bfc9421f5a46cac2ab3708830b74a32c2542d7, installed within aggregate ecce14dd18488d0c05c191f02a2846193d2b5977 (0.85.1, original bundle ID).
- Installed executable SHA256: ab5dc9c3e11b7be80028c00e524718fe623c440a5eb050dee52473b37459e6bb.
- The native macOS accessibility trace records the real picker changing from Gemini weekly to the dynamically reported family. The unedited settings screenshot shows its title and 88% remaining in the shared layout preview. Account rows are not in this screenshot.
- PR 637daec adds only architecture reasons and retargets the unchanged Cursor exemption fingerprint. The same 48-test gate fails before and passes after. Independent review found no relaxation of the analyzer.
- The physical menu-bar title and merged switcher are not yet captured here. The user reported the entry was not visible while settings was open; verification was stopped and the compact progress-bar style and original Gemini weekly selection were restored. This observation does not establish the disappearance root cause. The settings preview alone is not claimed as proof of those two surfaces.

## #5159: native transport response-boundary proof

Head: dbe7beea444345934b951b4147b59f6505c7e3a9. Baseline comparison substitutes only the bundled Gemini JavaScript from a26ca57b518667a659d69524c473af2735069612, holding the native transport and harness constant.

The opt-in overlay inserts a URLProtocol in the production cookie transport's ephemeral URLSession configuration, and adds a counter at the existing ProviderHTTPClient.shared identity branch. It does NOT replace ProviderHTTPTransport with a response stub. The real cookie jar, request construction, URLSession, response-header bridge, plugin engine, rejection loop, and error classification run. All application HTTP requests in this proof are intercepted locally (SwiftPM may download build dependencies); unexpected requests fail closed. Only synthetic cookie candidates are supplied; browser import is never invoked.

The fixture delivers a final 302 response at the URLSession response boundary. It does NOT simulate a live Google server or exercise a complete network redirect handshake. The actual CookieRedirectDelegate is separately checked for cross-origin rejection and same-origin cookie reapplication. This separation is intentional: URLProtocol's declined-redirect callback does not produce the normal final response on macOS.

Results on both QuickJS and JavaScriptCore:
- Head: sign-in redirect -> 2 native cookie-transport calls, 1 rejected candidate, success from candidate 2; verification redirect -> 1 call, 0 rejected candidates, actionable verification message with no query leakage.
- Baseline: generic HTTP 302 instead of both corrected outcomes.
- 3 named tests / 5 cases pass on head. Baseline records 6 issues; the delegate-only case passes on both.

Reproduce in an otherwise idle checkout of the head above with full Xcode/Swift toolchain:

```sh
python3 /path/to/5159/run.py --repo /path/to/CodexBar
python3 /path/to/5159/run.py --repo /path/to/CodexBar --plugin-ref a26ca57b518667a659d69524c473af2735069612
```

The second invocation is expected to fail the new behavioral assertions. The runner refuses to overlay modified target files and restores its temporary files in finally. Do not run concurrent builds or editors against these files during the proof. On this host, Command Line Tools-only build adaptations and focused target selection were additionally used; those build adaptations are not product changes or part of the PR.

This is production-boundary fault-injection evidence, not an observation of the unmodified shipped CLI contacting Google. The previously reported real Google verification/recovery observation remains separately described in the PR.

## #5160: restart and serialized compatibility

Source: 22f7162af503f526e0b6e7376e5271d0f6cf6860.

- installed-restart.txt records an actual installed app relaunch and production refresh on the same identified account, with unchanged preferences and no repeated family warning enqueue.
- seed/upgrade/restart-output.txt are separate process runs using synthetic dictionary-backed defaults serialized to a temporary plist. They prove absent-history initialization, preservation of existing preferences, persisted threshold suppression, and a new lower threshold. Each phase runs the full 14-test persistence suite.
- They are NOT a real fresh macOS install or an official stable app installation upgraded to this build. A delivered family-labeled system notification banner is also not captured here.

Reproduce the synthetic phases on PR #5160 with CODEXBAR_WARNING_PROOF_DIR pointing to one temporary directory and CODEXBAR_WARNING_PROOF_PHASE set to seed, then upgrade, then restart, in three separate `swift test --filter FamilyQuotaWarningPersistenceTests` invocations.
