resource "aws_s3_bucket" "epsagon-trail" {
  bucket_prefix = "epsagon-trail-bucket"

  force_destroy = true

  lifecycle_rule {
    enabled = true

    expiration {
      days = "1"
    }
  }

  tags {
    Name = "Epsagon CloudTrail bucket"
  }
}

resource "aws_cloudformation_stack" "epsagon" {
  name = "epsagon"

  template_url = "https://s3.amazonaws.com/epsagon-cloudformation/terraform_template.json"
  capabilities = ["CAPABILITY_NAMED_IAM"]

  parameters {
    AWSAccount         = "${var.epsagon_account_id}"
    ExternalId         = "${var.epsagon_external_id}"
    EpsagonSns         = "${var.epsagon_sns_name}"
    ExternalBucketName = "${aws_s3_bucket.epsagon-trail.id}"
  }
}
