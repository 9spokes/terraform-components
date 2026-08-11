output "ddb_table_arn" {
  value = aws_dynamodb_table.ca.arn
}

output "ddb_table_name" {
  value = aws_dynamodb_table.ca.name
}

output "deletion_protection_enabled" {
  value = var.enable_deletion_protection
}
