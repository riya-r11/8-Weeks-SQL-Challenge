-- Pizza Runner - SQL Server

use pizza_runner;


--   B. Runner and Customer Experience


-- B1. How many runners signed up for each 1 week period? (i.e. week starts 2021-01-01)
SELECT
    DATEDIFF(DAY, '2021-01-01', registration_date) / 7 + 1 AS week_num,
    COUNT(*) AS runner_count
FROM runners
GROUP BY DATEDIFF(DAY, '2021-01-01', registration_date) / 7 + 1
ORDER BY week_num;


-- B2. What was the average time in minutes it took for each runner to arrive at the Pizza Runner HQ to pickup the order?
-- (find pickup duration)
SELECT
    ro.runner_id,
    AVG(
        DATEDIFF(MINUTE, co.order_time, ro.pickup_time)
    ) AS avg_pickup_time
FROM runner_orders ro
JOIN customer_orders co
    ON ro.order_id = co.order_id
WHERE ro.pickup_time != 'null'
GROUP BY ro.runner_id;


-- B3. Is there any relationship between the number of pizzas and how long the order takes to prepare?
-- (find preparation time)
WITH pizza_count AS
(
    SELECT
        order_id,
        COUNT(*) AS pizza_count,
        MIN(order_time) AS order_time
    FROM customer_orders
    GROUP BY order_id
)
SELECT
    pc.order_id,
    pc.pizza_count,
    DATEDIFF(
        MINUTE,
        pc.order_time,
        ro.pickup_time
    ) AS preparation_time
FROM pizza_count pc
JOIN runner_orders ro
    ON pc.order_id = ro.order_id
WHERE ro.pickup_time != 'null';



-- B4. What was the average distance travelled for each customer?
SELECT
    co.customer_id,
    AVG(
        CAST(
            REPLACE(CAST(ro.distance AS VARCHAR(50)), 'km', '')
            AS FLOAT
        )
    ) AS avg_distance_travelled
FROM customer_orders co
JOIN runner_orders ro
    ON co.order_id = ro.order_id
WHERE ro.pickup_time != 'null'
GROUP BY co.customer_id;

/*
 OR

    AVG(
        TRY_CAST(
            REPLACE(
                REPLACE(CAST(ro.distance AS VARCHAR(50)), 'km', ''),
                ' ', ''
            ) AS FLOAT
        )
    ) AS avg_distance_travelled
*/



-- B5. What was the difference between the longest and shortest delivery times for all orders?
SELECT
		MIN(CAST(LEFT(duration,2) AS int)) AS shortest_delivery_time,
		MAX(CAST(LEFT(duration,2) AS int)) AS longest_delivery_time,
		MAX(CAST(LEFT(duration,2) AS int)) - MIN(CAST(LEFT(duration,2) AS int)) AS diff
FROM runner_orders
WHERE pickup_time!='null';

-- OR

WITH cleaned_data AS
(
    SELECT
        TRY_CAST(
            REPLACE(
                REPLACE(
                    REPLACE(
                        REPLACE(CAST(duration AS VARCHAR(50)),
                            'minutes', ''),
                        'minute', ''),
                    'mins', ''),
                ' ', ''
            ) AS FLOAT
        ) AS duration_minutes
    FROM runner_orders
    WHERE pickup_time != 'null'
)
SELECT
    MIN(duration_minutes) AS shortest_delivery_time,
    MAX(duration_minutes) AS longest_delivery_time,
    MAX(duration_minutes) - MIN(duration_minutes) AS difference
FROM cleaned_data;



-- B6. What was the average speed for each runner for each delivery and do you notice any trend for these values?

WITH cleaned_data AS
(
    SELECT
        runner_id,
        order_id,

        TRY_CAST(
            REPLACE(
                REPLACE(
                    CAST(distance AS VARCHAR(50)),
                    'km', ''
                ),
                ' ', ''
            ) AS FLOAT
        ) AS distance_km,

        TRY_CAST(
            REPLACE(
                REPLACE(
                    REPLACE(
                        REPLACE(
                            CAST(duration AS VARCHAR(50)),
                            'minutes', ''
                        ),
                        'minute', ''
                    ),
                    'mins', ''
                ),
                ' ', ''
            ) AS FLOAT
        ) AS duration_minutes

    FROM runner_orders
    WHERE pickup_time != 'null'
)

SELECT
    runner_id,
    order_id,
    ROUND(
        (distance_km / duration_minutes) * 60,
        2
    ) AS avg_speed_kmph
FROM cleaned_data
ORDER BY runner_id, order_id;




-- B7. What is the successful delivery percentage for each runner?
WITH cte_total_orders AS
(SELECT runner_id, count(*) as total_orders
FROM runner_orders
GROUP BY runner_id
),
cte_successful_deliveries AS
(SELECT runner_id, count(*) as successful_delivery
FROM runner_orders
WHERE pickup_time!='null'
GROUP BY runner_id
)
SELECT ct.runner_id, 
		successful_delivery*100.0/total_orders AS successful_delivery_perc
FROM cte_total_orders ct
LEFT JOIN cte_successful_deliveries cs
	ON ct.runner_id = cs.runner_id;

-- OR

SELECT
    runner_id,
    SUM(
        CASE
            WHEN pickup_time != 'null' THEN 1
            ELSE 0
        END
    ) * 100.0 / COUNT(*) AS successful_delivery_perc
FROM runner_orders
GROUP BY runner_id;

