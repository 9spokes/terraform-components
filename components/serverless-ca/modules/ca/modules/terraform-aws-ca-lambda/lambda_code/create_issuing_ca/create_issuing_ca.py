import base64
import json
import os
from utils.certs.kms import kms_get_kms_key_id, kms_describe_key
from utils.certs.crypto import (
    crypto_kms_ca_cert_signing_request,
    crypto_cert_info,
    crypto_create_ca_bundle,
)
from utils.certs.ca import ca_kms_sign_ca_certificate_request, ca_name, ca_bundle_name
from utils.certs.db import db_ca_cert_issued, db_list_certificates
from utils.certs.s3 import s3_download, s3_upload
from cryptography.x509 import load_pem_x509_certificate, load_pem_x509_csr

lifetime = 3650


def ensure_publication(
    external_s3_bucket_name,
    internal_s3_bucket_name,
    key,
    content,
    content_type,
):
    """Publish persisted CA material if S3 does not already contain it."""
    published_object = s3_download(
        external_s3_bucket_name,
        internal_s3_bucket_name,
        key,
        internal=False,
    )

    if published_object is None:
        s3_upload(
            external_s3_bucket_name,
            internal_s3_bucket_name,
            content,
            key,
            content_type=content_type,
        )
        return

    if published_object["Body"].read() != content:
        raise RuntimeError(f"Published CA artifact {key} does not match the certificate state in DynamoDB")


def ensure_issuing_ca_published(
    external_s3_bucket_name,
    internal_s3_bucket_name,
    project,
    env_name,
    ca_slug,
    root_ca_cert_pem,
    issuing_ca_cert_pem,
):
    """Reconcile the issuing certificate and bundle from persisted certificates."""
    ensure_publication(
        external_s3_bucket_name,
        internal_s3_bucket_name,
        f"{ca_slug}.crt",
        issuing_ca_cert_pem,
        "application/x-x509-ca-cert",
    )
    ensure_publication(
        external_s3_bucket_name,
        internal_s3_bucket_name,
        f"{ca_bundle_name(project, env_name)}.pem",
        crypto_create_ca_bundle([root_ca_cert_pem, issuing_ca_cert_pem]),
        "application/x-pem-file",
    )


def lambda_handler(event, context):  # pylint:disable=unused-argument,too-many-locals
    project = os.environ["PROJECT"]
    env_name = os.environ["ENVIRONMENT_NAME"]
    external_s3_bucket_name = os.environ["EXTERNAL_S3_BUCKET"]
    internal_s3_bucket_name = os.environ["INTERNAL_S3_BUCKET"]
    domain = os.environ.get("DOMAIN")

    public_crl = os.environ.get("PUBLIC_CRL")
    enable_public_crl = False
    if public_crl == "enabled":
        enable_public_crl = True

    issuing_ca_info = json.loads(os.environ["ISSUING_CA_INFO"])

    root_ca_name = ca_name(project, env_name, "root")
    ca_slug = ca_name(project, env_name, "issuing")

    # check Root CA exists
    root_ca_certificates = db_list_certificates(project, env_name, root_ca_name, consistent_read=True)
    if not root_ca_certificates:
        print(f"CA {root_ca_name} not found")

        return
    if len(root_ca_certificates) > 1:
        raise RuntimeError(f"Expected one root certificate for {root_ca_name}, found {len(root_ca_certificates)}")

    try:
        root_ca_cert_pem = base64.b64decode(root_ca_certificates[0]["Certificate"]["B"], validate=True)
        root_ca_cert = load_pem_x509_certificate(root_ca_cert_pem)
    except (KeyError, TypeError, ValueError) as error:
        raise RuntimeError(f"Persisted root certificate for {root_ca_name} is invalid") from error

    # A retry after DynamoDB persisted the issuing certificate but S3
    # publication failed must repair both artifacts without signing again.
    existing_certificates = db_list_certificates(project, env_name, ca_slug, consistent_read=True)
    if len(existing_certificates) > 1:
        raise RuntimeError(f"Expected one issuing certificate for {ca_slug}, found {len(existing_certificates)}")

    if existing_certificates:
        try:
            issuing_ca_cert_pem = base64.b64decode(
                existing_certificates[0]["Certificate"]["B"],
                validate=True,
            )
            load_pem_x509_certificate(issuing_ca_cert_pem)
        except (KeyError, TypeError, ValueError) as error:
            raise RuntimeError(f"Persisted issuing certificate for {ca_slug} is invalid") from error

        ensure_issuing_ca_published(
            external_s3_bucket_name,
            internal_s3_bucket_name,
            project,
            env_name,
            ca_slug,
            root_ca_cert_pem,
            issuing_ca_cert_pem,
        )
        print(f"CA {ca_slug} already exists and its published artifacts are verified")

        return

    # get issuing CA key details from KMS
    kms_key_id = kms_get_kms_key_id(ca_slug)
    cipher = kms_describe_key(kms_key_id)["KeySpec"]

    print(f"using {cipher} key pair in KMS for {ca_slug}")

    # get root CA key details from KMS
    root_ca_kms_key_id = kms_get_kms_key_id(root_ca_name)

    # create certificate signing request
    csr = load_pem_x509_csr(
        crypto_kms_ca_cert_signing_request(ca_slug, kms_key_id, kms_describe_key(kms_key_id)["SigningAlgorithms"][0])
    )

    # sign certificate
    pem_certificate = ca_kms_sign_ca_certificate_request(
        project,
        env_name,
        domain,
        csr,
        root_ca_cert,
        root_ca_kms_key_id,
        enable_public_crl,
        issuing_ca_info,
        kms_describe_key(root_ca_kms_key_id)["SigningAlgorithms"][0],
    )
    base64_certificate = base64.b64encode(pem_certificate)

    # get details to upload to DynamoDB
    cert = load_pem_x509_certificate(pem_certificate)
    info = crypto_cert_info(cert, ca_slug)

    # create entry in DynamoDB
    db_ca_cert_issued(project, env_name, info, base64_certificate)

    # publish certificate and CA bundle to S3
    ensure_issuing_ca_published(
        external_s3_bucket_name,
        internal_s3_bucket_name,
        project,
        env_name,
        ca_slug,
        root_ca_cert_pem,
        pem_certificate,
    )

    return
