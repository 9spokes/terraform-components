import base64
from unittest.mock import patch

import pytest

from lambda_code.create_root_ca.create_root_ca import lambda_handler
from utils.certs.db import db_list_certificates


@pytest.fixture(autouse=True)
def root_ca_environment(monkeypatch):
    monkeypatch.setenv("PROJECT", "example")
    monkeypatch.setenv("ENVIRONMENT_NAME", "test")
    monkeypatch.setenv("EXTERNAL_S3_BUCKET", "external-certificates")
    monkeypatch.setenv("INTERNAL_S3_BUCKET", "internal-state")
    monkeypatch.setenv("ROOT_CA_INFO", "{}")


def test_retry_repairs_publication_after_dynamodb_write_succeeds():
    pem_certificate = b"-----BEGIN CERTIFICATE-----\ntest\n-----END CERTIFICATE-----\n"
    persisted_certificate = {"Certificate": {"B": base64.b64encode(pem_certificate)}}

    with (
        patch(
            "lambda_code.create_root_ca.create_root_ca.db_list_certificates",
            side_effect=[[], [persisted_certificate]],
        ) as list_certificates,
        patch("lambda_code.create_root_ca.create_root_ca.kms_get_kms_key_id", return_value="root-key") as get_key,
        patch(
            "lambda_code.create_root_ca.create_root_ca.kms_describe_key",
            return_value={"KeySpec": "ECC_NIST_P384", "SigningAlgorithms": ["ECDSA_SHA_384"]},
        ),
        patch("lambda_code.create_root_ca.create_root_ca.kms_get_public_key", return_value=b"public-key"),
        patch("lambda_code.create_root_ca.create_root_ca.load_der_public_key"),
        patch(
            "lambda_code.create_root_ca.create_root_ca.ca_create_kms_root_ca",
            return_value=pem_certificate,
        ) as create_certificate,
        patch("lambda_code.create_root_ca.create_root_ca.load_pem_x509_certificate"),
        patch("lambda_code.create_root_ca.create_root_ca.crypto_cert_info", return_value={}) as cert_info,
        patch("lambda_code.create_root_ca.create_root_ca.db_ca_cert_issued") as persist_certificate,
        patch("lambda_code.create_root_ca.create_root_ca.s3_download", return_value=None),
        patch(
            "lambda_code.create_root_ca.create_root_ca.s3_upload",
            side_effect=[RuntimeError("simulated S3 failure"), None],
        ) as upload_certificate,
    ):
        with pytest.raises(RuntimeError, match="simulated S3 failure"):
            lambda_handler({}, None)

        lambda_handler({}, None)

    assert list_certificates.call_count == 2
    assert all(call.kwargs == {"consistent_read": True} for call in list_certificates.call_args_list)
    get_key.assert_called_once()
    create_certificate.assert_called_once()
    cert_info.assert_called_once()
    persist_certificate.assert_called_once()
    assert upload_certificate.call_count == 2
    assert upload_certificate.call_args_list[1].args == (
        "external-certificates",
        "internal-state",
        pem_certificate,
        "example-root-ca-test.crt",
    )
    assert upload_certificate.call_args_list[1].kwargs == {
        "content_type": "application/x-x509-ca-cert"
    }


def test_retry_rejects_conflicting_published_root_certificate():
    persisted = base64.b64encode(b"persisted-certificate")
    published_object = {"Body": type("Body", (), {"read": lambda self: b"different-certificate"})()}

    with (
        patch(
            "lambda_code.create_root_ca.create_root_ca.db_list_certificates",
            return_value=[{"Certificate": {"B": persisted}}],
        ),
        patch("lambda_code.create_root_ca.create_root_ca.load_pem_x509_certificate"),
        patch("lambda_code.create_root_ca.create_root_ca.s3_download", return_value=published_object),
        patch("lambda_code.create_root_ca.create_root_ca.s3_upload") as upload_certificate,
    ):
        with pytest.raises(RuntimeError, match="does not match the certificate persisted in DynamoDB"):
            lambda_handler({}, None)

    upload_certificate.assert_not_called()


@patch("utils.certs.db.boto3")
def test_root_lookup_requests_strongly_consistent_dynamodb_read(mock_boto3):
    client = mock_boto3.client.return_value
    client.query.return_value = {"Items": []}

    assert db_list_certificates("example", "test", "example-root-ca-test", consistent_read=True) == []
    assert client.query.call_args.kwargs["ConsistentRead"] is True


def test_multiple_persisted_root_certificates_fail_closed():
    with (
        patch(
            "lambda_code.create_root_ca.create_root_ca.db_list_certificates",
            return_value=[{"Certificate": {"B": b"first"}}, {"Certificate": {"B": b"second"}}],
        ),
        patch("lambda_code.create_root_ca.create_root_ca.kms_get_kms_key_id") as get_key,
    ):
        with pytest.raises(RuntimeError, match="Expected one root certificate.*found 2"):
            lambda_handler({}, None)

    get_key.assert_not_called()


def test_invalid_persisted_root_certificate_fails_closed():
    with (
        patch(
            "lambda_code.create_root_ca.create_root_ca.db_list_certificates",
            return_value=[{"Certificate": {"B": b"not-base64"}}],
        ),
        patch("lambda_code.create_root_ca.create_root_ca.kms_get_kms_key_id") as get_key,
    ):
        with pytest.raises(RuntimeError, match="Persisted root certificate.*is invalid"):
            lambda_handler({}, None)

    get_key.assert_not_called()
