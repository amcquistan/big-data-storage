
import logging
import sys

from pgdb import connect

from awsglue.utils import getResolvedOptions

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def main(args):
    # extract / transform data from Postgres and load to S3
    con, cur = None, None
    try:
        con = connect(
                database=args['postgres_dbname'],
                host=args['postgres_dbhost'],
                user=args['postgres_dbuser'],
                password=args['postgres_dbpasswd']
        )
        cur = con.cursor()
        cur.execute('CALL export_s3_staging_tables(%s, %s)', (args['s3_bucket'], args['aws_region']))
    except Exception as e:
        logger.error({
            'resource': __file__,
            'message_type': 'error',
            'message': str(e)
        })
        return e
    finally:
        if cur is not None:
            cur.close()
        if con is not None:
            con.close()

    # load data from S3 into Redshift staging tables
    con, cur = None, None
    try:
        con = connect(
                database=args['redshift_dbname'],
                host=args['redshift_dbhost'],
                user=args['redshift_dbuser'],
                password=args['redshift_dbpasswd']
        )
        cur = con.cursor()

        cur.execute("CREATE TEMP TABLE tmp_customer_dim (LIKE customer_dim)")
        cur.execute(
            "COPY tmp_customer_dim FROM %s IAM_ROLE %s DELIMITER ',' COMPUPDATE OFF", (
            "s3://{}/customers.csv".format(args['s3_bucket']),
            args['iam_role']
        ))
        cur.execute("""DELETE FROM customer_dim c
                        USING tmp_customer_dim t
                        WHERE c.customer_id = t.customer_id""")
        cur.execute("INSERT INTO customer_dim SELECT * FROM tmp_customer_dim")

        cur.execute("CREATE TEMP TABLE tmp_film_dim (LIKE film_dim)")
        cur.execute(
            "COPY tmp_film_dim FROM %s IAM_ROLE %s DELIMITER ',' COMPUPDATE OFF", (
            "s3://{}/films.csv".format(args['s3_bucket']),
            args['iam_role']
        ))
        cur.execute("""DELETE FROM film_dim f
                        USING tmp_film_dim t
                        WHERE f.film_id = t.film_id""")
        cur.execute("INSERT INTO film_dim SELECT * FROM tmp_film_dim")

        cur.execute("CREATE TEMP TABLE tmp_staff_dim (LIKE staff_dim)")
        cur.execute(
            "COPY tmp_staff_dim FROM %s IAM_ROLE %s DELIMITER ',' COMPUPDATE OFF", (
            "s3://{}/staff.csv".format(args['s3_bucket']),
            args['iam_role']
        ))
        cur.execute("""DELETE FROM staff_dim s
                        USING tmp_staff_dim t
                        WHERE s.staff_id = t.staff_id""")
        cur.execute("INSERT INTO staff_dim SELECT * FROM tmp_staff_dim")

        cur.execute("CREATE TEMP TABLE tmp_date_dim (LIKE date_dim)")
        cur.execute(
            "COPY tmp_date_dim FROM %S IAM_ROLE %s DELIMITER ',' COMPUPDATE OFF", (
            "s3://{}/dates.csv".format(args['s3_bucket']),
            args['iam_role']
        ))
        cur.execute("""DELETE FROM date_dim d
                        USING tmp_date_dim t
                        WHERE d.date_id = t.date_id""")
        cur.execute("INSERT INTO date_dim SELECT * FROM tmp_date_dim")

        cur.execute("CREATE TEMP TABLE tmp_sales_facts (LIKE sales_facts)")
        cur.execute(
            "COPY tmp_sales_facts FROM %s IAM_ROLE %s DELIMITER ',' COMPUPDATE OFF", (
            "s3://{}/sales_facts.csv".format(args['s3_bucket']),
            args['iam_role']
        ))
        cur.execute("""DELETE FROM sales_facts s
                        USING tmp_sales_facts t
                        WHERE s.film_id = t.film_id
                            AND s.custoemr_id = t.film_id
                            AND s.staff_id = t.staff_id
                            AND s.date_id = t.date_id""")
        cur.execute("INSERT INTO sales_facts SELECT * FROM tmp_sales_facts")

        con.commit()
    except Exception as e:
        logger.error({
            'resource': __file__,
            'message_type': 'error',
            'message': str(e)
        })
        return e
    finally:
        if cur is not None:
            cur.close()
        if con is not None:
            con.close()


if __name__ == '__main__':
    expected_args = [
        "s3_bucket",
        "aws_region",
        "iam_role",
        "redshift_dbname",
        "redshift_dbhost",
        "redshift_dbuser",
        "redshift_dbpasswd",
        "postgres_dbname",
        "postgres_dbhost",
        "postgres_dbuser",
        "postgres_dbpasswd"
    ]
    args = getResolvedOptions(sys.argv, expected_args)
    main(args)
  