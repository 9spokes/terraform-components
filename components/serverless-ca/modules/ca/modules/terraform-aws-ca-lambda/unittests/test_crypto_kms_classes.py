"""
Unit tests for crypto_kms_classes.py — regression tests for issue #606.

AWS KMS ``Sign`` rejects a RAW ``Message`` longer than 4096 bytes. The KMS-backed
key classes therefore hash the data locally and sign the fixed-size digest with
``MessageType="DIGEST"``. These tests assert that behaviour for both the RSA and
the Elliptic Curve key classes, across every ECDSA key size the module supports
(``ECC_NIST_P256``/``P384``/``P521``), including a payload larger than 4096 bytes.
"""

import hashlib
from unittest.mock import MagicMock, patch

import pytest
from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec, padding
from cryptography.hazmat.primitives.asymmetric.utils import Prehashed

from utils.certs.crypto import crypto_kms_ca_cert_signing_request
from utils.certs.crypto_kms_classes import AWSKMSEllipticCurvePrivateKey, AWSKMSRSAPrivateKey

# A payload comfortably larger than the 4096-byte KMS RAW limit (the regression case).
LARGE_PAYLOAD = b"a" * 5000

# hash_algorithm -> (KMS SigningAlgorithm, expected digest length in bytes, hash class)
ECDSA_VARIANTS = {
    "sha256": ("ECDSA_SHA_256", 32, hashes.SHA256),
    "sha384": ("ECDSA_SHA_384", 48, hashes.SHA384),
    "sha512": ("ECDSA_SHA_512", 64, hashes.SHA512),
}


@pytest.mark.parametrize("hash_algorithm,expected", list(ECDSA_VARIANTS.items()))
@patch("utils.certs.crypto_kms_classes.boto3")
def test_ec_sign_uses_digest_message_type(mock_boto3, hash_algorithm, expected):
    """EC sign hashes locally and signs the digest with MessageType=DIGEST for every curve."""
    signing_algorithm, digest_len, hash_class = expected

    mock_client = MagicMock()
    mock_client.sign.return_value = {"Signature": b"signature"}
    mock_boto3.client.return_value = mock_client

    private_key = AWSKMSEllipticCurvePrivateKey("test-key-id", hash_algorithm)

    # Use a real cryptography signature algorithm, as x509 signing does in production.
    signature = private_key.sign(LARGE_PAYLOAD, ec.ECDSA(hash_class()))

    assert signature == b"signature"
    mock_client.sign.assert_called_once()
    _, kwargs = mock_client.sign.call_args
    assert kwargs["MessageType"] == "DIGEST"
    assert kwargs["SigningAlgorithm"] == signing_algorithm
    assert kwargs["KeyId"] == "test-key-id"

    expected_digest = hashlib.new(hash_algorithm, LARGE_PAYLOAD).digest()
    assert kwargs["Message"] == expected_digest
    # The digest is fixed-size and well within the 4096-byte KMS limit.
    assert len(kwargs["Message"]) == digest_len
    assert len(kwargs["Message"]) <= 4096


@pytest.mark.parametrize("hash_algorithm,expected", list(ECDSA_VARIANTS.items()))
@patch("utils.certs.crypto_kms_classes.boto3")
def test_ec_sign_does_not_mutate_callers_hash_object(mock_boto3, hash_algorithm, expected):
    """The selected KMS hash controls signing without mutating cryptography's input object."""
    _, _, hash_class = expected
    mock_client = MagicMock()
    mock_client.sign.return_value = {"Signature": b"signature"}
    mock_boto3.client.return_value = mock_client

    signature_algorithm = ec.ECDSA(hash_class())
    AWSKMSEllipticCurvePrivateKey("test-key-id", hash_algorithm).sign(LARGE_PAYLOAD, signature_algorithm)

    assert signature_algorithm.algorithm.name == hash_algorithm


@patch("utils.certs.crypto_kms_classes.boto3")
def test_ec_sign_rejects_mismatched_hash_before_kms(mock_boto3):
    """ECDSA cannot produce a CSR with mismatched AlgorithmIdentifier and signature hashes."""
    private_key = AWSKMSEllipticCurvePrivateKey("test-key-id", "sha384")

    with pytest.raises(
        ValueError,
        match="Configured hash algorithm sha384 does not match supplied hash algorithm sha256",
    ):
        private_key.sign(LARGE_PAYLOAD, ec.ECDSA(hashes.SHA256()))

    mock_boto3.client.assert_not_called()


