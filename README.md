# Public Boards

Static public execution boards published automatically from their source
repositories.

- [ASR theory board](https://maryna-mudria.github.io/public-boards/asr/)
- [Call AI execution board](https://maryna-mudria.github.io/public-boards/call-ai/)
- [BST SKUD execution board](https://maryna-mudria.github.io/public-boards/skud/)
- [SKUD Client execution board](https://maryna-mudria.github.io/public-boards/client-skud/)

## Reviewed manual publication

The source repository remains canonical. Do not edit a published board by
hand. Use this fallback only after the source change is merged and its normal
publication workflow cannot start because GitHub Actions is unavailable.

1. Create a `chore/` branch from the latest `main` in this repository.
2. Run `scripts/publish-board.sh` from this repository with
   `PUBLISH_TARGET_REF` set to that branch. Pass the canonical HTML path,
   allowlisted public target, source repository, and merged source SHA.
3. Repeat the command on the same branch for every board that needs
   publication.
4. Open a pull request, wait for the public-tree and validator checks, review
   the generated board diff, and merge it.
5. Confirm the Pages deployment and compare the published file with the
   canonical source.

Example:

```bash
PUBLISH_TARGET_REF=chore/sync-call-ai-20260730 \
  scripts/publish-board.sh \
  /absolute/path/to/source/frontend/public/internal/exec-board-7f3q2/index.html \
  call-ai/index.html \
  maryna-mudria/call_ai_mvp_offline \
  MERGED_SOURCE_SHA
```

Without `PUBLISH_TARGET_REF`, the publisher keeps its automated behavior and
publishes directly to `main`.
