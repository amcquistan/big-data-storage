

DROP TABLE IF EXISTS customer_dim;
CREATE TABLE customer_dim (
    customer_id INTEGER,
    first_name VARCHAR(254),
    last_name VARCHAR(254)
)
SORTKEY(customer_id)
DISTSTYLE ALL;

DROP TABLE IF EXISTS film_dim;
CREATE TABLE film_dim(
    film_id INTEGER,
    title VARCHAR(254),
    release_year INTEGER,
    rating oltp.mpaa_rating
)
SORTKEY(film_id)
DISTSTYLE(ALL);

DROP TABLE IF EXISTS staff_dim;
CREATE TABLE staff_dim(
    staff_id INTEGER,
    first_name VARCHAR(254),
    last_name VARCHAR(254)
)
SORTKEY(staff_id)
DISTSTYLE(ALL);

DROP TABLE IF EXISTS date_dim;
CREATE TABLE date_dim(
    date_id INTEGER,
    date DATE,
    year INTEGER,
    month INTEGER,
    day_of_month INTEGER,
    week_of_year INTEGER,
    day_of_week INTEGER
)
SORTKEY(date_id)
DISTSTYLE(ALL);

DROP TABLE IF EXISTS sales_facts;
CREATE TABLE sales_facts(
    film_id INTEGER NOT NULL,
    customer_id INTEGER NOT NULL,
    staff_id INTEGER NOT NULL,
    date_id INTEGER NOT NULL,
    amount NUMERIC(5, 2),
    UNIQUE(film_id, customer_id, staff_id, date_id)
)
COMPOUND SORTKEY (date_id, film_id)
DISTKEY(date_id);
