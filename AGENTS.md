# Contributor instructions

Keep changes focused and preserve existing behavior unless a change is explicitly requested. Follow CONTRIBUTING.md and document public behavior in README.md.

## Changelog and pull requests

Add entries under the current `(Next)` heading in CHANGELOG.md and retain `Your contribution here`. Include the implementation PR number, its URL, and contributor attribution using this format:

```markdown
* [#123](https://github.com/dblock/ruby-link-checker/pull/123): Describe the change - [@contributor](https://github.com/contributor).
```

Predict the PR number before opening a new PR, then verify the assigned number and correct the entry if necessary. Issue references may supplement but do not replace the implementation PR link.

Keep Markdown paragraphs on one line. Keep each PR branch to one commit, squash follow-up changes before pushing, and use `--force-with-lease` when updating rewritten PR history. Never force-push the default branch.

## Validation

Run focused RSpec tests for behavior changes and `bundle exec rubocop` before committing. `bundle exec rake` runs both the full specs and RuboCop. Avoid repeated intermediate test runs; rerun when failures or subsequent changes require it.

For changelog or README changes, run `bundle exec danger dry_run --base=origin/main`; Danger checks changelog entries and README table-of-contents consistency. Keep the temporary `git < 6` dependency pin until Danger supports git 6; the Gemfile comment links the upstream fix.

Do not commit Gemfile.lock; this repository ignores it. Include `Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>` in AI-assisted commits and disclose AI involvement when posting GitHub comments on behalf of the user.
