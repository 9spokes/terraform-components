output "lambda_functions" {
  description = "Operational Lambda function names and ARNs"
  value       = try(module.ca[0].lambda_functions, {})
}

output "state_machine" {
  value = try(module.ca[0].state_machine, null)
}

output "scheduler" {
  value = try(module.ca[0].scheduler, null)
}

output "dynamodb_table" {
  value = try(module.ca[0].dynamodb_table, null)
}

output "kms_keys" {
  value = try(module.ca[0].kms_keys, {})
}

output "s3_buckets" {
  value = try(module.ca[0].s3_buckets, {})
}

output "database_reader_role_arn" {
  value = try(module.ca[0].database_reader_role_arn, null)
}

output "sns_topic_arn" {
  value = try(module.ca[0].sns_topic_arn, null)
}

output "certificate_locations" {
  description = "Private S3 locations for the CA bundle, certificates, and CRLs"
  value       = try(module.ca[0].certificate_locations, {})
}

output "deployment_contract" {
  description = "Auditable artifact, authorization, and hardening contract"
  value       = try(module.ca[0].deployment_contract, null)
}
