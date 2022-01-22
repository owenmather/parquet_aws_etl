# Upload glue script to S3
aws s3api put-object --bucket "eu-transformation-s3" --key "transform_job.py" --body transform_job.py