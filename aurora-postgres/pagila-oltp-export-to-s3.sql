
SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SELECT pg_catalog.set_config('search_path', 'public', false);

CREATE EXTENSION IF NOT EXISTS aws_s3 CASCADE;

SELECT pg_catalog.set_config('search_path', '', false);

DROP FUNCTION IF EXISTS oltp.get_sales_facts;
CREATE FUNCTION oltp.get_sales_facts() 
  RETURNS TABLE (film_id INTEGER,
                customer_id INTEGER,
                staff_id INTEGER,
                date_id INTEGER,
                amount NUMERIC(5, 2))
  LANGUAGE plpgsql
AS $$
  BEGIN
    RETURN QUERY 
            SELECT DISTINCT i.film_id, 
                  p.customer_id, 
                  p.staff_id, 
                  TO_CHAR(payment_date, 'yyyymmdd')::INT AS date_id, 
                  p.amount
            FROM oltp.payment p
                JOIN oltp.rental r ON p.rental_id = r.rental_id
                JOIN oltp.inventory i ON r.inventory_id = i.inventory_id
            ORDER BY date_id, i.film_id;
END; $$;

DROP FUNCTION IF EXISTS oltp.get_date_dim;
CREATE FUNCTION oltp.get_date_dim() 
  RETURNS TABLE (date_id INTEGER,
                date DATE,
                year INTEGER,
                month INTEGER,
                day_of_month INTEGER,
                week_of_year INTEGER,
                day_of_week INTEGER)
LANGUAGE plpgsql
AS $$
  BEGIN
  RETURN QUERY
      SELECT TO_CHAR(date_seq, 'YYYYMMDD')::INT AS date_id,
              date_seq AS date,
              EXTRACT(ISOYEAR FROM date_seq)::INTEGER AS year,
              EXTRACT(MONTH FROM date_seq)::INTEGER AS month,
              EXTRACT(DAY FROM date_seq)::INTEGER AS day_of_month,
              EXTRACT(WEEK FROM date_seq)::INTEGER AS week_of_year,
              EXTRACT(ISODOW FROM date_seq)::INTEGER AS day_of_week
      FROM (SELECT '2010-01-01'::DATE + SEQUENCE.DAY AS date_seq
              FROM GENERATE_SERIES(0, 5000) AS SEQUENCE(DAY)
              ORDER BY date_seq) DS;
END; $$;

DROP PROCEDURE IF EXISTS oltp.export_s3_staging_tables;
CREATE PROCEDURE oltp.export_s3_staging_tables(s3_bucket VARCHAR, aws_region VARCHAR)
  LANGUAGE plpgsql
  AS $$
  BEGIN
    RAISE NOTICE 'Exporting staging tables to S3 %', s3_bucket;

    PERFORM aws_s3.query_export_to_s3(
        'SELECT customer_id, first_name, last_name FROM oltp.customer ORDER BY customer_id',
        s3_bucket,
        'customers.csv',
        aws_region,
        options :='format csv'
    );

    PERFORM aws_s3.query_export_to_s3(
        'SELECT film_id, title, release_year, rating FROM film ORDER BY film_id',
        s3_bucket,
        'films.csv',
        aws_region,
        options :='format csv'
    );

    PERFORM aws_s3.query_export_to_s3(
        'SELECT staff_id, first_name, last_name FROM staff ORDER BY staff_id',
        s3_bucket,
        'staff.csv',
        aws_region,
        options :='format csv'
    );

    PERFORM aws_s3.query_export_to_s3(
        'SELECT oltp.get_date_dim()',
        s3_bucket,
        'dates.csv',
        aws_region,
        options :='format csv'
    );

    PERFORM aws_s3.query_export_to_s3(
        'SELECT oltp.get_sales_facts()',
        s3_bucket,
        'sales_facts.csv',
        aws_region,
        options :='format csv'
    );
  END;
  $$;
