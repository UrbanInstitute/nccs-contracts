# How to record a data release on GitHub

Create one dated GitHub release for each data release, in the repository whose code built the files. The release ties a public date and a named person to an exact version of the code. Start with the next data release. Do not create tags for past releases.

## Before you start

- The files are on S3 and their build record file (`_manifest.json`) is beside them.
- The release note is merged in `nccs-contracts/governance/release-notes/`. Use `_TEMPLATE.md` in that folder. It has the "Released by" and "Pipeline author" fields.

## Steps

1. Read the code version from the build record file. Example:

   ```
   aws s3 cp s3://nccsdata/unified/bmf/_manifest.json - --profile thiya | grep git_sha
   ```

   Expected result: one short commit hash, for example `1b1f8a9`.

2. Choose the tag name: `data-<product>-<YYYY-MM-DD>`, using the date the files were published. Example: `data-unified-bmf-2026-12-15`.

3. In the repository that built the files, create the release at that commit:

   ```
   gh release create data-unified-bmf-2026-12-15 \
     --target <commit hash from step 1> \
     --title "Unified BMF, published 2026-12-15" \
     --notes-file release-body.md
   ```

   Expected result: `gh` prints the address of the new release.

4. Write `release-body.md` with these lines before running step 3:

   - Released by: the person who ran the build and the upload.
   - Pipeline author: the person or project that wrote the code.
   - Other credit: as in the release note.
   - S3 path and version label.
   - Link to the release note in `nccs-contracts`.

5. Add the release address to the "Details" line of the release note and to the changelog entry on the website.

## What a release does and does not do

- It records who released the data, on what date, from which code. GitHub keeps the name of the account that created the release.
- If the repository is linked to Zenodo (`nccs-data-bmf` and `nccs-data-core` carry a `.zenodo.json` file for this), each release also receives a DOI.
- It does not publish or change any file on S3.
- It does not replace the release note. The release note stays the one place where the change is described.

## Releases produced by another project

For e-file releases produced by the Nonprofit Open Data Collective, do not create a release in an NCCS repository. Record the producer as "Released by" and "Pipeline author" in the release note, and name the NCCS person who documented and checked the release under "Other credit".
