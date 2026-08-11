# Serverless CA component

Self-contained Cloud Posse component for a KMS-backed, two-tier private certificate authority. It is a production-hardened adaptation of Serverless CA v3.5.0; see [UPSTREAM.md](UPSTREAM.md) for attribution and the complete deviation ledger.

The component is Class 3: its inputs, packaging, and AWS resource model are reusable without 9Spokes-specific source changes. No current Cloud Posse component or module provides the same Serverless CA implementation, so the reviewed source is packaged with its wrapper under one tag.

## Security and operations model

- Terraform never builds Lambda code. Supply all seven functions as immutable, versioned S3 objects.
- `sha256` values use the base64-encoded SHA-256 representation expected by `aws_lambda_function.source_code_hash`.
- The first component API is private-only. Public CRL/CloudFront and embedded Slack or SNS consumers remain internal upstream capabilities and are not exposed.
- Direct issuance, database reads, and publication-bucket reads have independent principal lists.
- Terraform seeds the three GitOps manifests once and ignores later content changes.
- CA creation is not CA initialization. Invoke and verify initialization through an explicit operator procedure after deployment.

## Deployment order

1. Create the regional, versioned artifact bucket and the narrowly scoped publisher role in the chosen CA account.
2. Promote packages from a protected GitHub release into the approved bucket prefix and record each S3 version ID.
3. Configure and deploy this component with those immutable artifact coordinates.
4. Run explicit operator initialization, then verify the root/issuing certificates, CA bundle, and both CRLs before adding consumers.

Do not combine these stages or initialize the CA from Terraform.
