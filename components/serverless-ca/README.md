# Serverless CA component

Self-contained Cloud Posse component for a KMS-backed, two-tier private certificate authority. It is a production-hardened adaptation of Serverless CA v3.5.0; see [UPSTREAM.md](UPSTREAM.md) for attribution and the complete deviation ledger.

The component is Class 3: its inputs, packaging, and AWS resource model are reusable without 9Spokes-specific source changes. No current Cloud Posse component or module provides the same Serverless CA implementation, so the reviewed source is packaged with its wrapper under one tag.

## Security and operations model

- Terraform never builds Lambda code. Supply all seven functions as immutable, versioned S3 objects.
- Choose `lambda_architecture = "x86_64"` (the compatibility default) or `"arm64"`. Every artifact records its architecture and must match the selected runtime.
- Release assets are named `<function>-x86_64.zip` and `<function>-arm64.zip`; promote only the seven files matching the selected runtime.
- `sha256` values are base64-encoded SHA-256 digests. Terraform uses them as deterministic update triggers and verifies the service-reported Lambda `code_sha256` after deployment.
- The first component API is private-only. Public CRL/CloudFront and embedded Slack or SNS consumers remain internal upstream capabilities and are not exposed.
- Direct issuance, database reads, and publication-bucket reads have independent principal lists.
- Terraform seeds the three GitOps manifests once and ignores later content changes.
- CA creation is not CA initialization. The Scheduler is disabled on the first apply; an operator must invoke and verify initialization explicitly.

## Deployment order

1. Create the regional, versioned artifact bucket and the narrowly scoped publisher role in the chosen CA account.
2. Promote the seven architecture-qualified packages for the selected runtime from a protected GitHub release into the approved bucket prefix and record each S3 version ID.
3. Configure and deploy this component with those immutable artifact coordinates.
4. Keep `scheduler_enabled = false` on the first apply. An operator invokes exactly one deployed Step Functions state machine execution (for example with `modules/ca/scripts/start_ca_step_function.py`) to initialize the CA. Concurrent initialization executions are unsupported because CA creation does not use a distributed lock.
5. Verify the root certificate, issuing certificate, CA bundle, root CRL, and issuing CRL at the `certificate_locations` output before adding consumers.
6. Set `scheduler_enabled = true` and apply again only after those checks succeed.

Do not combine these stages or initialize the CA from Terraform.
