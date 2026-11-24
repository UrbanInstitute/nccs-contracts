# How to record a data release on GitHub

Create one dated GitHub release for each data release, in the repository whose code built the files. A GitHub release is a page that records a date, the account that created it, and one exact version of the code. Start with the next data release. Do not create releases for past data releases.

## What a release does and does not do

- It records who released the data, on what date, from which code. GitHub keeps the name of the account that created the release.
- It does not publish or change any file on S3.
- It does not replace the release note. The release note stays the one place that describes the change.
- If the repository is connected to Zenodo, each release also receives a DOI. Zenodo is a public research archive. A DOI is a permanent identifier that others can cite. `nccs-data-bmf` and `nccs-data-core` carry a `.zenodo.json` file for this.

## Before you start

Check both of these. If either is not true, stop and finish it first.

- The files are on S3, and their build record file (`_manifest.json`) is beside them.
- The release note is on the `main` branch in `nccs-contracts/governance/release-notes/`. To write one, copy `_TEMPLATE.md` in that folder. It has the "Released by" and "Pipeline author" fields.

## Steps

1. Read the code version from the build record file. Use your own AWS profile name. Example:

   ```
   aws s3 cp s3://nccsdata/unified/bmf/_manifest.json - --profile <your profile> | grep git_sha
   ```

   Expected result: one short commit hash, for example `1b1f8a9`. A commit hash is the identifier Git gives one version of the code.

2. Choose the tag name. A tag is a name that Git attaches to one version of the code. Use `data-<product>-<YYYY-MM-DD>`, with the date you published the files.

   Expected result: a name such as `data-unified-bmf-2026-12-15`.

3. Write a file named `release-body.md` with these lines:

   - Released by: the person who ran the build and the upload.
   - Pipeline author: the person or project that wrote the code.
   - Other credit: as in the release note.
   - S3 path and version label.
   - Link to the release note in `nccs-contracts`.

   Expected result: a file of five lines that matches the release note.

4. In the repository that built the files, create the release at the commit from step 1:

   ```
   gh release create data-unified-bmf-2026-12-15 \
     --target <commit hash from step 1> \
     --title "Unified BMF, published 2026-12-15" \
     --notes-file release-body.md
   ```

   Expected result: `gh` prints the address of the new release.

5. Add the release address to the "Details" line of the release note and to the changelog entry on the website.

   Expected result: the release note and the changelog entry both link to the release.

## If another project produced the release

If the Nonprofit Open Data Collective produced an e-file release, do not create a release in an NCCS repository. In the release note, record the Nonprofit Open Data Collective as "Released by" and "Pipeline author". Under "Other credit", name the NCCS person who documented and checked the release.
