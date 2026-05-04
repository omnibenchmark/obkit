# Release process

Tag-driven release flow. Pushing a `v<version>` tag triggers
`.github/workflows/release.yml`, which builds the Python and R packages,
publishes the Python wheel to PyPI via Trusted Publishing, and creates a
GitHub Release with both source tarballs attached.

Canonical repo: <https://github.com/omnibenchmark/obkit>.

## One-time setup

### PyPI Trusted Publishing

No API token is stored anywhere. PyPI mints a short-lived OIDC credential
at workflow run, bound to this repo + workflow file + environment.

1. On <https://pypi.org/manage/account/publishing/>, add a **pending
   publisher** for project name `obkit`:
   - Owner: `omnibenchmark`
   - Repository: `obkit`
   - Workflow filename: `release.yml`
   - Environment: `pypi`
2. In GitHub repo settings → Environments, create an environment named
   `pypi`. Optionally add required reviewers — the publish job will pause
   for human approval before uploading.

The pending publisher upgrades to a real one on first successful upload.

### GitHub permissions

The release workflow needs `contents: write` to create releases and
`id-token: write` to mint the PyPI OIDC token. Both are scoped per-job in
the workflow file; no repo-wide token grants are required.

Recommended hardening:
- Branch protection on `main` (required reviews).
- Required reviews on changes under `.github/workflows/`.
- Tag protection rule for `v*` so only maintainers can create release tags.

## Per-release checklist

1. **Bump versions** in both files (must match):
   - `python/pyproject.toml` → `project.version`
   - `r/obkit/DESCRIPTION` → `Version:`

   The workflow verifies that the tag matches both versions and fails
   loudly if they drift.
2. **Update READMEs** if install/usage changed
   (`python/README.md` is what PyPI renders).
3. **Run tests locally**:

   ```bash
   # Python
   cd python && uv run --with pytest --with-editable . pytest && cd -
   # R
   Rscript -e 'testthat::test_local("r/obkit")'
   ```
4. **Commit and push to main**.
5. **Tag and push**:

   ```bash
   git tag v<version>
   git push origin v<version>
   ```
6. **Watch the workflow** at
   <https://github.com/omnibenchmark/obkit/actions>. Approve the `pypi`
   environment if reviewers are required.
7. **Verify**: package appears on
   <https://pypi.org/project/obkit/> and a GitHub Release exists with
   both `obkit-<version>-py3-none-any.whl` / `.tar.gz` and
   `obkit_<version>.tar.gz` (R) attached.

## Local dry runs

Both packages can be built locally without uploading.

```bash
# Python
cd python && rm -rf dist build obkit.egg-info && uv build && uvx twine check dist/*

# R
R CMD build r/obkit
R CMD check --no-manual --as-cran obkit_*.tar.gz
```

## What gets shipped

- **Python wheel**: only `obkit/`. `tests/` is excluded by
  `[tool.setuptools.packages.find]` in `python/pyproject.toml`.
- **Python sdist**: includes `LICENSE`, `README.md`, `pyproject.toml`,
  and tests (harmless).
- **R tarball**: standard `R CMD build` output.

## Rolling back

PyPI does not allow re-uploading a yanked or deleted version. If a release
is broken:

1. Yank the version on PyPI (does not unpublish, but hides from
   resolvers).
2. Bump to the next patch version, fix, and re-tag.

GitHub Releases can be deleted freely; the underlying tag remains and can
be force-moved if absolutely necessary, but prefer a new tag.

## Manual fallback

If the workflow is broken and a release is urgent, the Python package can
be uploaded by hand from a workstation with a project-scoped PyPI token:

```bash
cd python && rm -rf dist build obkit.egg-info && uv build
uvx twine upload python/dist/*
```

This is the higher-attack-surface path (long-lived token in `~/.pypirc`)
and should only be used when CI is unavailable.
