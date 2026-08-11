{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "StepFunction",
      "Effect": "Allow",
      "Action": [
        "states:StartExecution"
      ],
      "Resource": "arn:aws:states:${region}:${account_id}:stateMachine:${project}-ca-${env}"
    }
  ]
}
