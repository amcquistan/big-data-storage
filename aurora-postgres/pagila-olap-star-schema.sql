-- pagila-olap-star-schema.sql

CREATE SCHEMA IF NOT EXISTS olap;

DROP TABLE IF EXISTS olap.customer_dim;
CREATE TABLE olap.customer_dim (
    customer_id INTEGER PRIMARY KEY,
    first_name VARCHAR(254),
    last_name VARCHAR(254)
);

DROP TABLE IF EXISTS olap.film_dim;
CREATE TABLE olap.film_dim(
    film_id INTEGER PRIMARY KEY,
    title VARCHAR(254),
    release_year INTEGER,
    rating oltp.mpaa_rating
);

DROP TABLE IF EXISTS olap.staff_dim;
CREATE TABLE olap.staff_dim(
    staff_id INTEGER PRIMARY KEY,
    first_name VARCHAR(254),
    last_name VARCHAR(254)
);

DROP TABLE IF EXISTS olap.date_dim;
CREATE TABLE olap.date_dim(
    date_id INTEGER PRIMARY KEY,
    date TIMESTAMP WITH TIME ZONE,
    year INTEGER,
    month INTEGER,
    day_of_month INTEGER,
    week_of_year INTEGER,
    day_of_week INTEGER
);

DROP TABLE IF EXISTS olap.sales_facts;
CREATE TABLE olap.sales_facts(
    film_id INTEGER NOT NULL,
    customer_id INTEGER NOT NULL,
    staff_id INTEGER NOT NULL,
    date_id INTEGER NOT NULL,
    amount NUMERIC(5, 2),
    UNIQUE(film_id, customer_id, staff_id, date_id)
);


CREATE OR REPLACE PROCEDURE olap.run_elt()
LANGUAGE plpgsql
AS $$
BEGIN

    INSERT INTO olap.date_dim(date_id, date, year, month, day_of_month, week_of_year, day_of_week)
    SELECT TO_CHAR(date_seq, 'yyyymmdd')::INT AS date_id,
        date_seq AS date,
        EXTRACT(ISOYEAR FROM date_seq) AS year,
        EXTRACT(MONTH FROM date_seq) AS month,
        EXTRACT(DAY FROM date_seq) AS day_of_month,
        EXTRACT(WEEK FROM date_seq) AS week_of_year,
        EXTRACT(ISODOW FROM date_seq) AS day_of_week
    FROM (SELECT '2010-01-01'::DATE + SEQUENCE.DAY AS date_seq
            FROM GENERATE_SERIES(0, 5000) AS SEQUENCE(DAY)
            ORDER BY date_seq) DS
    ON CONFLICT(date_id) DO NOTHING;


    INSERT INTO film_dim(film_id, title, release_year, rating)
    SELECT film_id, title, release_year, rating FROM oltp.film
    ON CONFLICT(film_id) DO UPDATE SET 
        title = EXCLUDED.title,
        release_year = EXCLUDED.release_year,
        rating = EXCLUDED.rating;


    INSERT INTO staff_dim(staff_id, first_name, last_name)
    SELECT staff_id, first_name, last_name FROM oltp.staff
    ON CONFLICT(staff_id) DO UPDATE SET 
        first_name = EXCLUDED.first_name,
        last_name = EXCLUDED.last_name;


    INSERT INTO customer_dim (customer_id, first_name, last_name)
    SELECT customer_id, first_name, last_name FROM customer
    ON CONFLICT(customer_id) DO UPDATE SET
        first_name = EXCLUDED.first_name,
        last_name = EXCLUDED.last_name;


    CREATE TABLE olap.sales_facts_tmp (LIKE olap.sales_facts INCLUDING ALL);

    INSERT INTO olap.sales_facts_tmp(
        film_id, customer_id, staff_id, date_id, amount
    ) SELECT DISTINCT i.film_id, 
                p.customer_id, 
                p.staff_id, 
                TO_CHAR(payment_date, 'yyyymmdd')::INT AS date_id, 
                amount
    FROM oltp.payment p
        JOIN oltp.rental r ON p.rental_id = r.rental_id
        JOIN oltp.inventory i ON r.inventory_id = i.inventory_id;

    ALTER TABLE olap.sales_facts RENAME TO sales_facts_old;
    ALTER TABLE olap.sales_facts_tmp RENAME TO sales_facts;
    
    DROP TABLE olap.sales_facts_old CASCADE;

    COMMIT;
END; $$;