@pytest.mark.parametrize(
    "kms_signing_algorithm,key_factory,hash_class",
    [
        ("ECDSA_SHA_384", ec.SECP384R1, hashes.SHA384),
        ("ECDSA_SHA_512", ec.SECP521R1, hashes.SHA512),
    ],
)
@patch("utils.certs.crypto_kms_classes.boto3")
def test_generated_nondefault_ecdsa_csr_is_valid(mock_boto3, kms_signing_algorithm, key_factory, hash_class):
    """The CSR AlgorithmIdentifier, signature, and KMS request use the selected ECDSA hash."""
    backing_key = ec.generate_private_key(key_factory())
    mock_client = MagicMock()
    mock_client.get_public_key.return_value = {
        "PublicKey": backing_key.public_key().public_bytes(
            serialization.Encoding.DER,
            serialization.PublicFormat.SubjectPublicKeyInfo,
        )
    }

    def sign_with_backing_key(**kwargs):
        assert kwargs["SigningAlgorithm"] == kms_signing_algorithm
        return {
            "Signature": backing_key.sign(
                kwargs["Message"],
                ec.ECDSA(Prehashed(hash_class())),
            )
        }

    mock_client.sign.side_effect = sign_with_backing_key
    mock_boto3.client.return_value = mock_client

    csr = x509.load_pem_x509_csr(
        crypto_kms_ca_cert_signing_request("example-ca", "test-key-id", kms_signing_algorithm)
    )

    assert csr.is_signature_valid
    assert csr.signature_hash_algorithm.name == hash_class().name


@patch("utils.certs.crypto_kms_classes.boto3")
def test_rsa_sign_uses_digest_message_type(mock_boto3):
    """RSA sign hashes locally with sha256 and signs the digest with MessageType=DIGEST."""
    mock_client = MagicMock()
    mock_client.sign.return_value = {"Signature": b"signature"}
    mock_boto3.client.return_value = mock_client

    private_key = AWSKMSRSAPrivateKey("test-key-id")

    # Use real cryptography padding/hash objects, as x509 signing does in production.
    algorithm = hashes.SHA256()
    signature = private_key.sign(LARGE_PAYLOAD, padding.PKCS1v15(), algorithm)

    assert signature == b"signature"
    mock_client.sign.assert_called_once()
    _, kwargs = mock_client.sign.call_args
    assert kwargs["MessageType"] == "DIGEST"
    assert kwargs["SigningAlgorithm"] == "RSASSA_PKCS1_V1_5_SHA_256"
    assert kwargs["KeyId"] == "test-key-id"

    expected_digest = hashlib.sha256(LARGE_PAYLOAD).digest()
    assert kwargs["Message"] == expected_digest
    assert len(kwargs["Message"]) == 32
    assert len(kwargs["Message"]) <= 4096
    assert algorithm.name == "sha256"


@patch("utils.certs.crypto_kms_classes.boto3")
def test_rsa_sign_rejects_mismatched_hash_before_kms(mock_boto3):
    """RSA cannot produce a CSR with mismatched AlgorithmIdentifier and signature hashes."""
    private_key = AWSKMSRSAPrivateKey("test-key-id", "sha256")

    with pytest.raises(
        ValueError,
        match="Configured hash algorithm sha256 does not match supplied hash algorithm sha384",
    ):
        private_key.sign(LARGE_PAYLOAD, padding.PKCS1v15(), hashes.SHA384())

    mock_boto3.client.assert_not_called()


@patch("utils.certs.crypto_kms_classes.boto3")
def test_ec_sign_rejects_unknown_hash_algorithm(mock_boto3):
    """An unsupported hash algorithm raises NotImplementedError before calling KMS."""
    mock_boto3.client.return_value = MagicMock()

    private_key = AWSKMSEllipticCurvePrivateKey("test-key-id", "md5")

    with pytest.raises(NotImplementedError):
        private_key.sign(LARGE_PAYLOAD, ec.ECDSA(hashes.MD5()))
