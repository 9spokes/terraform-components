# Upstream source and deviation ledger

This component contains an adapted, attributed snapshot of
[`serverless-ca/terraform-aws-ca`](https://github.com/serverless-ca/terraform-aws-ca).

- Upstream version: `v3.5.0`
- Upstream commit: `ec435e7ef6296365988dd7ac27aab82c531fb5ca`
- Snapshot date: 2026-08-11
- Upstream copyright: Copyright 2024 Q-Solution Limited
- License: Apache License 2.0, preserved at `modules/ca/LICENSE.md`

## Included paths

- Root Terraform runtime: `*.tf`, `python-version`, and upstream README
- Terraform submodules under `modules/**`
- Lambda handlers, shared utilities, and upstream Lambda unit tests
- Operational Python utilities and integration-test source under `scripts/**`, `utils/**`, and `tests/**`
- Runtime and development dependency specifications

The upstream documentation website, images, examples, repository automation, and maintainer files are intentionally excluded. They are not required to build, test, package, or operate the reviewed component.

## 9Spokes deviations

1. Removed Terraform `null_resource`, `local-exec`, virtualenv creation, local ZIP generation, and apply-time dependency installation.
2. Require immutable S3 inputs for all seven Lambda packages: bucket, key, object version ID, and base64-encoded SHA-256 digest.
3. Fix the Lambda runtime to Python 3.14, explicitly support x86_64 and arm64, and require every immutable artifact to declare the selected architecture. Upstream implicitly used x86_64 through its ManyLinux packaging default and Lambda's default architecture.
4. Split the original combined principal list into direct TLS invocation, DynamoDB reader, and external publication-bucket reader principals.
5. Default S3 to non-destructive deletion, enabled versioning, full public-access blocking, and encryption for both internal and external buckets.
6. Default DynamoDB deletion protection to enabled, KMS deletion windows to 30 days, and Lambda/Step Functions log retention to 365 days.
7. Propagate tags to every taggable resource touched by the adapted implementation.
8. Seed `tls.json`, `revoked.json`, and `revoked-root-ca.json` with empty arrays and ignore later content changes, handing ongoing content ownership to a separate operations workflow.
9. Remove local CSR-file upload from Terraform; scheduled GitOps processing reads the operational manifests from S3.
10. Expand operational outputs for Lambda functions, Step Functions, Scheduler, DynamoDB, KMS, S3, the optional reader role, SNS, certificates, CA bundle, and CRLs. No private key material is output.
11. Add an auditable deployment contract used by mocked OpenTofu tests to prove artifact mapping, principal separation, and hardening defaults.
12. Replace deprecated AWS region data-source attributes with the AWS provider 6 form.
13. Add fully hash-locked Python dependency files, deterministic Lambda/component packaging in a digest-pinned official Lambda image, Lambda-runtime smoke imports, dependency audit, and static security checks.
14. Add a curated Cloud Posse wrapper with `null-label` context, a bare regional AWS provider, private-only publication, and no embedded notification consumers.
15. Replace runtime `assert` checks on SNS responses with explicit exceptions so optimized Python execution cannot skip failure handling.
16. Scope Step Functions and Scheduler permissions to the exact CA functions/state machine and remove unused S3 object deletion from Lambda roles.
17. Constrain the adapted module itself to OpenTofu 1.12.4 and AWS provider 6.x, tag optional ACM/CloudFront resources, and require HTTPS for the retained public-CRL path.
18. Point Step Functions, SNS, outputs, and direct invoke permissions at a `live` alias backed by a published immutable Lambda version instead of mutable `$LATEST`.
19. Create the Scheduler in `DISABLED` state by default. Operators explicitly initialize and verify the CA before setting `scheduler_enabled = true` in a later apply.
20. Reject parsed CSRs with an invalid signature before duplicate-key registration or signing, while preserving the upstream request subject and SAN override contract.
21. Preserve the selected ECDSA signing hash in generated CSRs and KMS signing calls without mutating cryptography caller objects.
22. Verify the service-reported digest of every deployed Lambda package against the declared artifact SHA-256 digest.
23. Grant the Step Functions role scoped access to describe Distributed Map child executions while retaining state-machine-scoped start permission.
24. Make root and issuing CA initialization repair missing publication artifacts from existing DynamoDB certificates without regenerating either CA, and reject conflicting published material.
25. Constrain issuing CA and leaf certificate validity to the expiry of their respective issuer certificates.
26. Harden operational S3 discovery for missing buckets and empty object listings.
27. Encode root and issuing CA distinguished names in `C, ST, L, O, OU, CN, emailAddress` order and reuse the exact
    CA name construction for CRL issuers, without changing the upstream leaf-subject ordering contract.
28. Pass the Terraform-created DynamoDB table name to every CA function as `DYNAMODB_TABLE_NAME` and read it
    before the upstream name derivation. Python `str.title()` and HCL `title()` disagree for digit-leading
    projects (`9Spokes` versus `9spokes`), so the derived name pointed at a table that never existed.

When updating the snapshot, review upstream changes path-by-path and update this ledger. Do not overwrite the adapted files with an unreviewed bulk copy.
