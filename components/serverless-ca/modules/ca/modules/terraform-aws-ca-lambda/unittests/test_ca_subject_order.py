from datetime import timedelta
from unittest.mock import patch

import pytest
from cryptography import x509
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.x509.oid import NameOID

from utils.certs.ca import (
    ca_construct_subject_name,
    ca_create_root_ca,
    ca_kms_publish_crl,
    ca_kms_sign_ca_certificate_request,
)

ORGANIZATION = "9 SPOKES INTERNATIONAL LIMITED"
ROOT_COMMON_NAME = "9Spokes Internal Root CA G1"
ISSUING_COMMON_NAME = "9Spokes Internal Issuing CA G1"


def _ca_info(common_name, path_length_constraint):
    return {
        "country": "NZ",
        "organization": ORGANIZATION,
        "commonName": common_name,
        "pathLengthConstraint": path_length_constraint,
    }


def _expected_subject(common_name):
    return [
        (NameOID.COUNTRY_NAME, "NZ"),
        (NameOID.ORGANIZATION_NAME, ORGANIZATION),
        (NameOID.COMMON_NAME, common_name),
    ]


def _ordered_attributes(name):
    return [(attribute.oid, attribute.value) for attribute in name]


def _csr(common_name, key):
    return (
        x509.CertificateSigningRequestBuilder()
        .subject_name(x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, common_name)]))
        .sign(key, hashes.SHA256())
    )


@pytest.mark.parametrize(
    ("hierarchy", "common_name"),
    [
        ("root", ROOT_COMMON_NAME),
        ("issuing", ISSUING_COMMON_NAME),
    ],
)
def test_approved_ca_subject_has_exact_order_and_values(hierarchy, common_name):
    subject = ca_construct_subject_name(_ca_info(common_name, 0), hierarchy)

    assert _ordered_attributes(subject) == _expected_subject(common_name)

    omitted_oids = {
        NameOID.ORGANIZATIONAL_UNIT_NAME,
        NameOID.STATE_OR_PROVINCE_NAME,
        NameOID.LOCALITY_NAME,
        NameOID.EMAIL_ADDRESS,
    }
    assert all(not subject.get_attributes_for_oid(oid) for oid in omitted_oids)


def test_root_and_issuing_certificate_pem_preserves_approved_subject_order():
    root_key = ec.generate_private_key(ec.SECP384R1())
    root_pem = ca_create_root_ca(
        root_key.public_key(),
        root_key,
        _ca_info(ROOT_COMMON_NAME, 1),
        "ECDSA_SHA_384",
    )
    root_certificate = x509.load_pem_x509_certificate(root_pem)
    assert _ordered_attributes(root_certificate.subject) == _expected_subject(
        ROOT_COMMON_NAME
    )
    assert root_certificate.issuer == root_certificate.subject

    issuing_key = ec.generate_private_key(ec.SECP256R1())
    with (
        patch("utils.certs.ca.crypto_select_class", return_value=lambda *_: root_key),
        patch("utils.certs.ca.crypto_hash_class", return_value=hashes.SHA384()),
    ):
        issuing_pem = ca_kms_sign_ca_certificate_request(
            "9spokes",
            "internal-g1",
            "ca.example.com",
            _csr(ISSUING_COMMON_NAME, issuing_key),
            root_certificate,
            "root-key",
            False,
            _ca_info(ISSUING_COMMON_NAME, 0),
            "ECDSA_SHA_384",
        )

    issuing_certificate = x509.load_pem_x509_certificate(issuing_pem)
    assert _ordered_attributes(issuing_certificate.subject) == _expected_subject(
        ISSUING_COMMON_NAME
    )
    assert issuing_certificate.issuer == root_certificate.subject

    with (
        patch(
            "utils.certs.ca.crypto_select_class", return_value=lambda *_: issuing_key
        ),
        patch("utils.certs.ca.crypto_hash_class", return_value=hashes.SHA256()),
    ):
        issuing_crl = ca_kms_publish_crl(
            _ca_info(ISSUING_COMMON_NAME, 0),
            {"KmsKeyId": "issuing-key", "PublicKey": issuing_key.public_key()},
            timedelta(days=7, seconds=600),
            [],
            1,
            "ECDSA_SHA_256",
        )

    assert issuing_crl.issuer == issuing_certificate.subject
    assert _ordered_attributes(issuing_crl.issuer) == _expected_subject(
        ISSUING_COMMON_NAME
    )


def test_crl_issuer_uses_the_same_order_as_the_ca_certificate_subject():
    root_info = _ca_info(ROOT_COMMON_NAME, 1)
    root_key = ec.generate_private_key(ec.SECP384R1())
    root_certificate = x509.load_pem_x509_certificate(
        ca_create_root_ca(
            root_key.public_key(),
            root_key,
            root_info,
            "ECDSA_SHA_384",
        )
    )

    with (
        patch("utils.certs.ca.crypto_select_class", return_value=lambda *_: root_key),
        patch("utils.certs.ca.crypto_hash_class", return_value=hashes.SHA384()),
    ):
        crl = ca_kms_publish_crl(
            root_info,
            {"KmsKeyId": "root-key", "PublicKey": root_key.public_key()},
            timedelta(days=7, seconds=600),
            [],
            1,
            "ECDSA_SHA_384",
        )

    assert crl.issuer == root_certificate.subject
    assert _ordered_attributes(crl.issuer) == _expected_subject(ROOT_COMMON_NAME)
