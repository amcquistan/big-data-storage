
import logging
import sys

from pgdb import connect

try:
    from awsglue.utils import getResolvedOptions
except:
    # mock for local development and testing
    import argparse
    def getResolvedOptions(args, options):
        parser = argparse.ArgumentParser()
        for opt in options:
            parser.add_argument('--'+opt, required=True)
        return vars(parser.parse_args(args[1:]))

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def main(args):
    # extract data from Postgres and load to S3

    # load data from S3 into Redshift staging tables

    # transform and load into prod tables in Redshift
    pass


if __name__ == '__main__':
    expected_args = [
        "s3_bucket",
        "redshift_dbname",
        "redshift_dbhost",
        "redshift_dbport",
        "redshift_dbuser",
        "redshift_dbpasswd",
        "postgres_dbname",
        "postgres_dbhost",
        "postgres_dbport",
        "postgres_dbuser",
        "postgres_dbpasswd"
    ]
    args = getResolvedOptions(sys.argv, expected_args)
    main(args)
  