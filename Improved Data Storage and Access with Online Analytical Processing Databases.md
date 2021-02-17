## Online Analytical Processing Databases Plus Extract, Transform and, Load in Aurora PostgreSQL

### Introduction

In recent times data and the information extracted from it has been equated to digitial gold for modern organizations looking to provide the best products or services to delight customers as well as improve process efficiency. Buzz words like business intelligence, data science, decision support systems, and similiar have empasized the importance of using facts derived from data to support decisions. This has translated into increasingly more frequent requests for data from various systems and departments across a continuim of ways ranging from hands on ad hock queries to BI software tools which create static and interactive reports. All this necessitates thoughtful consideration when designing the systems that organize and provides interfaces to these data stores which some have come to describe as Online Analytical Processing (OLAP) databases.

### OLTP vs OLAP

Historically the tool of choice among oranizations for organizing, durably storing and providing access to business data has been the relational database management system also commonly referred to as an Online Transaction Processing (OLTP) System. This technology has been an enourmously successful data store for backing the applications that have evolved to be the life blood of how the economies of the world function today which are designed for isolated interactions between the system and an actor such as an ecommerce order, a tax payment, or scheduling a medical appointment. OLTP databases emphazie writing data in a way that minimizes data duplication following a paradigm of [Atomic, Consistent, Isolated, Durable (ACID)](https://en.wikipedia.org/wiki/ACID) transactions which is largely accomplished through heavy [normalization](https://en.wikipedia.org/wiki/Database_normalization) of the data structure.

<img src="./oltp-pagila.jpg">

As needs for gathering data for analysis and decision making increased it became apparent that the design philosphy centered on maximizing writability in traditional OLTP database was incongruent with this new need for meaningful data retrival emphasizing pulling relationships together and subsequent aggregations like counts, sums and averages.  These types of queries in OLTP databases are often unnecessarily complex, error prone, and above all strenous to the underlying database often leading to serious degration exhibited in important applications built on top of them. 

<img src="./oltp-fail.jpg">

From this a new paradigm was born and termed [Online Analytical Processing (OLAP)](https://en.wikipedia.org/wiki/Online_analytical_processing) systems which instead focus on the efficiency to which data can be retrieved in meaningful ways. OLAP databases focus less on minimizing data duplication and instead denormalize relational data, albeit not completely, using concepts like [Star Schemas](https://en.wikipedia.org/wiki/Star_schema) and precomputed (aka [materialized](https://en.wikipedia.org/wiki/Materialized_view)) columns and even whole tables. 

<img src="./pagila-star-schema.jpg">

Below is a summary table that compares and contrasts the use cases, design goals, and common technologies of OLTP and OLAP databases.

<table>
<thead>
  <tr>
    <th></th>
    <th>OLTP</th>
    <th>OLAP</th>
  </tr>
</thead>
<tbody>
  <tr>
    <td>Use Cases</td>
    <td>Operational business systems like order processing, appointments, accounting and financial systems</td>
    <td>Internal / External Reporting systems, Business Intelligence, Analytics / ML</td>
  </tr>
  <tr>
    <td>Design Goals</td>
    <td>Efficient small writes (transactions), storage minimization, enforcing business rules and constraints</td>
    <td>Efficient reads and aggregations through minimizing joins, large batch writes</td>
  </tr>
  <tr>
    <td>Technologies</td>
    <td>Common DBMS we have grown to love like MS SQL Server, Oracle, PostgreSQL, MySQL</td>
    <td>Often same DBMS tech (Oracle, SQL Server, PostgreSQL) other times its more specialized Data Warehouse like Redshift, Snowflake, Teradata</td>
  </tr>
</tbody>
</table>

### Introducing the Pagila OLTP Movie Rental Database

At this point I will swiftly transition into a more practical discussion of OLTP and OLAP data storage through the use of a popular fictitous database named Pagila representing a movie rental business and designed specifically for an OLTP implementation in PostgreSQL. I will be using a modified version of the Pagila database to suit this article which you can find in [this repo here from my GitHub account](). You can find the original Pagila database schema and data in this [link to the PostgresSQL docs](https://wiki.postgresql.org/wiki/Sample_Databases). 

### Setting Up and Exploring Pagila Demo OLTP Database in AWS Cloud

The actual database I am using for these demonstrations is an AWS Aurora Postgres instance. For those interested in following along I have provided all necessary Infrastructure as Code based in Terraform and will walk through spinning up the infrastructure stack shortly. If you need to, please [download and install Terraform](https://www.terraform.io/downloads.html) if you would like to follow along.

To start I clone the repo from my GitHub account, change into the aurora-postgres directory and, initialize the terraform project to pull in the AWS provider module.

```
git clone ...
cd big-data-storage/aurora-postgres
terraform init
```

Next I create the Terraform plan and then apply it. If you are following along be cautioned that the below commands will spin up a number of AWS Cloud resources which will cost money (in the range of a few dollars) so, please be sure to follow my instructions for tearing down this infrastructure at the end of this article.

```
terraform plan -out aurora-postgres.tfplan
terraform apply "aurora-postgres.tfplan"
```

The above Terraform apply command will spit out the PostgreSQL client compliant database url which I'll use throughout this tutorial referenced as a environment variable DATABASE_URL which can be generated on unix based systems like so.

```
export DATABASE_URL=postgresql://user:password@hosturl.com:5432/dbname
```

To faciliate this article I altered the original Pagila design so that the OLTP specific tables and data will be organized into a schema named oltp. A second schema will be introduced later named olap which will organize and hold the OLAP schema and data as well. 

At this point I can load the Pagila schema file named pagila-oltp-schema.sql which can be found in the aurora-postgres directory using the [psql PostgreSQL CLI client](https://www.postgresql.org/docs/current/app-psql.html) like so.

```
psql $DATABASE_URL -f pagila-oltp-schema.sql
```

Following creation of the schema I can load it with data using another file named pagila-oltp-data.sql again within the aurora-postgres directory.

```
psql $DATABASE_URL -f pagila-oltp-data.sql
``` 

To narrow the scope of this discussion I want to focus in on just a subset of the Pagila OLTP tables shown in the below image.

<img src="./oltp-pagila.jpg">

Notice the infamous Lumbergh from Office Space who is once again requesting those TPS reports for Weekly revenue totals and by movie rating as well as average daily revenue. All kiding aside here those are some very reasonable and realistic requests to expect as a data analyst, developer, or whatever xyz role you can come up with and are good examples to highlight how painful it can be to pull data out of such an OLTP database.

First I will start with providing a query that can be used to pull the weekly revenue by rating as shown below.

```
-- oltp-weekly-rev-UNION.sql

WITH weekly_payments AS (
  SELECT amount, 
      EXTRACT(WEEK FROM payment_date) AS _week,
      rating
  FROM payment p 
      JOIN rental r ON p.rental_id = r.rental_id
      JOIN inventory i ON r.inventory_id = i.inventory_id
      JOIN film f ON i.film_id = f.film_id
  ORDER BY _week, rating, amount
)
SELECT wp._week, wp.rating, SUM(wp.amount) AS sales
FROM weekly_payments wp
GROUP BY wp._week, wp.rating

UNION ALL

SELECT wp._week, NULL, SUM(wp.amount) AS sales
FROM weekly_payments wp
GROUP BY wp._week

UNION ALL

SELECT NULL, NULL, SUM(wp.amount) AS sales
FROM weekly_payments wp

ORDER BY _week, rating
```

Although far from the worst query I've seen it is still a pretty formidable chunk of SQL and one that is likely to be unfriendly to a database under moderate to heavy load. You can find this query in the aurora-postgres directory within a file named oltp-weekly-rev-UNION.sql

To be fair to the good folks who build PostgreSQL I should mention that they do provide a handy function named CUBE that makes this type of query much simpler which I've shown below.

```
-- oltp-weekly-rev-CUBE.sql

WITH weekly_payments AS (
  SELECT amount, 
      EXTRACT(WEEK FROM payment_date) AS _week,
      rating
  FROM payment p 
      JOIN rental r ON p.rental_id = r.rental_id
      JOIN inventory i ON r.inventory_id = i.inventory_id
      JOIN film f ON i.film_id = f.film_id
  ORDER BY _week, rating, amount
)
SELECT wp._week, wp.rating, SUM(wp.amount) AS sales
FROM weekly_payments wp
GROUP BY CUBE (wp._week, wp.rating)
ORDER BY wp._week, wp.rating, sales;
```

Next up on the TPS report requirements is the Daily Average Revenue for which you can find the corresponding SQL below.

```
-- oltp-daily.sql

WITH weekly_payments AS (
  SELECT amount, 
      EXTRACT(ISODOW FROM payment_date) AS dow,
      rating
  FROM payment p 
      JOIN rental r ON p.rental_id = r.rental_id
      JOIN inventory i ON r.inventory_id = i.inventory_id
      JOIN film f ON i.film_id = f.film_id
  ORDER BY dow, rating, amount
)
SELECT dow, SUM(wp.amount) AS sales
FROM weekly_payments wp
GROUP BY dow
ORDER BY dow;
```

Again, not terrible but does lay a solid foundation for comparing to a better world within a OLAP database design to be discussed in the next section.

### Venturing into Data Engineering: Designing the OLAP DB then Performing Extract, Transform, and Load

The goal of the remainder of this article will be to design, build, and load a second schema named olap which will contain a Star Schema to query for the revenue reporting requirements as well as a materialize view which is simply a reporting table to further simplify querying the data for these reports.

Below is the Star Schema that will be built. As you can see it is collapsed down to just 5 tables, which some say resemble a Star, with what is known as a fact table in the center representing video rental sales and four dimensional (aka relational) tables linked to and surrounding the fact table. The motivation for using a Star Schema is they generally result in simplier more performant queries and they work well for generating [OLAP cubes](https://en.wikipedia.org/wiki/OLAP_cube) which faciliate aggregating and drilling into aggregates across dimensions.

<img src="./pagila-star-schema.jpg">

The Data Definition Language (DDL) SQL for creating the Star Schema is shown below.

```
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
```

The above DDL for the Star Schema tables is pretty straight forward but, there is one thing worth noting here. There are no foreign keys explicitly applied to enforce referential integrity among the dimensional tables and the fact table. This is a fairly common practice among some in the business of designing OLAP databases as described in this [Stack Overflow Post](https://stackoverflow.com/questions/2690818/is-it-good-practice-to-have-foreign-keys-in-a-datawarehouse-relationships). Often times foreign keys and other constraints are depicted in a ERD diagram for conveying business rules but omitted in the physical schema or, in the case of many true Data Warehouse providers, ignored by the actual database engine as is the case in Redshift and Snowflake. From my perspective the primary reason for omitting the Foreign Key constraints are to facilitate faster writing of data to tables and to make certain ETL/ELT tasks easier when it is necessary to load a child table before a parent one.

I can create the OLAP Star Schema using the file pagila-olap-star-schema.sql within the aurora-postgres directory like so.

```
psql $DATABASE_URL -f pagila-olap-star-schema.sql
```

Ok so now that the OLAP star shema has been built the next logical step is to get the data into it. This is where the popular Data Engineering concepts of Extract, Transform, and Load (ETL) along with the often blurred counter part Extract, Load, and Transform (ELT). The key here is that I must extract the data from the source OLTP tables, transform the data into a format that is consistent with the OLAP target tables and finish by loading this Transformed data into the Star Schema tables.

For this ETL step I have defined a stored procedure which is actually created in the previously executed pagila-olap-star-schema.sql file and shown below.

```
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
```

A few note worthy points to mention here.

First, the date_dim table is actually being built from a generated seqence of DATE objects being operated on by various date related functions to make useful date fields.

Second, the dimension tables are built using a common INSERT INTO ... SELECT FROM ... pattern along with a handy Upsert pattern. This allows for subsequent reloads of the data over time which will add new records as they become available (for example new customers) as well as update any existing records that have had updates in the source OLTP tables. This approach should should be weighed against the next approach I use which is called a table swap and is handy for minimizing table locking but, since dimension tables are generally small (usually much much smaller than fact tables) this approach is commonly used.

Lastly, the fact table loading is a bit more complicated in comparison to the dimensional tables because they are usually much larger and thus take longer to load and may be locked for unacceptably long times. Therefore, I create a temporary staging table to load into first then swap with the original production fact table via a rename from production to old then staging to production before finally dropping the old production table.

I can run this new stored procedure within the psql shell as shown below to populate the Star Schema.

```
$ psql $DATABASE_URL
psql (11.10, server 11.9)

pagila=> CALL olap.run_elt();
```

### Realizing the Fruits of our Labor

Finally the time has come to reap the benefits of fruits of our labor from building the OLAP database and experience better queries.

I will start by showing the new Weekly Revenue query against the Star Schema.

```
-- olap-weekly-rev.sql

SELECT week_of_year, rating, SUM(amount) AS sales
FROM olap.sales_facts s
  JOIN olap.date_dim d ON s.date_id = d.date_id
  JOIN olap.film_dim f ON s.film_id = f.film_id
GROUP BY CUBE(week_of_year, rating)
ORDER BY week_of_year, rating, sales;
```

As you can see there is no more need for a Common Table Expression and there are fewer joins. I've also used the OLAP CUBE function from the begining this time.

The Daily Average Revenue is also considerably trimmed down and more palpable.

```
-- olap-daily.sql

SELECT day_of_week, AVG(amount) AS sales
FROM olap.sales_facts s
  JOIN olap.date_dim d ON s.date_id = d.date_id
GROUP BY CUBE(day_of_week)
ORDER BY day_of_week;
```

### Building Reporting Tables with Materialized Views

Ok so I took a good bit of time explaining what the Star Schema is and how they are useful for performing large aggregating queries. However, they often still require multiple joins to aggregate across dimensions and if a particular query is hitting enough of the fact table and/or ran often enough your database will still experience performance degredation. For example, lets say the weekly sales and average daily sales data is feed into a BI tool or reporting dashboard that is frequently viewed by many people in the organization and you are getting reports that its taking longer and longer to load. Then what do you do?

Another common solution is to create a reporting table, sometimes referred to as a [materialized view](https://www.postgresqltutorial.com/postgresql-materialized-views/), which stores there results of a burdensome query and simply refreshes itself only as often is as necessary.

Below are SQL statements which create materialized views for the two queries that I've been working with in this article and generated from data in the Star Schema.

The Weekly Revenue Materialized View.

```
-- olap-materialized-weekly-rev.sql

CREATE MATERIALIZED VIEW olap.weekly_rating_sales
AS 
  SELECT week_of_year, rating, SUM(amount) AS sales
  FROM olap.sales_facts s
    JOIN olap.date_dim d ON s.date_id = d.date_id
    JOIN olap.film_dim f ON s.film_id = f.film_id
  GROUP BY CUBE(week_of_year, rating)
  ORDER BY week_of_year, rating, sales
WITH DATA;
```

Clearly querying this is now a dead simple task.

```
SELECT * FROM olap.weekly_rating_sales;
```

The Daily Average Revenue Materialized View.

```
-- olap-materialized-daily.sql

CREATE MATERIALIZED VIEW olap.daily_average_sales
AS 
  SELECT day_of_week, AVG(amount) AS sales
  FROM olap.sales_facts s
    JOIN olap.date_dim d ON s.date_id = d.date_id
  GROUP BY CUBE(day_of_week)
  ORDER BY day_of_week
WITH DATA;
```

Now the queries are as simple as they can get and the database benefits from having the underlying complex queries being ran in a time controlled manner.

### Conclusion



 

 

