#!/usr/bin/env bash
# The database's migrations in a pull request, against the branch it merges
# into (usage: check-migrations.sh origin/main). From the repository root.
#
# A migration on main is history: the release has applied it to the live
# database, so editing or removing it changes nothing there and only makes a
# fresh database differ from the live one. A change to the schema is a new
# migration. And a new one has to come after every migration already on main,
# or `supabase db push` refuses it (one merged first went past it in the
# meantime): give it a new timestamp.
set -euo pipefail

base="${1:?usage: check-migrations.sh <base ref>}"
dir=matchmaker/supabase/migrations
fail=0

changed=$(git diff --name-status --no-renames "$base"...HEAD -- "$dir" | awk '$1 != "A"' || true)
if [ -n "$changed" ]; then
	echo "::error::Migrations already on the base branch were changed or removed. Put the change in a new migration instead:"
	echo "$changed"
	fail=1
fi

newest=$(git ls-tree --name-only "$base" "$dir/" | sed 's#.*/##' | grep -E '^[0-9]{14}_' | sort | tail -n 1 | cut -c1-14 || true)
for f in $(git diff --name-only --diff-filter=A "$base"...HEAD -- "$dir"); do
	name=$(basename "$f")
	if ! [[ "$name" =~ ^[0-9]{14}_[a-z0-9_]+\.sql$ ]]; then
		echo "::error file=$f::A migration is named <14-digit UTC timestamp>_<name>.sql (supabase migration new <name> makes one)."
		fail=1
	elif [ -n "$newest" ] && [[ ! "${name:0:14}" > "$newest" ]]; then
		echo "::error file=$f::$name comes before $newest, the newest migration on the base branch, so the release couldn't apply it. Rename it with a timestamp from now."
		fail=1
	else
		echo "new migration: $name"
	fi
done

exit $fail
