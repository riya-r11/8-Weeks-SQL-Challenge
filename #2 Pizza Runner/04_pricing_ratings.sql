-- Pizza Runner - SQL Server

use pizza_runner;


-- D. Pricing and Ratings


-- D1. If a Meat Lovers pizza costs $12 and Vegetarian costs $10 and there were no charges for changes - how much money has Pizza Runner made so far if there are no delivery fees?

SELECT 
	SUM(CASE 
			WHEN CAST(pizza_name AS VARCHAR(MAX))='Meatlovers' THEN 12
			WHEN CAST(pizza_name AS VARCHAR(MAX))='Vegetarian' THEN 10
			ELSE 0
		END) AS Total_revenue
		
FROM customer_orders o
JOIN pizza_names p
	ON o.pizza_id = p.pizza_id
JOIN runner_orders ro
    ON o.order_id = ro.order_id
WHERE ro.pickup_time != 'null'; -- filter delivered pizzas

-- D2. What if there was an additional $1 charge for any pizza extras?
--     Add cheese is $1 extra
SELECT 
	SUM(CASE 
			WHEN CAST(pizza_name AS VARCHAR(MAX))='Meatlovers' THEN 12
			WHEN CAST(pizza_name AS VARCHAR(MAX))='Vegetarian' THEN 10
			ELSE 0
		END) 
	+
    SUM(CASE
            WHEN o.extras IS NOT NULL
                 AND o.extras NOT IN ('null', '')
            THEN
                (LEN(CAST(o.extras AS VARCHAR(100)))
                 - LEN(REPLACE(CAST(o.extras AS VARCHAR(100)), ',', '')) + 1)
            ELSE 0
        END
    ) AS Total_revenue
FROM customer_orders o
JOIN pizza_names p
	ON o.pizza_id = p.pizza_id
JOIN runner_orders ro
    ON o.order_id = ro.order_id
WHERE ro.pickup_time != 'null'; -- filter delivered pizzas


-- D3. The Pizza Runner team now wants to add an additional ratings system that allows customers to rate their runner, how would you design an additional table for this new dataset 
-- - generate a schema for this new table and insert your own data for ratings for each successful customer order between 1 to 5.
CREATE TABLE runner_ratings
(
    order_id INT PRIMARY KEY,
    customer_id INT NOT NULL,
    runner_id INT NOT NULL,
    rating INT NOT NULL CHECK (rating BETWEEN 1 AND 5),

    --FOREIGN KEY (order_id) REFERENCES runner_orders(order_id)
);

-- INSERT query
INSERT INTO runner_ratings
    (order_id, customer_id, runner_id, rating)
SELECT
    successful_orders.order_id,
    successful_orders.customer_id,
    successful_orders.runner_id,
    ((ROW_NUMBER() OVER (ORDER BY successful_orders.order_id) - 1) % 5) + 1
        AS rating
FROM
(
    SELECT DISTINCT
        ro.order_id,
        co.customer_id,
        ro.runner_id
    FROM runner_orders ro
    JOIN customer_orders co
        ON ro.order_id = co.order_id
    WHERE ro.pickup_time != 'null'
) AS successful_orders;




-- D4. Using your newly generated table - can you join all of the information together to form a table which has the following information for successful deliveries?
-- - customer_id
-- - order_id
-- - runner_id
-- - rating
-- - order_time
-- - pickup_time
-- - Time between order and pickup
-- - Delivery duration
-- - Average speed
-- - Total number of pizzas

-- Data clean : duration, distance for delivered pizzas
WITH cte_delivery_details AS
(
	SELECT
        ro.order_id,
        ro.runner_id,
		pickup_time,
        TRY_CAST(
            REPLACE(REPLACE(CAST(ro.distance AS VARCHAR(50)), 'km', ''), ' ', '')
            AS FLOAT
        ) AS distance_km,
        TRY_CAST(
            REPLACE(
                REPLACE(
                    REPLACE(
                        REPLACE(CAST(ro.duration AS VARCHAR(50)),
                            'minutes', ''),
                        'minute', ''),
                    'mins', ''),
                ' ', ''
            ) AS FLOAT
        ) AS duration_minutes
    FROM runner_orders ro
    WHERE ro.pickup_time != 'null'
)

-- Calculate all columns except Total_number_of_pizzas
,cte_rating AS
(
	SELECT o.customer_id, o.order_id, o.pizza_id, rr.runner_id, rr.rating, o.order_time, d.pickup_time,
			DATEDIFF(minute, o.order_time, d.pickup_time) AS Time_between_order_and_pickup_mins,
			d.duration_minutes AS Delivery_duration_mins,
			ROUND(d.distance_km / (d.duration_minutes/60.0), 2) AS Average_speed
	FROM customer_orders o
	JOIN runner_ratings rr
		ON o.order_id=rr.order_id AND o.customer_id=rr.customer_id
	JOIN cte_delivery_details d
		ON rr.order_id=d.order_id AND rr.runner_id=d.runner_id
)

-- Count no. of pizzas
SELECT customer_id, order_id, runner_id, rating, order_time, pickup_time, Time_between_order_and_pickup_mins, Delivery_duration_mins, Average_speed,
		COUNT(pizza_id) AS Total_number_of_pizzas
FROM cte_rating
GROUP BY customer_id, order_id, runner_id, rating, order_time, pickup_time, Time_between_order_and_pickup_mins, Delivery_duration_mins, Average_speed;




-- D5. If a Meat Lovers pizza was $12 and Vegetarian $10 fixed prices with no cost for extras and each runner is paid $0.30 per kilometre traveled - how much money does Pizza Runner have left over after these deliveries?

-- Data Clean : 'distance' in runner_orders table
WITH cte_delivery_details AS
(
    SELECT
        order_id,
        runner_id,
		pickup_time,
        TRY_CAST(
            REPLACE(REPLACE(CAST(distance AS VARCHAR(50)), 'km', ''), ' ', '')
            AS FLOAT
        ) AS distance_km
    FROM runner_orders 
    WHERE pickup_time != 'null'
)
-- pizza price - runner payment = Total revenue
SELECT 
	SUM(CASE 
			WHEN CAST(pizza_name AS VARCHAR(MAX))='Meatlovers' THEN 12
			WHEN CAST(pizza_name AS VARCHAR(MAX))='Vegetarian' THEN 10
			ELSE 0.0
		END)
	- SUM(distance_km*0.3) AS Total_revenue
FROM cte_delivery_details d
JOIN customer_orders o
	ON o.order_id = d.order_id
JOIN pizza_names p
	ON p.pizza_id = o.pizza_id;

