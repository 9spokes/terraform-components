import base64
import json
import os
from utils.certs.kms import kms_get_kms_key_id, kms_get_public_key, kms_describe_key
from utils.certs.crypto import crypto_cert_info
from utils.certs.ca import ca_name, ca_create_kms_root_ca
from utils.certs.db import db_ca_cert_issued, db_list_certificates
from utils.certs.s3 import s3_download, s3_upload
from cryptography.x509 import load_pem_x509_certificate
from cryptography.hazmat.primitives.serialization import load_der_public_key

lifetime = 7300


def ensure_root_certificate_published(
    external_s3_bucket_name,
    internal_s3_bucket_name,
    ca_slug,
    pem_certificate,
):
    """Publish a persisted root certificate if S3 does not already contain it."""
    key = f"{ca_slug}.crt"
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
            pem_certificate,
            key,
            content_type="application/x-x509-ca-cert",
        )
        return

    published_certificate = published_object["Body"].read()
    if published_certificate != pem_certificate:
        raise RuntimeError(
            f"Published root certificate {key} does not match the certificate persisted in DynamoDB"
        )


def lambda_handler(event, context):  # pylint:disable=unused-argument
    project = os.environ["PROJECT"]
    env_name = os.environ["ENVIRONMENT_NAME"]
    external_s3_bucket_name = os.environ["EXTERNAL_S3_BUCKET"]
    internal_s3_bucket_name = os.environ["INTERNAL_S3_BUCKET"]
    root_ca_info = json.loads(os.environ["ROOT_CA_INFO"])

    ca_slug = ca_name(project, env_name, "root")

    # A retry after DynamoDB persisted the certificate but S3 publication failed
    # must repair the publication without generating a second root certificate.
    existing_certificates = db_list_certificates(project, env_name, ca_slug, consistent_read=True)
    if len(existing_certificates) > 1:
        raise RuntimeError(f"Expected one root certificate for {ca_slug}, found {len(existing_certificates)}")

    if existing_certificates:
        try:
            pem_certificate = base64.b64decode(
                existing_certificates[0]["Certificate"]["B"],
                validate=True,
            )
            load_pem_x509_certificate(pem_certificate)
        except (KeyError, TypeError, ValueError) as error:
            raise RuntimeError(f"Persisted root certificate for {ca_slug} is invalid") from error

        ensure_root_certificate_published(
            external_s3_bucket_name,
            internal_s3_bucket_name,
            ca_slug,
            pem_certificate,
        )
        print(f"CA {ca_slug} already exists and its published certificate is verified")

        return

    # get key details from KMS
    kms_key_id = kms_get_kms_key_id(ca_slug)
    cipher = kms_describe_key(kms_key_id)["KeySpec"]
    public_key = load_der_public_key(kms_get_public_key(kms_key_id))

    print(f"using {cipher} key pair in KMS for {ca_slug}")

    pem_certificate = ca_create_kms_root_ca(
        public_key, kms_key_id, root_ca_info, kms_describe_key(kms_key_id)["SigningAlgorithms"][0]
    )
    base64_certificate = base64.b64encode(pem_certificate)

    # get details to upload to DynamoDB
    cert = load_pem_x509_certificate(pem_certificate)
    info = crypto_cert_info(cert, ca_slug)

    # create entry in DynamoDB
    db_ca_cert_issued(project, env_name, info, base64_certificate)

    # publish the root certificate to S3
    ensure_root_certificate_published(
        external_s3_bucket_name,
        internal_s3_bucket_name,
        ca_slug,
        pem_certificate,
    )

    return
