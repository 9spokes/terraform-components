# Workflow architecture decisions

## 2026-08-28 — Promote only verified Serverless CA releases through a protected environment

Status: accepted

The tag-triggered `package` job builds, attests, and publishes the Serverless CA
release. `promote-serverless-ca-artifacts` is deliberately a separate job, gated
by the `serverless-ca-artifact-promotion` environment. It downloads only the
published release matching `github.ref_name`, rejects non-stable SemVer tags,
drafts, prereleases, missing assets, and unexpected assets, then verifies GitHub
attestations and `SHA256SUMS` before it acquires AWS credentials.

The workflow writes immutable objects beneath
`serverless-ca/releases/<tag>/` with conditional `PutObject` and SSE-S3. It
writes the 18 checksummed release assets first and records each successful
`PutObject` response in a deterministic `promotion-manifest.json`. Each entry
maps the release filename and checksum to the exact S3 key, returned S3 version
ID, content length, tag, source commit, repository, and workflow run. The
manifest is generated only after the release attestations and checksums have
been verified and after every asset upload has returned the version ID that the
manifest records. It is promotion metadata, not a GitHub Release asset, so it
is not part of the release allowlist or attestation loop.

The manifest proves that this workflow received successful, versioned
`PutObject` responses for the listed verified release inputs. It is not an
independent S3 read-back, retention audit, or proof that a promotion completed.
The workflow therefore uploads `SHA256SUMS` only after the manifest, and its
presence remains the completion marker. The role does not need S3 read, list,
delete, tagging, ACL, retention, legal-hold, or governance-bypass permissions.

The promotion is not atomically retryable after any partial immutable upload:
the role deliberately cannot inspect or remove partial objects and conditional
rewrites fail. Operators must diagnose the failure and publish a new SemVer
release; they must not repurpose the failed tag.

This workflow depends on platform PR #3675 being merged, applied, and its three
environment variables (`AWS_REGION`, `AWS_ROLE_ARN`, and `ARTIFACT_BUCKET`)
verified live before this change is merged. Release publication and protected AWS
promotion remain separate authorization gates even though a tag triggers both.
