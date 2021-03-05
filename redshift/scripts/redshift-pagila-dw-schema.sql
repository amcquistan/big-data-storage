
DROP TABLE IF EXISTS customer_dim;
CREATE TABLE customer_dim (
    customer_id INTEGER SORTKEY,
    first_name VARCHAR(254),
    last_name VARCHAR(254)
)
DISTSTYLE ALL;

DROP TABLE IF EXISTS film_dim;
CREATE TABLE film_dim(
    film_id INTEGER SORTKEY,
    title VARCHAR(254),
    release_year INTEGER,
    rating VARCHAR(10)
)
DISTSTYLE ALL;

DROP TABLE IF EXISTS staff_dim;
CREATE TABLE staff_dim(
    staff_id INTEGER SORTKEY,
    first_name VARCHAR(254),
    last_name VARCHAR(254)
)
DISTSTYLE ALL;

DROP TABLE IF EXISTS date_dim;
CREATE TABLE date_dim(
    date_id INTEGER SORTKEY,
    date DATE,
    year INTEGER,
    month INTEGER,
    day_of_month INTEGER,
    week_of_year INTEGER,
    day_of_week INTEGER
)
DISTSTYLE ALL;

DROP TABLE IF EXISTS sales_facts;
CREATE TABLE sales_facts(
    film_id INTEGER NOT NULL,
    customer_id INTEGER NOT NULL,
    staff_id INTEGER NOT NULL,
    date_id INTEGER NOT NULL DISTKEY,
    amount NUMERIC(5, 2)
)
COMPOUND SORTKEY (date_id, film_id);
