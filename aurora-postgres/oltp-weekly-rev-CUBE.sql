-- OLTP-Weekly-Ref-CUBE.sql

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