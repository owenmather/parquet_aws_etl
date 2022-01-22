import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
import re

args = getResolvedOptions(sys.argv, ["JOB_NAME"])
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args["JOB_NAME"], args)

# Script generated for node S3 bucket
S3bucket_node1 = glueContext.create_dynamic_frame.from_options(
    format_options={},
    connection_type="s3",
    format="parquet",
    connection_options={
        "paths": [
            "s3://eu-transformation-s3/lambda/build-layer/sample-file-assessment.snappy.parquet"
        ]
    },
    transformation_ctx="S3bucket_node1",
)

# Dropped fields with apply mapping "has_subtrackers,token,dataplatform_inserted_at"
ApplyMapping_node2 = ApplyMapping.apply(
    frame=S3bucket_node1,
    mappings=[
        ("name", "string", "name", "string"),
        ("value", "float", "value", "float"),
        ("start_date", "date", "start_date", "date"),
        ("end_date", "date", "end_date", "date"),
        ("year_week", "string", "year_week", "string"),
        ("country", "string", "country", "string"),
        ("os_name", "string", "os_name", "string"),
    ],
    transformation_ctx="ApplyMapping_node2",
)

# Filter entries where OS is 'ios' and country is 'FR'
Filter_node1642875715697 = Filter.apply(
    frame=ApplyMapping_node2,
    f=lambda row: (
        bool(re.match("ios", row["os_name"])) and bool(re.match("FR", row["country"]))
    ),
    transformation_ctx="Filter_node1642875715697",
)

# Repartition to single
repartitioned1 = Filter_node1642875715697.repartition(1)

# Script generated for node S3 bucket
S3bucket_node3 = glueContext.write_dynamic_frame.from_options(
    frame=repartitioned1,
    connection_type="s3",
    format="csv",
    connection_options={"path": "s3://eu-transformation-s3/glue2/", "partitionKeys": []},
    transformation_ctx="S3bucket_node3",
)

job.commit()
