import base64
import io
from unittest.mock import MagicMock, patch

import pytest

from lambda_code.create_issuing_ca.create_issuing_ca import lambda_handler


@pytest.fixture(autouse=True)
def issuing_ca_environment(monkeypatch):
    monkeypatch.setenv("PROJECT", "example")
    monkeypatch.setenv("ENVIRONMENT_NAME", "test")
    monkeypatch.setenv("EXTERNAL_S3_BUCKET", "external-certificates")
    monkeypatch.setenv("INTERNAL_S3_BUCKET", "internal-state")
    monkeypatch.setenv("ISSUING_CA_INFO", "{}")
    monkeypatch.setenv("PUBLIC_CRL", "disabled")


def test_retry_repairs_issuing_publication_after_dynamodb_write_succeeds():
    root_pem = b"root-certificate"
    issuing_pem = b"issuing-certificate"
    bundle_pem = "root-and-issuing-bundle"
    root_item = {"Certificate": {"B": base64.b64encode(root_pem)}}
    issuing_item = {"Certificate": {"B": base64.b64encode(issuing_pem)}}
    root_certificate = MagicMock()
    issuing_certificate = MagicMock()

    with (
        patch(
            "lambda_code.create_issuing_ca.create_issuing_ca.db_list_certificates",
            side_effect=[[root_item], [], [root_item], [issuing_item]],
        ) as list_certificates,
        patch(
            "lambda_code.create_issuing_ca.create_issuing_ca.load_pem_x509_certificate",
            side_effect=[root_certificate, issuing_certificate, root_certificate, issuing_certificate],
        ),
        patch("lambda_code.create_issuing_ca.create_issuing_ca.kms_get_kms_key_id", return_value="kms-key"),
        patch(
            "lambda_code.create_issuing_ca.create_issuing_ca.kms_describe_key",
            return_value={"KeySpec": "ECC_NIST_P256", "SigningAlgorithms": ["ECDSA_SHA_256"]},
        ),
        patch("lambda_code.create_issuing_ca.create_issuing_ca.crypto_kms_ca_cert_signing_request"),
        patch("lambda_code.create_issuing_ca.create_issuing_ca.load_pem_x509_csr"),
        patch(
            "lambda_code.create_issuing_ca.create_issuing_ca.ca_kms_sign_ca_certificate_request",
            return_value=issuing_pem,
        ) as sign_certificate,
        patch("lambda_code.create_issuing_ca.create_issuing_ca.crypto_cert_info", return_value={}),
        patch("lambda_code.create_issuing_ca.create_issuing_ca.db_ca_cert_issued") as persist_certificate,
        patch(
            "lambda_code.create_issuing_ca.create_issuing_ca.crypto_create_ca_bundle",
            return_value=bundle_pem,
        ),
        patch(
            "lambda_code.create_issuing_ca.create_issuing_ca.s3_download",
            side_effect=[None, None, None],
        ),
        patch(
            "lambda_code.create_issuing_ca.create_issuing_ca.s3_upload",
            side_effect=[RuntimeError("simulated S3 failure"), None, None],
        ) as upload_artifact,
    ):
        with pytest.raises(RuntimeError, match="simulated S3 failure"):
            lambda_handler({}, None)

        lambda_handler({}, None)

    assert list_certificates.call_count == 4
    assert all(call.kwargs == {"consistent_read": True} for call in list_certificates.call_args_list)
    sign_certificate.assert_called_once()
    persist_certificate.assert_called_once()
    assert upload_artifact.call_count == 3
    assert upload_artifact.call_args_list[1].args == (
        "external-certificates",
        "internal-state",
        issuing_pem,
        "example-issuing-ca-test.crt",
    )
    assert upload_artifact.call_args_list[1].kwargs == {
        "content_type": "application/x-x509-ca-cert"
    }
    assert upload_artifact.call_args_list[2].args == (
        "external-certificates",
        "internal-state",
        bundle_pem.encode("utf-8"),
        "example-ca-bundle-test.pem",
    )
    assert upload_artifact.call_args_list[2].kwargs == {"content_type": "application/x-pem-file"}


def test_retry_accepts_matching_existing_issuing_publication():
    root_pem = b"root-certificate"
    issuing_pem = b"issuing-certificate"
    bundle_pem = "root-and-issuing-bundle"
    root_item = {"Certificate": {"B": base64.b64encode(root_pem)}}
    issuing_item = {"Certificate": {"B": base64.b64encode(issuing_pem)}}

    with (
        patch(
            "lambda_code.create_issuing_ca.create_issuing_ca.db_list_certificates",
            side_effect=[[root_item], [issuing_item]],
        ),
        patch(
            "lambda_code.create_issuing_ca.create_issuing_ca.load_pem_x509_certificate",
            side_effect=[MagicMock(), MagicMock()],
        ),
        patch(
            "lambda_code.create_issuing_ca.create_issuing_ca.crypto_create_ca_bundle",
            return_value=bundle_pem,
        ),
        patch(
            "lambda_code.create_issuing_ca.create_issuing_ca.s3_download",
            side_effect=[
                {"Body": io.BytesIO(issuing_pem)},
                {"Body": io.BytesIO(bundle_pem.encode("utf-8"))},
            ],
        ),
        patch("lambda_code.create_issuing_ca.create_issuing_ca.s3_upload") as upload_artifact,
    ):
        lambda_handler({}, None)

    upload_artifact.assert_not_called()
