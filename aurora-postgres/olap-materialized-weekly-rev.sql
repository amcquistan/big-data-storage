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
