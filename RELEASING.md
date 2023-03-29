# Releasing ruby-link-checker

There are no hard rules about when to release ruby-link-checker. Release bug fixes frequently, features not so frequently and breaking API changes rarely.

### Release

Run tests, check that all tests succeed locally.

```
bundle install
rake
```

Check that the last build succeeded.

Add a date to this release in [CHANGELOG.md](CHANGELOG.md).

```
### 0.2.2 (2015/7/10)
```

Remove the line with "Your contribution here.", since there will be no more contributions to this release.

Commit your changes.

```
git add README.md CHANGELOG.md lib/ruby-link-checker/version.rb
git commit -m "Preparing for release, 0.2.2."
```

Release.

```
$ rake release

ruby-link-checker 0.2.2 built to pkg/ruby-link-checker-0.2.2.gem.
Tagged v0.2.2.
Pushed git commits and tags.
Pushed ruby-link-checker 0.2.2 to rubygems.org.
```

### Prepare for the Next Version

Add the next release to [CHANGELOG.md](CHANGELOG.md).

```
### 0.2.3 (Next)

* Your contribution here.
```

Increment the third version number in [lib/ruby-link-checker/version.rb](lib/ruby-link-checker/version.rb).

Commit your changes.

```
git add CHANGELOG.md lib/ruby-link-checker/version.rb
git commit -m "Preparing for next development iteration, 0.2.3."
git push origin main
```
