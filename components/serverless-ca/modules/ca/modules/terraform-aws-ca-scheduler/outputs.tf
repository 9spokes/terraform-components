output "schedule_arn" {
  value = aws_scheduler_schedule.schedule.arn
}

output "schedule_name" {
  value = aws_scheduler_schedule.schedule.name
}

output "schedule_state" {
  value = aws_scheduler_schedule.schedule.state
}
