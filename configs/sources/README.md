# Third-party source pins

Each JSON file declares one upstream component. Build scripts fetch sources into
`.cache/sources/` at compile time — nothing is vendored in git.

## Example: bump mpv

Edit [`mpv.json`](mpv.json):

```json
{
  "ref": "v0.42.0",
  "commit": "<full commit hash from GitHub release tag>"
}
```

Then run:

```bash
./scripts/fetch-sources.sh mpv
PROFILE=gpl ./scripts/build-libmpv.sh
```

## Fields

| Field | Used by | Meaning |
|-------|---------|---------|
| `method` | all | `git` or `tarball` |
| `repository` + `ref` + `commit` | git | Clone URL, tag/branch, optional exact commit pin |
| `version` + `url` | tarball | Release version and download URL |

## Pre-fetch all sources

```bash
./scripts/fetch-sources.sh all
```
