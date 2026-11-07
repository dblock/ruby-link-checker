<img src="assets/logo.png" alt="A ruby gemstone launching like a rocket" width="160">

# Ruby Gem Release

[![Gem Version](https://img.shields.io/gem/v/ruby-gem-release.svg)](https://rubygems.org/gems/ruby-gem-release) [![Test](https://github.com/dblock/ruby-gem-release/actions/workflows/test.yml/badge.svg)](https://github.com/dblock/ruby-gem-release/actions/workflows/test.yml) [![Coverage Status](https://coveralls.io/repos/github/dblock/ruby-gem-release/badge.svg?branch=master)](https://coveralls.io/github/dblock/ruby-gem-release?branch=master)

**Release your Ruby gem from GitHub Actions—without maintaining custom release scripts or storing a RubyGems API key.**

Update your changelog, validate and publish your gem, create its GitHub Release, and prepare the next development version with one workflow dispatch. Choose your version and changelog formats; the standard workflow handles the release sequence.

- **No stored RubyGems API key:** Authenticate with RubyGems Trusted Publishing using OpenID Connect (OIDC).
- **Let collaborators release:** After one-time setup, collaborators with write access, including on personal repositories, can dispatch releases without repository admin access or their own RubyGems credentials.
- **Try it before publishing:** Dry runs exercise local commits, builds, and tags without uploading or pushing.
- **Keep your conventions:** Use the standard workflow or compose Ruby objects and callbacks for custom releases.

Requires Ruby 3.3+, GitHub Actions, and RubyGems Trusted Publishing.

## Usage

### 1. Configure Your Gem

Add `ruby-gem-release` (`~> 0.2.0`) to the development dependencies and install the standard workflow in your Rakefile. Choose your version file and changelog format explicitly:

```ruby
require 'ruby-gem-release/workflow/ruby_gem'
require 'ruby-gem-release/changelog'

RubyGemRelease::Workflow::RubyGem.new(
  version: RubyGemRelease::Version::RubyConstant.new(path: 'lib/example/version.rb', constant: 'VERSION'),
  changelog: RubyGemRelease::Changelog::KeepAChangelog.new
).install_tasks
```

The standard workflow handles changelog updates, publication, and the next development version, selecting the gemspec and repository using unambiguous defaults. See [Detailed Usage](docs/usage.md) for file examples and custom release callbacks.

### 2. Add the Release Workflow

Add `.github/workflows/release.yml` using the [sample workflow](examples/.github/workflows/release.yml), replacing the Ruby version with your project's value:

```yaml
name: Release

on:
  workflow_dispatch:
    inputs:
      rubygems-owner:
        description: RubyGems account ID for first publication; omit for an existing gem.
        type: string
        required: false

permissions:
  contents: write
  id-token: write

jobs:
  release:
    uses: dblock/ruby-gem-release/.github/workflows/release.yml@v0.2.0
    with:
      ruby-version: '3.3'
      rubygems-owner: ${{ inputs.rubygems-owner }}
```

### 3. Enable Trusted Publishing

In your GitHub repository, open **Settings → Environments** and create an environment named `release`. Alternatively, from your repository directory, use `gh`:

```sh
gh api --method PUT repos/{owner}/{repo}/environments/release
```

On [RubyGems.org](https://rubygems.org), open your gem's **Trusted publishers** page and create a [trusted publisher](https://guides.rubygems.org/trusted-publishing/#using-reusable-workflows). Set the repository fields to your gem's repository, the workflow filename to `release.yml`, and the environment to `release`. Set the separate workflow repository fields to `dblock` and `ruby-gem-release`; these identify the reusable workflow RubyGems verifies in the OIDC token. For a new gem, use the [pending trusted publishers page](https://rubygems.org/profile/oidc/pending_trusted_publishers) instead.

For example, the trusted publishers page for a gem named `example` is `https://rubygems.org/gems/example/trusted_publishers`.

### 4. Make a Release

Your branch rules must permit release commits and tags to be pushed; see [branch permissions](RELEASING.md#one-time-setup). Review the changes and dispatch the workflow from your default branch:

**First release:** Pass the numeric RubyGems account ID shown on the Pending Trusted Publishers page as `rubygems-owner`. This declares the account that will own the gem on its first publication. Replace `YOUR_ACCOUNT_ID` below with that ID:

```sh
gh workflow run release.yml -f rubygems-owner=YOUR_ACCOUNT_ID
```

**Subsequent releases:** Omit `rubygems-owner` once the gem exists. Its trusted publisher is still required, but the account ID is no longer needed:

```sh
gh workflow run release.yml
```

For a real-world example of adding release automation to an existing gem, see [ruby-link-checker #26](https://github.com/dblock/ruby-link-checker/pull/26). It adds the dependency, Rake tasks, reusable workflow, and release instructions while preserving the existing changelog format.

## Configuration

See [Detailed Usage](docs/usage.md#configuration) for workflow customization, callbacks, and available classes, and the [Actions Reference](docs/actions/release.md) for inputs and defaults.

For step-based integration, see the [Composite Action](docs/actions/action.md).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md), [DESIGN.md](DESIGN.md), [CHANGELOG.md](CHANGELOG.md), and [RELEASING.md](RELEASING.md).

## License

Distributed under the [MIT License](LICENSE.txt).
