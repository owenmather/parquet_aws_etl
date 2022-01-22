
variable "transformation_lambda_name" {
  type        = string
  description = "name of the transformation lambda"
}

variable "s3_transformation_bucket_name" {
  type        = string
  description = "name of the transformation s3 bucket"
}

variable "resource_prefix" {
  type        = string
  description = "prefix name for all owned resources"
}

variable "environment" {
  type        = string
  description = "environment for deployment"
}

variable "application" {
  type        = string
  description = "name of application"
}

variable "region" {
  type        = string
  description = "aws region"
}

variable "loglevel" {
  type        = string
  description = "logging level for lambda application"
}

variable "input_file" {
  type        = string
  description = "str, path object or file-like object to parquet file to process"
}

variable "build_layer_name" {
  type        = string
  description = "name of lambda build layer to user"
}