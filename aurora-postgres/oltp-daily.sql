-- OLTP-Daily.sql

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
