# Zip up dependencies for lambda build layer and push to S3
pip install -r requirements.txt --no-deps -t .build-layer/python
cd .build-layer
zip -r ../dist/build-layer.zip python/*

# Upload build layer to S3.
aws s3api put-object --bucket "eu-transformation-s3" --key "lambda/build-layer/transformation.zip" --body dist/build-layer.zip