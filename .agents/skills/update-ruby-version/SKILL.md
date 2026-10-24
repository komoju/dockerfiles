---
name: update-ruby-version
description: Add a new Ruby version to the rails-base and rails-buildpack build workflows. Replaces the existing entry with the same major.minor in both .github/workflows/build-rails-base.yml and .github/workflows/build-rails-buildpack.yml using freshly verified linux/amd64 image digests, adds the new version to .github/workflows/rebuild-images.yml, and appends the replaced (old) version to the historical lists in README.md.
---

# Update Ruby Version

Use this skill to add a new Ruby version to the build workflows in this repository.

## When to use

When the user asks to add, build, or update a Ruby version (e.g. "add Ruby 3.4.10", "update to Ruby 4.0.5", "build Ruby 3.3.12"). The skill handles the full mechanical change across three workflow files and the README.

## Steps

### 1. Get the target version

If the user did not already specify the version, ask them for a full `MAJOR.MINOR.PATCH` (e.g. `3.4.10`, `4.0.5`). Extract:

- `version` — the full version string (e.g. `3.4.10`)
- `major_minor` — the first two components joined with a dot (e.g. `3.4`)
- `major` — first component (e.g. `3`); used to build the folder name `<major>.x`

### 2. Look up the `linux/amd64` image digests

The two workflows use different tag suffixes:

- `build-rails-base.yml` uses `<version>-slim-bookworm` (the slim variant)
- `build-rails-buildpack.yml` uses `<version>-bookworm` (full variant)

Both images are built for **`linux/amd64` only**, so each workflow entry pins the digest of the **`linux/amd64` platform manifest**, never the multi-arch index digest and never the top-level `digest` field from the Docker Hub web API (`hub.docker.com/v2/...`). While a new release is still being published one architecture at a time, that field can point at another platform's manifest (e.g. `linux/386`), and the build then fails with `InvalidBaseImagePlatform`.

Resolve the digest from the registry's manifest index, verify the image config really is `linux/amd64`, and confirm the ECR Public mirror (`public.ecr.aws/docker/library/ruby`, which the Dockerfiles pull from) serves the same digest. Save this script to a scratch file that won't be committed (e.g. `tmp/amd64_digest.py`) and run it with both tags:

```python
import json, sys, urllib.request

ACCEPT = ", ".join([
    "application/vnd.oci.image.index.v1+json",
    "application/vnd.docker.distribution.manifest.list.v2+json",
    "application/vnd.oci.image.manifest.v1+json",
    "application/vnd.docker.distribution.manifest.v2+json",
])

def get(url, token, accept=ACCEPT):
    req = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}", "Accept": accept})
    with urllib.request.urlopen(req) as r:
        return json.load(r)

def amd64_digest(registry, repo, token, tag):
    index = get(f"https://{registry}/v2/{repo}/manifests/{tag}", token)
    matches = [m["digest"] for m in index["manifests"]
               if m.get("platform", {}).get("os") == "linux" and m["platform"].get("architecture") == "amd64"]
    assert len(matches) == 1, f"{tag}: expected one linux/amd64 manifest, found {matches}"
    digest = matches[0]
    manifest = get(f"https://{registry}/v2/{repo}/manifests/{digest}", token)
    config = get(f"https://{registry}/v2/{repo}/blobs/{manifest['config']['digest']}", token, "*/*")
    assert (config["os"], config["architecture"]) == ("linux", "amd64"), f"{tag}: config is {config['os']}/{config['architecture']}"
    return digest

hub_token = json.load(urllib.request.urlopen("https://auth.docker.io/token?service=registry.docker.io&scope=repository:library/ruby:pull"))["token"]
ecr_token = json.load(urllib.request.urlopen("https://public.ecr.aws/token?scope=repository:docker/library/ruby:pull"))["token"]
for tag in sys.argv[1:]:
    hub = amd64_digest("registry-1.docker.io", "library/ruby", hub_token, tag)
    ecr = amd64_digest("public.ecr.aws", "docker/library/ruby", ecr_token, tag)
    assert hub == ecr, f"{tag}: Docker Hub {hub} != ECR mirror {ecr}"
    print(tag, hub)
```

```bash
python3 -I tmp/amd64_digest.py <version>-slim-bookworm <version>-bookworm
```

If a request fails with a 404, stop and tell the user the tag does not exist yet (Ruby images are usually published to Docker Hub within a day or two of the official release). If an assertion fails (no `linux/amd64` manifest yet, wrong config platform, or the ECR mirror hasn't caught up), stop and tell the user the image isn't fully published; retry later rather than using any other digest.

### 3. Update `.github/workflows/build-rails-base.yml`

Read the file. Find the matrix entry whose `ruby:` value starts with `<major_minor>.` — for example, to add `3.4.10` you replace the entry for `3.4.9`. Capture that old version string so you can later append it to the README.

Replace the entry in-place. The format must remain exactly:

```yaml
          - ruby: '<version>'
            folder: '<major>.x' # slim bookworm for linux/amd64
            tag: '<version>-slim-bookworm@<digest-from-step-2>'
```

Edit the entry in-place, preserving the surrounding format, indentation (10 spaces before `- ruby:`, 12 spaces before the other two keys), and inline comment exactly as shown.

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

### 6. Update `.github/workflows/rebuild-images.yml`

This workflow rebuilds every published image when a security fix needs to be layered on top of them, so it must list each new version as soon as it is published. Add two matrix entries for the **new version**, one per repository:

```yaml
          - { repository: rails-base, tag: '<version>' }
          - { repository: rails-buildpack, tag: '<version>' }
```

Insert each entry into its repository's group, keeping the list in ascending version order. Do not remove the replaced version; its published image still needs to be rebuilt. If the replaced version is missing from either group, add it too.

### 7. Report back

Summarize in 2–3 lines: which version was added, which version it replaced, and the three workflow files plus the README that were updated. Remind the user to open a PR titled along the lines of "Build docker image for Ruby `<version>`" — that matches the existing commit-message convention in `git log`.

## Notes

- The matrix in each build workflow currently holds exactly four entries (one per supported `MAJOR.MINOR` line). The skill preserves that — it replaces, it does not append.
- Digests for older entries in the workflow are **not** refreshed. Docker Hub tags are mutable, so the digest captured at the time of an earlier PR may no longer match the live tag — that's expected; leave it alone.
- Some older entries pin a multi-arch index digest from before this skill required `linux/amd64` digests. Leave them as they are; only new entries must use the verified `linux/amd64` digest from step 2.
- The `folder` value (`3.x` or `4.x`) corresponds to a real directory under `rails-base/` and `rails-buildpack/`. If the user requests a version whose `<major>.x` folder does not exist, stop and tell them — adding a new major needs new Dockerfiles, which is out of scope for this skill.
