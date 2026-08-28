from datetime import datetime, timedelta, timezone
from unittest.mock import patch

import pytest
from cryptography import x509
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.x509.oid import NameOID

from utils.certs.ca import (
    ca_build_cert,
    ca_kms_sign_ca_certificate_request,
    certificate_not_valid_after_utc,
)


def _certificate(common_name, key, expires_at):
    subject = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, common_name)])
    return (
        x509.CertificateBuilder()
        .subject_name(subject)
        .issuer_name(subject)
        .public_key(key.public_key())
        .serial_number(x509.random_serial_number())
        .not_valid_before(datetime.now(timezone.utc) - timedelta(days=1))
        .not_valid_after(expires_at)
        .sign(key, hashes.SHA256())
    )


def _csr(common_name, key):
    return (
        x509.CertificateSigningRequestBuilder()
        .subject_name(x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, common_name)]))
        .sign(key, hashes.SHA256())
    )


def test_leaf_not_after_is_capped_at_issuing_ca_expiry():
    issuing_key = ec.generate_private_key(ec.SECP256R1())
    issuing_expiry = datetime.now(timezone.utc) + timedelta(days=2)
    issuing_certificate = _certificate("Issuing CA", issuing_key, issuing_expiry)
    leaf_key = ec.generate_private_key(ec.SECP256R1())

    builder = ca_build_cert(
        _csr("leaf.example.com", leaf_key),
        issuing_certificate,
        lifetime=365,
        delta=timedelta(minutes=5),
        cert_request_info={"Purposes": ["server_auth"], "Extensions": []},
    )
    leaf_certificate = builder.sign(issuing_key, hashes.SHA256())

    assert leaf_certificate.not_valid_after_utc == issuing_certificate.not_valid_after_utc


def test_issuing_ca_not_after_is_capped_at_root_ca_expiry():
    root_key = ec.generate_private_key(ec.SECP384R1())
    root_expiry = datetime.now(timezone.utc) + timedelta(days=2)
    root_certificate = _certificate("Root CA", root_key, root_expiry)
    issuing_key = ec.generate_private_key(ec.SECP256R1())

    with (
        patch("utils.certs.ca.crypto_select_class", return_value=lambda *_: root_key),
        patch("utils.certs.ca.crypto_hash_class", return_value=hashes.SHA256()),
    ):
        certificate_pem = ca_kms_sign_ca_certificate_request(
            "example",
            "test",
            "ca.example.com",
            _csr("Issuing CA", issuing_key),
            root_certificate,
            "root-key",
            False,
            {"commonName": "Issuing CA", "lifetime": 3650},
        )

    issuing_certificate = x509.load_pem_x509_certificate(certificate_pem)
    assert issuing_certificate.not_valid_after_utc == root_certificate.not_valid_after_utc


def test_expired_issuer_is_rejected():
    issuing_key = ec.generate_private_key(ec.SECP256R1())
    issuing_certificate = _certificate(
        "Expired Issuing CA",
        issuing_key,
        datetime.now(timezone.utc) - timedelta(seconds=1),
    )
    leaf_key = ec.generate_private_key(ec.SECP256R1())

    with pytest.raises(ValueError, match="Issuer certificate has expired"):
        ca_build_cert(
            _csr("leaf.example.com", leaf_key),
            issuing_certificate,
            lifetime=1,
            delta=timedelta(minutes=5),
            cert_request_info={"Purposes": ["server_auth"], "Extensions": []},
        )


def test_short_requested_lifetime_remains_shorter_than_issuer():
    issuing_key = ec.generate_private_key(ec.SECP256R1())
    issuing_certificate = _certificate(
        "Issuing CA",
        issuing_key,
        datetime.now(timezone.utc) + timedelta(days=30),
    )
    leaf_key = ec.generate_private_key(ec.SECP256R1())

    leaf_certificate = ca_build_cert(
        _csr("leaf.example.com", leaf_key),
        issuing_certificate,
        lifetime=1,
        delta=timedelta(minutes=5),
        cert_request_info={"Purposes": ["server_auth"], "Extensions": []},
    ).sign(issuing_key, hashes.SHA256())

    assert leaf_certificate.not_valid_after_utc < issuing_certificate.not_valid_after_utc


def test_legacy_naive_issuer_expiry_is_normalized_to_utc():
    expires_at = datetime(2030, 1, 1, 12, 0, 0)
    legacy_certificate = type("LegacyCertificate", (), {"not_valid_after": expires_at})()

    assert certificate_not_valid_after_utc(legacy_certificate) == expires_at.replace(tzinfo=timezone.utc)


def test_modern_issuer_expiry_does_not_access_deprecated_property():
    expires_at = datetime(2030, 1, 1, 12, 0, 0, tzinfo=timezone.utc)

    class ModernCertificate:
        not_valid_after_utc = expires_at

        @property
        def not_valid_after(self):
            raise AssertionError("deprecated property accessed")

    assert certificate_not_valid_after_utc(ModernCertificate()) == expires_at
