output "ip_addresses" {
  value       = aws_cloudhsm_v2_hsm.hsm.*.ip_address
  description = "List of CloudHSM IP addresses"
}
