locals {

  # Example base tags for eu resources
  tags_eu = {
    environment = var.environment
    application = var.application
    region = var.region
  }

  lambda_zip_path = "${path.module}/../dist/${var.transformation_lambda_name}.zip"
  lambda_build_layer_path = "${path.module}/../dist/${var.build_layer_name}.zip"
}
