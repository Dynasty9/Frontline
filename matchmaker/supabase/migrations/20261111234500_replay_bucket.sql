-- Spectator recordings (src/replays.js, REPLAY_BUCKET=replays): a battle the
-- host broadcasts, kept a week, as JSON files in this bucket. Private: only
-- the matchmaker reads and writes it, with the project's secret key, which
-- bypasses row-level security. There are no policies, so nobody signed in or
-- not can list, read or write it directly; viewers get recordings through the
-- matchmaker. A chunk is at most 12 MB (REPLAY_BODY), so 16 MB a file.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('replays', 'replays', false, 16777216, array['application/json'])
on conflict (id) do nothing;
