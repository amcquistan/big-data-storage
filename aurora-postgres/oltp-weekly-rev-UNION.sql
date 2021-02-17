
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