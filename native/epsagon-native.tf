data "aws_caller_identity" "current" {}

locals {
  epsagon_trail_bucket_name = aws_s3_bucket.epsagon_trail_bucket.id
}

variable "epsagon_aws_account_id" {}
variable "epsagon_external_id" {}
variable "region" {}

resource "aws_s3_bucket" "epsagon_trail_bucket" {
  bucket = "epsagon-trail-bucket"
  acl    = "private"
  lifecycle_rule {
    expiration {
      days = 1
    }
    enabled = true
  }
}

resource "aws_s3_bucket_policy" "epsagon_trail_bucket_policy" {
  bucket = local.epsagon_trail_bucket_name
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Id": "epsagon_trail_bucket_policy",
  "Statement": [
    {
      "Sid": "GetBucket",
      "Effect": "Allow",
      "Principal": {
        "Service": [
          "cloudtrail.amazonaws.com"
        ]
      },
      "Action": "s3:GetBucket*",
      "Resource": "arn:aws:s3:::${local.epsagon_trail_bucket_name}"
    },
     {
      "Sid": "PutObject",
      "Effect": "Allow",
      "Principal": {
        "Service": [
          "cloudtrail.amazonaws.com"
        ]
      },
      "Action": "s3:PutObject*",
      "Resource": "arn:aws:s3:::${local.epsagon_trail_bucket_name}/*"
    }   
  ]
}
POLICY
}

resource "aws_cloudwatch_log_group" "epsagon_monitoring_log_group" {
  name              = "epsagon_monitoring_log_group"
  retention_in_days = 1
}

resource "aws_iam_role" "epsagon_cloudtrail_to_cloudwatch_logs_role" {
  name               = "epsagon_cloudtrail_to_cloudwatch_logs_role"
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": [
          "cloudtrail.amazonaws.com"
        ]
      },
      "Action": [
        "sts:AssumeRole"
      ]
    }
  ]
}
POLICY
}

resource "aws_iam_policy" "epsagon_cloudtrail_to_cloudwatch_logs_role_policy" {
  name   = "epsagon_cloudtrail_to_cloudwatch_logs_role_policy"
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:PutLogEvents",
        "logs:CreateLogStream"
      ],
      "Resource": "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:epsagon_monitoring_log_group:log-stream:*"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "epsagon_cloudtrail_to_cloudwatch_logs_role_policy_attachment" {
  role       = aws_iam_role.epsagon_cloudtrail_to_cloudwatch_logs_role.name
  policy_arn = aws_iam_policy.epsagon_cloudtrail_to_cloudwatch_logs_role_policy.arn
}

resource "aws_cloudtrail" "epsagon_cloudtrail" {
  name                       = "epsagon_monitoring_trail"
  s3_bucket_name             = local.epsagon_trail_bucket_name
  cloud_watch_logs_group_arn = aws_cloudwatch_log_group.epsagon_monitoring_log_group.arn
  cloud_watch_logs_role_arn  = aws_iam_role.epsagon_cloudtrail_to_cloudwatch_logs_role.arn
  is_multi_region_trail      = true
  event_selector {
    read_write_type = "WriteOnly"
  }
  depends_on = [
    aws_s3_bucket_policy.epsagon_trail_bucket_policy,
    aws_s3_bucket.epsagon_trail_bucket
  ]

}

resource "aws_iam_role" "epsagon_role" {
  name               = "epsagon_role"
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowEpsagon",
      "Effect": "Allow",
      "Principal": {
        "AWS": [
          "${var.epsagon_aws_account_id}"
        ]
      },
      "Condition": {
        "StringEquals": {
          "sts:ExternalId":
            "${var.epsagon_external_id}"
        }
      },      
      "Action": [
        "sts:AssumeRole"
      ]
    },
    {
      "Sid": "AllowAppsync",
      "Effect": "Allow",
      "Principal": {
        "Service": "appsync.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }    
  ]
}
POLICY
}

resource "aws_iam_policy" "epsagon_role_policy" {
  name   = "epsagon_role_policy"
  policy = <<POLICY
{
  "Version": "2012-10-17",

  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "apigateway:GET",
        "appsync:GetDataSource",
        "appsync:GetGraphqlApi",
        "appsync:GetIntrospectionSchema",
        "appsync:GetResolver",
        "appsync:GetSchemaCreationStatus",
        "appsync:GetType",
        "appsync:GraphQL",
        "appsync:ListApiKeys",
        "appsync:ListDataSources",
        "appsync:ListGraphqlApis",
        "appsync:ListResolvers",
        "appsync:ListTypes",
        "appsync:UpdateGraphqlAPI",
        "appsync:UpdateResolver",
        "appsync:UpdateType",        
        "batch:Describe*",
        "cloudwatch:Get*",
        "cloudwatch:List*",
        "ec2:Describe*",
        "ec2:Get*",
        "ecs:Describe*",
        "ecs:List*",
        "events:PutRule",
        "events:PutTargets",
        "iam:ListAccountAliases",
        "lambda:Get*",
        "lambda:List*",
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:DeleteSubscriptionFilter",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams",
        "logs:DescribeSubscriptionFilters",
        "logs:FilterLogEvents",
        "logs:PutLogEvents",
        "logs:PutSubscriptionFilter",
        "states:Describe*",
        "states:Get*",
        "states:List*",
        "xray:BatchGet*",
        "xray:Get*"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "iam:PassRole",
      "Resource": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/epsagon_role_policy"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "epsagon_role_policy_attachment" {
  role       = aws_iam_role.epsagon_role.name
  policy_arn = aws_iam_policy.epsagon_role_policy.arn
}
