-- olap-materialized-daily.sql

CREATE MATERIALIZED VIEW olap.daily_average_sales
AS 
  SELECT day_of_week, AVG(amount) AS sales
  FROM olap.sales_facts s
    JOIN olap.date_dim d ON s.date_id = d.date_id
  GROUP BY CUBE(day_of_week)
  ORDER BY day_of_week
WITH DATA;
