---
name: update-ruby-version
description: Add a new Ruby version to the rails-base and rails-buildpack build workflows. Replaces the existing entry with the same major.minor in both .github/workflows/build-rails-base.yml and .github/workflows/build-rails-buildpack.yml using fresh digests from Docker Hub, and appends the replaced (old) version to the historical lists in README.md.
---

# Update Ruby Version

Use this skill to add a new Ruby version to the build workflows in this repository.

## When to use

When the user asks to add, build, or update a Ruby version (e.g. "add Ruby 3.4.10", "update to Ruby 4.0.5", "build Ruby 3.3.12"). The skill handles the full mechanical change across two workflow files and the README.

## Steps

### 1. Get the target version

If the user did not already specify the version, ask them using `AskUserQuestion`. Expect a full `MAJOR.MINOR.PATCH` (e.g. `3.4.10`, `4.0.5`). Extract:

- `version` — the full version string (e.g. `3.4.10`)
- `major_minor` — the first two components joined with a dot (e.g. `3.4`)
- `major` — first component (e.g. `3`); used to build the folder name `<major>.x`

### 2. Look up Docker Hub digests

The two workflows use different tag suffixes:

- `build-rails-base.yml` uses `<version>-slim-bookworm` (the slim variant)
- `build-rails-buildpack.yml` uses `<version>-bookworm` (full variant)

Both entries in the workflow encode the **multi-arch manifest list digest** (the top-level `digest` field returned by the Docker Hub Registry API). Fetch both in parallel using two Bash calls:

```bash
curl -fsS "https://hub.docker.com/v2/repositories/library/ruby/tags/<version>-slim-bookworm/" \
  | python3 -c "import sys, json; print(json.load(sys.stdin)['digest'])"
```

```bash
curl -fsS "https://hub.docker.com/v2/repositories/library/ruby/tags/<version>-bookworm/" \
  | python3 -c "import sys, json; print(json.load(sys.stdin)['digest'])"
```

If either request fails with a 404 or the JSON is missing the `digest` key, stop and tell the user the tag does not exist on Docker Hub yet (Ruby images are usually published to Docker Hub within a day or two of the official release).

### 3. Update `.github/workflows/build-rails-base.yml`

Read the file. Find the matrix entry whose `ruby:` value starts with `<major_minor>.` — for example, to add `3.4.10` you replace the entry for `3.4.9`. Capture that old version string so you can later append it to the README.

Replace the entry in-place. The format must remain exactly:

```yaml
          - ruby: '<version>'
            folder: '<major>.x' # slim bookworm for linux/amd64
            tag: '<version>-slim-bookworm@<digest-from-step-2>'
```

Use `Edit` with enough surrounding context to make the `old_string` unique. Keep the indentation (10 spaces before `- ruby:`, 12 spaces before the other two keys) and the inline comment exactly as shown.

If no matrix entry matches the `major_minor`, stop and ask the user how to proceed (this means a brand-new minor line is being introduced — the skill's "replace" behavior doesn't apply, and the user should decide whether to add a fifth matrix entry instead).

### 4. Update `.github/workflows/build-rails-buildpack.yml`

Same procedure as step 3, but:

- The tag suffix is `-bookworm` (not `-slim-bookworm`)
- The inline comment reads `# bookworm for linux/amd64` (no "slim")
- Use the buildpack digest from step 2

### 5. Update `README.md`

The README has two `Older …` sections — one under `# rails-base` and one under `# rails-buildpack`. In each section, append the **old version** (the one that was just replaced in the workflow) to the matching `# Ruby <major_minor>` block, preserving the existing ordering and indentation.

- Under `## Older base images`, add the line `public.ecr.aws/degica/rails-base:<old-version>` to the `# Ruby <major_minor>` block.
- Under `## Older buildpacks`, add the line `public.ecr.aws/degica/rails-buildpack:<old-version>` to the `# Ruby <major_minor>` block.

Each list is in ascending version order; insert at the end of its block (before the next blank line / next `# Ruby …` header). If the `# Ruby <major_minor>` block does not exist yet in the README, create it in the correct major-then-minor sorted position.

Both URLs use the same `<old-version>` — do **not** add the new version to the README, only the version it replaced.

### 6. Report back

Summarize in 2–3 lines: which version was added, which version it replaced, and the two files plus the README that were updated. Remind the user to open a PR titled along the lines of "Build docker image for Ruby `<version>`" — that matches the existing commit-message convention in `git log`.

## Notes

- The matrix in each workflow currently holds exactly four entries (one per supported `MAJOR.MINOR` line). The skill preserves that — it replaces, it does not append.
- Digests for older entries in the workflow are **not** refreshed. Docker Hub tags are mutable, so the digest captured at the time of an earlier PR may no longer match the live tag — that's expected; leave it alone.
- The `folder` value (`3.x` or `4.x`) corresponds to a real directory under `rails-base/` and `rails-buildpack/`. If the user requests a version whose `<major>.x` folder does not exist, stop and tell them — adding a new major needs new Dockerfiles, which is out of scope for this skill.
