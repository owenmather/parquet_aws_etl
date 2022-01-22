terraform {
  required_version = "=1.1.4"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = "eu-central-1"
  default_tags {
    tags = local.tags_eu
  }
}

# Use local state file for this project
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}

# S3 Bucket for transformed data
resource "aws_s3_bucket" "transformation-data-s3" {
  bucket = var.s3_transformation_bucket_name
  versioning {
    enabled = true
  }
  # Enable server-side encryption by default
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  force_destroy = true

  policy = data.aws_iam_policy_document.s3_policy_force_https.json
}


# Deny all non SSL requests
data "aws_iam_policy_document" "s3_policy_force_https" {
  statement {
    sid = "AllowSSLRequestsOnly"
    actions = ["s3:*"]
    resources = [
      "arn:aws:s3:::${var.s3_transformation_bucket_name}/*",
      "arn:aws:s3:::${var.s3_transformation_bucket_name}"]
    effect = "Deny"
    principals {
      identifiers = ["*"]
      type = "*"
    }
    condition {
      test = "Bool"
      values = ["false"]
      variable = "aws:SecureTransport"
    }
  }
}

# Zip up lambda logic for deployment
data "archive_file" "transformation-lambda-zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda"
  output_path = local.lambda_zip_path
}

# Create build layer with dependencies
resource "aws_lambda_layer_version" "transformation-lambda-build-layer" {
  s3_bucket = aws_s3_bucket.transformation-data-s3.bucket
  s3_key = "lambda/build-layer/transformation.zip"
  layer_name = "${var.application}-${var.build_layer_name}"
  compatible_runtimes = ["python3.8"]
}


resource "aws_lambda_function" "transformation-lambda" {
  function_name = var.transformation_lambda_name
  # For this demo just use locally zipped lambda. Production would use S3 with versioning system for releases
  filename = local.lambda_zip_path
  source_code_hash = data.archive_file.transformation-lambda-zip.output_base64sha256
  description = "Example scheduled python function to transform parquet file"
  runtime = "python3.8"
  handler = "main.lambda_handler"
  timeout = 600
  role = aws_iam_role.lambda_role.arn
  publish = false
  memory_size = 128
  layers = [aws_lambda_layer_version.transformation-lambda-build-layer.arn]
  environment {
    variables = {
      IN_FILE = var.input_file
      OUT_FILE = "s3://eu-transformation-s3/output/weekly_counts.csv"
      LOGLEVEL = var.loglevel
    }
  }

  tracing_config {
    mode = "PassThrough"
  }

}


data "aws_iam_policy_document" "lambda_assume_policy" {
  statement {
    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type = "Service"

      identifiers = [
        "lambda.amazonaws.com",
      ]
    }
  }
}

resource "aws_iam_role" "lambda_role" {
  name = "${var.transformation_lambda_name}-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_policy.json
}

resource "aws_iam_role_policy_attachment" "lambda_cloudwatch_role_policy" {
  role = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchFullAccess"
}

# Demo allowing full s3 access for time saving. Would restrict to r/w
resource "aws_iam_role_policy_attachment" "lambda_s3_role_policy" {
  role = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

//AWS Glue Config
resource  "aws_glue_job" "transform_glue_job" {
  name     = "transformation-example"
  role_arn = aws_iam_role.glue-role.arn
  description = "Example ETL Job"
  max_retries = 0
  glue_version = "3.0"
  number_of_workers = 2
  worker_type = "G.1X"

  command {
    script_location = "s3://${aws_s3_bucket.transformation-data-s3.bucket}/transform_job.py"
  }

  default_arguments = {
    "--job-language" = "python"
    "--job-bookmark-option" = "job-bookmark-disable"
  }

  timeout = 2

}

resource "aws_iam_role" "glue-role" {
  name = "AWSGlueServiceRoleDefault"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "glue.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

# Use AWS Default Role for Glue
resource "aws_iam_role_policy_attachment" "glue_service" {
    role = aws_iam_role.glue-role.id
    policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# Demo allowing full s3 access for time saving. Would restrict to r/w
resource "aws_iam_role_policy" "glue_s3_role_policy" {
  role = aws_iam_role.glue-role.name
  policy = data.aws_iam_policy_document.s3_rw_policy.json
}

# Allow full access on our bucket for convenience
data "aws_iam_policy_document" "s3_rw_policy" {
  statement {
    actions = ["s3:*"]
    resources = ["arn:aws:s3:::${var.s3_transformation_bucket_name}/*"]
  }
}

resource "aws_glue_workflow" "transformation-workflow" {
  name = "transformation-workflow"
  max_concurrent_runs = 1
}

# Example schedule 22 hours every day
resource "aws_glue_trigger" "transformation-trigger" {
  name          = "transformation-start"
  schedule = "cron(0 22 * * * *)"
  type     = "SCHEDULED"
  workflow_name = aws_glue_workflow.transformation-workflow.name

  actions {
    job_name = aws_glue_job.transform_glue_job.name
  }
}