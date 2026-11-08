# Releasing ruby-link-checker

There are no hard rules about when to release ruby-link-checker. Release bug fixes frequently, features not so frequently and breaking API changes rarely.

Releases use [ruby-gem-release](https://github.com/dblock/ruby-gem-release/tree/v0.3.1) and the manual [Release workflow](.github/workflows/release.yml). Merges do not publish. Every workflow dispatch performs a real release.

## One-Time Setup

Create a GitHub environment named `release` in this repository. Restrict deployment to `main` and require approval when available.

On [RubyGems.org](https://rubygems.org/gems/ruby-link-checker/trusted_publishers), configure a trusted publisher with repository owner `dblock`, repository name `ruby-link-checker`, workflow filename `release.yml`, and environment `release`. Set the separate workflow repository owner to `dblock` and name to `ruby-gem-release` because publication uses its reusable workflow. No stored RubyGems API key is needed.

The workflow requests `contents: write` and `id-token: write`. Branch rules must allow the release identity to push fast-forward release and next-version commits to `main` and create tags, without allowing force pushes or deletion. Adding the workflow does not configure these permissions or the trusted publisher.

## Prepare and Publish

Prepare the intended version in `lib/ruby-link-checker/version.rb` and its matching `### VERSION (Next)` section in `CHANGELOG.md` through a PR. Keep exactly one `* Your contribution here.` placeholder in that section. The workflow releases the current version, dates the changelog, and removes the placeholder; it does not select a new release version.

Run tests and RuboCop locally and review the release changes before merging:

```sh
bundle exec rake
```

After merging, explicit release approval, and successful Trusted Publishing setup, dispatch from `main`:

```sh
gh workflow run release.yml --ref main
```

The workflow runs `bundle exec rake`, publishes the verified gem to RubyGems, pushes the release commit and tag atomically, and creates a GitHub Release with the gem attached. It then increments the patch version and pushes a new development commit with a fresh changelog section. Actions-token pushes do not trigger ordinary push workflows, so the release workflow runs tests and RuboCop before publication.

## Verify and Recover

Verify the published RubyGems version, matching tag and GitHub Release, attached gem, and next development version on `main`.

Never automatically rerun a failed or timed-out publication: RubyGems may have accepted the upload. Check registry and GitHub state first. Do not republish an existing version or move its tag. Available `release.gem`, `release.json`, and `release.bundle` recovery artifacts are retained for 30 days; follow the [upstream recovery instructions](https://github.com/dblock/ruby-gem-release/blob/v0.3.1/RELEASING.md#verify-and-recover) to complete only the missing steps.
