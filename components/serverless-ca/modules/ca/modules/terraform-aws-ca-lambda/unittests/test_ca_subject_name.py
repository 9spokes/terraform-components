import pytest
from cryptography.x509.oid import NameOID

from utils.certs.ca import ca_construct_subject_name


@pytest.mark.parametrize(
    ("hierarchy", "common_name"),
    [
        ("root", "9Spokes Internal Root CA G1"),
        ("issuing", "9Spokes Internal Issuing CA G1"),
    ],
)
def test_ca_subject_uses_approved_rdn_order(hierarchy, common_name):
    subject = ca_construct_subject_name(
        {
            "commonName": common_name,
            "country": "NZ",
            "organization": "9 SPOKES INTERNATIONAL LIMITED",
        },
        hierarchy,
    )

    attributes = [
        (attribute.oid, attribute.value) for rdn in subject.rdns for attribute in rdn
    ]

    assert attributes == [
        (NameOID.COUNTRY_NAME, "NZ"),
        (NameOID.ORGANIZATION_NAME, "9 SPOKES INTERNATIONAL LIMITED"),
        (NameOID.COMMON_NAME, common_name),
    ]
    assert (
        subject.rfc4514_string()
        == f"CN={common_name},O=9 SPOKES INTERNATIONAL LIMITED,C=NZ"
    )
