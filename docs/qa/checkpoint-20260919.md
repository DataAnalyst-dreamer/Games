# Development checkpoint — 2026-09-19

This checkpoint preserves the current planning, content drafts, implementation, QA utilities, experimental assets and prototypes. It is not a release or a claim that all content is integrated.

## Fin animation status

- PixelLab walk v1, v2 and v3 were all rejected by the user as unsuitable walking motion. Preserve them as experiment evidence, not production-approved art.
- The quarter-view prototype still uses v1 only for south-facing idle/walk; other directions and combat use the legacy knight proxy. The slime remains the legacy proxy.
- v3 preview playback and its held-walk control work according to user confirmation; the remaining defect is animation quality, not frozen playback.
- Higgsfield was researched only. No account connection, upload, purchase or generation was performed.

## Reproduction limits

The local launch and QA scripts may reference workspace-specific runtime locations under the parent reviews directory and an existing Godot 4.4.1 executable. Engine binaries, local runtime logs, credentials, Python caches and the machine-specific quarter-view ready.json are not included in this checkpoint. A fresh clone is source/assets, not a one-click packaged release. Prepare the isolated prototype in a suitably configured environment before using its launcher.

Earlier QA results remain historical evidence; this commit operation does not constitute a new full gameplay/visual acceptance run.
