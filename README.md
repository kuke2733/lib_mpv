# lib_mpv

Multi-platform **libmpv** build and distribution repository. Phase 1 targets **Windows x86_64** with two license profiles:

| Profile | License | Use case |
|---------|---------|----------|
| **gpl** | GPLv2+ | Open-source projects; full feature set including CD/DVD, rubberband, VapourSynth |
| **lgpl** | LGPLv2.1+ | Proprietary embedding; LGPL-compatible ffmpeg built from source |

Each build produces a portable SDK zip: `libmpv-2.dll`, headers, import libraries, and all runtime dependency DLLs legal under that profile.

## Source management (no submodule)

Upstream versions are **not** checked into git. Pin releases under [`configs/sources/`](configs/sources/) — one JSON file per component:

- [`configs/sources/mpv.json`](configs/sources/mpv.json) — git tag + commit
- [`configs/sources/ffmpeg.json`](configs/sources/ffmpeg.json) — tarball URL (LGPL build)

At build time, `scripts/fetch-sources.sh` downloads into `.cache/sources/`. To bump mpv, edit the JSON and rebuild.

## Quick start (CI)

Push to `main` or run **Actions → Build Windows x86_64 → Run workflow**. Artifacts:

- `libmpv-<version>-windows-x86_64-gpl.zip`
- `libmpv-<version>-windows-x86_64-lgpl.zip`

## Local build (MSYS2 CLANG64)

```bash
# Optional: pre-fetch upstream sources
./scripts/fetch-sources.sh all

# GPL
PROFILE=gpl ./scripts/build-libmpv.sh
PROFILE=gpl ./scripts/collect-deps.sh
PROFILE=gpl ./scripts/verify-license.sh
PROFILE=gpl ./scripts/package-windows.sh

# LGPL (builds ffmpeg from source; takes longer)
PROFILE=lgpl ./scripts/build-libmpv.sh
PROFILE=lgpl ./scripts/collect-deps.sh
PROFILE=lgpl ./scripts/verify-license.sh
PROFILE=lgpl ./scripts/package-windows.sh
```

Output: `dist/gpl/*.zip` and `dist/lgpl/*.zip`.

## Offline checks

```bash
bash scripts/validate-repo.sh
```

After a local or CI build:

```bash
PROFILE=gpl bash scripts/validate-package.sh
```

## License notice

This repository provides build scripts only. **mpv**, **ffmpeg**, and bundled libraries retain their original licenses. Choose the **gpl** or **lgpl** artifact according to your project's licensing requirements. This is not legal advice.

## References

- [mpv compile-windows.md](https://github.com/mpv-player/mpv/blob/master/DOCS/compile-windows.md)
- [mpv meson.options](https://github.com/mpv-player/mpv/blob/master/meson.options)
