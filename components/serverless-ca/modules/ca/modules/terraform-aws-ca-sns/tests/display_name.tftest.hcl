mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "111111111111"
    }
  }

  mock_data "aws_region" {
    defaults = {
      region = "ap-southeast-2"
    }
  }
}

variables {
  project                       = "example"
  function                      = "ca-notifications"
  env                           = "test"
  custom_sns_topic_name         = "stable-topic-name"
  custom_sns_topic_display_name = "Operations CA"
}

run "custom_display_name_does_not_change_topic_name" {
  command = plan

  assert {
    condition     = aws_sns_topic.sns_topic.name == "stable-topic-name"
    error_message = "custom_sns_topic_name must continue to control the topic name."
  }

  assert {
    condition     = aws_sns_topic.sns_topic.display_name == "Operations CA"
    error_message = "custom_sns_topic_display_name must control the SNS display name."
  }
}
