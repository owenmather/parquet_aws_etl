output "s3-name" {
  value = aws_s3_bucket.transformation-data-s3.bucket_domain_name
}

output "root" {
  value = path.root
}

output "cwd" {
  value =path.cwd
}

output "module" {
  value = path.module
}