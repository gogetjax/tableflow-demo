#!/usr/bin/env python3
"""Delta consumer by S3 path, using Spark + Delta Lake (the reference reader).

Why Spark and not delta-rs: Tableflow writes Delta with column mapping mode `id` (physical names
`col_N` resolved through Parquet field IDs) and enables the `typeWidening` and `deletionVectors`
reader features. delta-rs 1.6 refuses the table (unsupported reader features) and DuckDB's delta
extension resolves columns by physical name and returns NULLs (docs/06, docs/09 Q10).

No catalog, no Confluent. Credentials from the AWS default chain (instance role / env).
Env:
  DELTA_TABLE_URI  s3://<bucket>/<table_path>
  AWS_REGION       default us-east-1
  SPARK_JARS       optional: comma-separated local jar paths (offline runner). When unset, the
                   Delta and Hadoop-AWS packages are pulled from Maven Central.
Flags: --version-only, --count-only
"""
import argparse
import os
import sys

from pyspark.sql import SparkSession

DELTA_VERSION = "3.3.2"
HADOOP_AWS_VERSION = "3.3.4"


def session(region: str) -> SparkSession:
    b = (
        SparkSession.builder.appName("tableflow-demo-delta-consumer")
        .master("local[2]")
        .config("spark.sql.extensions", "io.delta.sql.DeltaSparkSessionExtension")
        .config("spark.sql.catalog.spark_catalog", "org.apache.spark.sql.delta.catalog.DeltaCatalog")
        .config("spark.hadoop.fs.s3a.aws.credentials.provider",
                "com.amazonaws.auth.DefaultAWSCredentialsProviderChain")
        .config("spark.hadoop.fs.s3a.endpoint.region", region)
        .config("spark.driver.memory", os.environ.get("SPARK_DRIVER_MEMORY", "2g"))
        .config("spark.ui.enabled", "false")
    )
    jars = os.environ.get("SPARK_JARS")
    if jars:
        b = b.config("spark.jars", jars)
    else:
        b = b.config("spark.jars.packages",
                     f"io.delta:delta-spark_2.12:{DELTA_VERSION},org.apache.hadoop:hadoop-aws:{HADOOP_AWS_VERSION}")
    return b.getOrCreate()


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--version-only", action="store_true")
    ap.add_argument("--count-only", action="store_true")
    args = ap.parse_args()

    uri = os.environ["DELTA_TABLE_URI"].replace("s3://", "s3a://", 1)
    region = os.environ.get("AWS_REGION", "us-east-1")
    spark = session(region)
    spark.sparkContext.setLogLevel("ERROR")

    from delta.tables import DeltaTable  # after the session so the extension is loaded

    dt = DeltaTable.forPath(spark, uri)
    hist = dt.history(1).select("version").collect()
    version = hist[0]["version"] if hist else None
    if args.version_only:
        print(version)
        return 0

    df = spark.read.format("delta").load(uri)
    n = df.count()
    if args.count_only:
        print(n)
        return 0

    print(f"table:        {uri}")
    print(f"version       {version}")
    print("schema:")
    df.printSchema()
    print(f"row count     {n}")
    print("first 5 rows:")
    df.select("order_id", "customer_id", "product_id", "quantity", "unit_price_cents",
              "currency", "ordered_at", "status", "source").show(5, truncate=False)
    return 0


if __name__ == "__main__":
    sys.exit(main())
