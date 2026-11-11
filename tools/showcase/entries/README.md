# One presentation record per change

Add `<entry-slug>.json` here alongside your changelog entry. The file contains one
record, using the same fields as an item in the legacy catalog:

```json
{
  "entry": "changelog/unreleased/example-fix.md",
  "summary": "The player-facing result.",
  "medium": "text",
  "stage": "text",
  "rationale": "This is an invisible reliability fix; explain the result.",
  "source_ref": "the-source-commit",
  "sources": [],
  "output": null
}
```

For evidence files, retain `sources` with each `file` and `sha256`, plus any capture
settings and provenance used by the existing records. The audit still checks
coverage, duplicate entries, missing assets and changed hashes. The renderer reads
the same combined inventory. No generated combined file is committed.

Do not append new records to `../catalog.json`. It remains readable for historical
records and older open PRs, so no mass migration is needed. To migrate an existing
PR, remove only the records that PR added to the array and save each here instead.
Never keep the same record in both places: the audit rejects duplicates.

Keep this filename after release filing. The audit follows the entry and its assets
from `changelog/unreleased/` into the release directory, as before. If a slug was
already used, choose a distinct filename; the record's `entry` identifies the actual
changelog path. Edits to the same change may still conflict and need review.

Validate with `python tools/showcase/audit.py`.
