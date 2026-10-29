-- Pizza Runner - SQL Server

use pizza_runner;

--   A. Pizza Metrics


-- Q1. How many pizzas were ordered?
SELECT COUNT(*) AS pizzas_ordercount 
FROM customer_orders;

-- Q2. How many unique customer orders were made?
SELECT COUNT(DISTINCT order_id) AS unique_order_count 
FROM customer_orders;

-- Q3. How many successful orders were delivered by each runner?
SELECT runner_id, 
		COUNT(*) AS successful_orders
FROM runner_orders
WHERE pickup_time != 'null'
GROUP BY runner_id;

-- Q4. How many of each type of pizza was delivered?
SELECT
    CAST(pn.pizza_name AS VARCHAR(50)) AS pizza_name,
    COUNT(*) AS deliver_count
FROM runner_orders ro
JOIN customer_orders co
    ON ro.order_id = co.order_id
JOIN pizza_names pn
    ON co.pizza_id = pn.pizza_id
WHERE ro.pickup_time != 'null'
GROUP BY CAST(pn.pizza_name AS VARCHAR(50));
-- CAST (if Error occurred)


-- Q5. How many Vegetarian and Meatlovers were ordered by each customer?
SELECT
    customer_id,
    CAST(pn.pizza_name AS VARCHAR(50)) AS pizza_name,
    COUNT(*) AS order_count
FROM customer_orders co
JOIN pizza_names pn
    ON co.pizza_id = pn.pizza_id
GROUP BY
    co.customer_id,
    CAST(pn.pizza_name AS VARCHAR(50))
ORDER BY customer_id;


-- Q6. What was the maximum number of pizzas delivered in a single order?
WITH cte_single_order_delivery_count AS
(
	SELECT co.order_id, count(pizza_id) AS delivery_count
	FROM runner_orders ro
	JOIN customer_orders co
		ON ro.order_id = co.order_id
	WHERE pickup_time != 'null'
	GROUP BY co.order_id
)
SELECT max(delivery_count) AS max_pizzas_delivered
FROM cte_single_order_delivery_count;



-- Q7. For each customer, how many delivered pizzas had at least 1 change and how many had no changes?
SELECT
    co.customer_id,

    SUM(
        CASE
            WHEN co.exclusions NOT IN ('null', '')
              OR co.extras NOT IN ('null', '')
            THEN 1
            ELSE 0
        END
    ) AS pizzas_with_changes,

    SUM(
        CASE
            WHEN co.exclusions IN ('null', '')
             AND co.extras IN ('null', '')
            THEN 1
            ELSE 0
        END
    ) AS pizzas_without_changes

FROM customer_orders co
JOIN runner_orders ro
    ON co.order_id = ro.order_id
WHERE ro.pickup_time != 'null'
GROUP BY co.customer_id;



-- Q8. How many pizzas were delivered that had both exclusions and extras?
SELECT COUNT(*) AS both_changes_count
FROM customer_orders co
JOIN runner_orders ro
    ON co.order_id = ro.order_id
WHERE ro.pickup_time != 'null'
  AND co.exclusions NOT IN ('null', '')
  AND co.extras NOT IN ('null', '');


-- Q9. What was the total volume of pizzas ordered for each hour of the day?
SELECT DATEPART(HOUR, order_time) AS hour_of_day,
		COUNT(*) as pizza_order_count
FROM customer_orders
GROUP BY DATEPART(HOUR, order_time)
ORDER BY hour_of_day;


-- Q10. What was the volume of orders for each day of the week?
SELECT DATENAME(WEEKDAY, order_time) AS day_of_week,
		COUNT(*) as pizza_order_count
FROM customer_orders
GROUP BY DATENAME(WEEKDAY, order_time), 
		DATEPART(WEEKDAY, order_time)
ORDER BY DATEPART(WEEKDAY, order_time);

