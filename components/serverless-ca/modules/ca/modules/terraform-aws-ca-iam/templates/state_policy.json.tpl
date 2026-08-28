{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "CloudWatchLogs",
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogDelivery",
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:DeleteLogDelivery",
        "logs:DescribeLogGroups",
        "logs:DescribeResourcePolicies",
        "logs:GetLogDelivery",
        "logs:ListLogDeliveries",
        "logs:ListTagsLogGroup",
        "logs:PutLogEvents",
        "logs:PutResourcePolicy",
        "logs:PutRetentionPolicy",
        "logs:PutSubscriptionFilter",
        "logs:UpdateLogDelivery"
      ],
      "Resource": "*"
    },
    {
      "Sid": "XRay",
      "Effect": "Allow",
      "Action": [
        "xray:PutTraceSegments",
        "xray:PutTelemetryRecords",
        "xray:GetSamplingRules",
        "xray:GetSamplingTargets"
      ],
      "Resource": "*"
    },
    {
      "Sid": "PutCloudWatchMetrics",
      "Effect": "Allow",
      "Action": "cloudwatch:PutMetricData",
      "Resource": "*"
    },
    {
      "Sid": "Lambda",
      "Effect": "Allow",
      "Action": [
        "lambda:InvokeFunction"
      ],
      "Resource": [
        "arn:aws:lambda:${region}:${account_id}:function:${project}-create-root-ca-${env}:live",
        "arn:aws:lambda:${region}:${account_id}:function:${project}-root-ca-crl-${env}:live",
        "arn:aws:lambda:${region}:${account_id}:function:${project}-create-issuing-ca-${env}:live",
        "arn:aws:lambda:${region}:${account_id}:function:${project}-issuing-ca-crl-${env}:live",
        "arn:aws:lambda:${region}:${account_id}:function:${project}-tls-cert-${env}:live",
        "arn:aws:lambda:${region}:${account_id}:function:${project}-expiry-${env}:live"
      ]
    },
    {
      "Sid": "StepFunction",
      "Effect": "Allow",
      "Action": [
        "states:StartExecution"
      ],
      "Resource": "arn:aws:states:${region}:${account_id}:stateMachine:${project}-ca-${env}"
    },
    {
      "Sid": "DescribeDistributedMapExecutions",
      "Effect": "Allow",
      "Action": [
        "states:DescribeExecution"
      ],
      "Resource": "arn:aws:states:${region}:${account_id}:execution:${project}-ca-${env}:*"
    },
    {
      "Sid": "S3BucketLocation",
      "Effect": "Allow",
      "Action": [
        "s3:GetBucketLocation",
        "s3:ListBucket"
      ],
      "Resource": [
        "${internal_s3_bucket_arn}"
      ]
    },
    {
      "Sid": "S3BucketDownload",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject"
      ],
      "Resource": [
        "${internal_s3_bucket_arn}/*"
      ]
    },
    {
      "Sid": "KMSforEncryptedResources",
      "Effect": "Allow",
      "Action": [
        "kms:Decrypt",
        "kms:Encrypt",
        "kms:GenerateDataKey"
      ],
      "Resource": ${jsonencode(kms_arns_symmetric)}
    }
  ]
}
