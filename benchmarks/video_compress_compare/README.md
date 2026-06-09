# video_compress compare

Local benchmark harness for comparing `vidsqueeze` against `video_compress`.

This app is not the public package example. It is an internal benchmark runner so the main `example/` app stays focused on the `vidsqueeze` API.

## Run

```bash
cd benchmarks/video_compress_compare
flutter run -d <device-id>
```

## Presets

| Preset | vidsqueeze |
|---|---|
| Quality | `quality` |
| Balanced | `balanced` |
| Small | `smallSize` |

## Resolution Mapping

| UI Resolution | vidsqueeze | video_compress |
|---|---|---|
| Original | no cap | `HighestQuality` |
| 1080p | `maxResolutionCap: 1080` | `Res1920x1080Quality` |
| 720p | `maxResolutionCap: 720` | `Res1280x720Quality` |
| 540p | `maxResolutionCap: 540` | `Res960x540Quality` |
| 480p | `maxResolutionCap: 480` | `Res640x480Quality` |

## Run Order

When both engines are enabled, each measured run executes in this order:

1. Run `video_compress` until `compressVideo` returns.
2. Record output size and elapsed time.
3. Wait 10 seconds.
4. Run `vidsqueeze`.
5. Record output size and elapsed time.

Results are shown from the main screen summary through a dedicated details page. The details page includes per-run comparisons, size winner, time winner, output delta, and vertical raw result cards for each engine. Raw cards include status, elapsed time, source size, output size, saved percentage, resolution, output path, and full error text when a competitor plugin returns null.

By default, `vidsqueeze` is forced to AVC because `video_compress` does not expose codec choice. Disable that toggle to measure `vidsqueeze` HEVC behavior separately.

## Fair Benchmark Notes

- Use the same source video.
- Run on the same device and thermal state.
- Prefer 1 warmup run, then 3 measured runs.
- Compare AVC-to-AVC for fair results.
- Treat `vidsqueeze` HEVC results as platform advantage results, not direct codec-equivalent results.
- If `video_compress` returns null, the harness retries with `DefaultQuality`, `MediumQuality`, then `LowQuality`. Fallback use is shown in the result status. If all attempts return null, the harness records the full retry chain and continues to the `vidsqueeze` run.

## Repository Hygiene

- This harness is intentionally kept outside the public `example/` app.
- The vendored `video_compress` package is used only for deterministic benchmark behavior.
- Vendored competitor examples and generated build outputs are ignored from git.
