from unittest.mock import patch

import pytest

from utils.certs.db import db_get_table_name, db_list_certificates


@pytest.fixture(autouse=True)
def clear_table_name(monkeypatch):
    monkeypatch.delenv("DYNAMODB_TABLE_NAME", raising=False)


def test_terraform_supplied_table_name_wins(monkeypatch):
    monkeypatch.setenv("DYNAMODB_TABLE_NAME", "9spokesCAInternal-G1")

    assert db_get_table_name("9spokes", "internal-g1") == "9spokesCAInternal-G1"


def test_blank_table_name_falls_back_to_derivation(monkeypatch):
    monkeypatch.setenv("DYNAMODB_TABLE_NAME", "   ")

    assert db_get_table_name("example", "test") == "ExampleCATest"


def test_upstream_derivation_is_preserved_without_terraform_name():
    assert db_get_table_name("secure-email", "dev") == "SecureEmailCADev"


def test_python_derivation_diverges_from_hcl_for_digit_leading_projects():
    # HCL title("9spokes") leaves the leading digit word untouched ("9spokes"), while
    # Python str.title() capitalises the letter after the digit ("9Spokes"). Terraform
    # created 9spokesCAInternal-G1; the derived name never existed, so the first live
    # initialization failed with AccessDenied on dynamodb:Query. The environment
    # variable exists to make this divergence irrelevant.
    derived = db_get_table_name("9spokes", "internal-g1")

    assert derived == "9SpokesCAInternal-G1"
    assert derived != "9spokesCAInternal-G1"


@patch("utils.certs.db.boto3")
def test_live_query_uses_terraform_table_name_for_9spokes(mock_boto3, monkeypatch):
    # Reproduces the first internal-g1 initialization: create_root_ca -> db_list_certificates
    # -> dynamodb:Query. Terraform created 9spokesCAInternal-G1; the query must name it exactly.
    monkeypatch.setenv("DYNAMODB_TABLE_NAME", "9spokesCAInternal-G1")
    client = mock_boto3.client.return_value
    client.query.return_value = {"Items": []}

    db_list_certificates("9spokes", "internal-g1", "9spokes-root-ca-internal-g1", consistent_read=True)

    assert client.query.call_args.kwargs["TableName"] == "9spokesCAInternal-G1"
    assert client.query.call_args.kwargs["ConsistentRead"] is True


@patch("utils.certs.db.boto3")
def test_live_query_without_terraform_name_reproduces_the_failure(mock_boto3):
    client = mock_boto3.client.return_value
    client.query.return_value = {"Items": []}

    db_list_certificates("9spokes", "internal-g1", "9spokes-root-ca-internal-g1")

    # This is the table that never existed and produced AccessDenied on dynamodb:Query.
    assert client.query.call_args.kwargs["TableName"] == "9SpokesCAInternal-G1"
