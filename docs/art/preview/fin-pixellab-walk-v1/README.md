# Fin PixelLab south walk trial 1 — 2026-09-14

Status: generated, static frame review complete; NOT approved for gameplay. No gameplay assets or combat parameters changed. No automatic retry.

User authorized uploading the existing Fin image and one eight-frame trial using trial allowance only, without additional payment. Used the explicitly selected PixelLab MCP service, not built-in image generation. Imagegen skill informed preservation constraints, input inspection, non-destructive storage, and output review.

- Tool: animate_image
- Job: 481e0b3c-7fda-495e-8cc4-070655f5c9d1
- Input: ../fin-resolution/front-64.png (native 66×96 including equipment; no resize/crop)
- Parameters: frame_count=8, no_background=true, seed=91401
- Cost returned: 1 generation
- Balance before: trial 40 remaining / 0 used / $0 credits
- Balance after: trial 39 remaining / 1 used / $0 credits
- Downloaded frame-0.png through frame-8.png, without pixel edits.
- frame-0 is the input; frames 1–8 are generated. All nine decoded as 66×96 and contain transparent pixels.
- Transparent pixel counts: 2957, 2985, 3090, 3235, 3271, 3381, 3388, 3304, 3194.
- preview.html displays original and animation at 4× nearest-neighbor, all frames at 2×, optional input-frame inclusion, pause, stepping and 4–16fps. Playback speed is a review choice, not a model-provided timing track.

## Review

All nine individual frames inspected. Palette, helmet, plume and equipment broadly survive. The leg poses vary rather than only translating one rigid image. However the sword swings substantially across the frame, the figure turns partly sideways, and the stance/silhouette narrows. This does not satisfy a stable south-facing walk. Foot-contact continuity and seamless looping are not certified by individual-frame review; inspect the interactive preview. Do not represent this as production-ready or as an improvement proven in the game.

## Exact action prompt

Walk in place facing south, toward the camera, for one complete seamless walking cycle. Alternate left and right foot contact, passing and lift poses with clearly articulated knees and ankles; each planted foot supports the body's weight. Keep both legs connected naturally to the hips, preserving their lengths and boot shapes. Small controlled vertical body movement, no side-to-side shaking or sliding. Hands maintain a firm grip on the sword and shield; equipment follows the arms subtly without switching sides. Keep the face, proportions, pixel art style, camera, scale and central position consistent with the input. No turning, no attack, no zoom, no added ground or shadow.

## Source

https://api.pixellab.ai/mcp/images/481e0b3c-7fda-495e-8cc4-070655f5c9d1/download?index=0

Change index to 1 through 8 for the generated frames. Local copies are the durable deliverable.
