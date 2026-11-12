# NCCS Release Note: <product and what changed>

Copy this file to `governance/release-notes/<short-name>.md` and fill in every field. Write "not recorded" where a fact has no record. Do not guess.

**Status:** <DRAFT or FINAL>. Published <YYYY-MM-DD> (version <version label>).
**Products:** <each data set that changed, with its S3 path>.
**Released by:** <the person who ran the build and the upload>, based on <code version from the build record file `_manifest.json`, or the commit hash>.
**Pipeline author:** <the person or project that wrote the code that built the files>.
**Other credit:** <anyone who found the defect, supplied the data, or checked the release. Write "none" if there is none>.

**What changes:** <which columns or files change, and how many rows>.

**What does not change:** <columns, rows and files a user can keep relying on>.

**For users:** <what a user must do: download again, filter differently, or nothing>.

**Verification:** <the checks that were run and where their results are kept>.

**Details:** <pull requests, decision records (ADR numbers), backlog items>.

## Changelog entry format

The website changelog (`nccs/changelog.md`) carries one entry per release note. Each entry has these lines, in this order:

```
## <YYYY-MM-DD>: <title>

**Data sets:** <products>

**What changed:** <one paragraph>

**What to do:** <one paragraph>

**Version:** <version label and code version>

**Attribution:** Released by: <name>. Pipeline author: <name>. Other credit: <as in the release note>.

**Source:** release note <link to the file in nccs-contracts>.
```
