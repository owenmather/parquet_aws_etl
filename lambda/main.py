import os
import pandas as pd
import logging

logging.getLogger().setLevel(os.environ.get("LOGLEVEL", "ERROR"))
LOG = logging.getLogger(__name__)

IN_FILE = os.environ.get("IN_FILE", "data/sample-file-assessment.snappy.parquet")
OUT_FILE = os.environ.get("OUT_FILE", "output/example.csv")


def run():
    df = pd.read_parquet(IN_FILE)

    # Convert dtypes to reduce memory usage
    type_conversion(df=df)

    # Check if we have any empty values in our dateset ~ would indicate potential for cleaning ~ imputing/removing etc
    if df.isnull().values.any():
        # Deal with missing values - Not implemented for this exercise
        handle_missing_values(df=df)

    # lets compute the weekly highest values for each name
    # First Drop columns we will not use
    # Drop everything after year_week and start+end date columns
    df.drop(columns=list(df.columns[5:]) + ["start_date", "end_date"], inplace=True)
    # Sum the values by name category for each year_week
    df["Weekly Total"] = df.groupby(['year_week', 'name'])["value"].transform('sum')
    # Compute the max value for each week
    df["Weekly Max"] = df.groupby(['year_week'])["Weekly Total"].transform('max')
    # Select the rows where the Weekly Total is the Weekly Max
    df = df[df["Weekly Max"] == df["Weekly Total"]]
    # Remove the duplicate (name,year_week) keys and reset the indexes
    df.drop_duplicates(["name", "year_week"], inplace=True)
    df.reset_index(drop=True, inplace=True)
    df.drop(columns=["value", "Weekly Max"], inplace=True, errors="ignore")
    # Use the year_week as index and sort
    df.set_index('year_week', inplace=True)
    df.sort_index(inplace=True)
    df.rename(columns={'Weekly Total': 'weekly_sum'}, inplace=True)
    df.to_csv(OUT_FILE)


def type_conversion(df: pd.DataFrame):
    """

    :param df:
    :return:
    """
    # Convert categorical datatypes
    df[["name", "country", "os_name", "year_week"]] = df[["name", "country", "os_name", "year_week"]].astype("category")
    # Value can be changed to int
    df["value"] = df["value"].astype("int")


def handle_missing_values(df: pd.DataFrame):
    """
    Not implemented for exercise
    :param df:
    :return:
    """
    LOG.warning("Missing value logic not implemented")


# Entrypoint for lambda
def lambda_handler(event, context):
    LOG.info("Running Transformation function")
    run()


if __name__ == "__main__":
    run()
