-- Pizza Runner - SQL Server

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







-- C. Ingredient Optimisation
-- C1. What are the standard ingredients for each pizza?
SELECT
    CAST(pn.pizza_name AS VARCHAR(50)) AS pizza_name,
    STRING_AGG(CAST(pt.topping_name AS VARCHAR(50)), ', ') AS standard_ingredients   FROM pizza_recipes pr
JOIN pizza_names pn
    ON pr.pizza_id = pn.pizza_id
CROSS APPLY STRING_SPLIT(CAST(pr.toppings AS VARCHAR(50)), ',') t
JOIN pizza_toppings pt
	ON pt.topping_id = CAST(t.value AS INT)
GROUP BY CAST(pn.pizza_name AS VARCHAR(50));
	


-- C2. What was the most commonly added extra?
SELECT TOP 1
    CAST(pt.topping_name AS VARCHAR(50)) AS extra_name,
    COUNT(*) AS extra_count
FROM customer_orders co
CROSS APPLY STRING_SPLIT(CAST(co.extras AS VARCHAR(50)), ',') e
JOIN pizza_toppings pt
    ON pt.topping_id = CAST(e.value AS INT)
WHERE co.extras NOT IN ('null', '')
GROUP BY CAST(pt.topping_name AS VARCHAR(50))
ORDER BY extra_count DESC;


-- C3. What was the most common exclusion?
SELECT TOP 1
    CAST(pt.topping_name AS VARCHAR(50)) AS exclusion_name,
    COUNT(*) AS exclusion_count
FROM customer_orders co
CROSS APPLY STRING_SPLIT(CAST(co.exclusions AS VARCHAR(50)), ',') e
JOIN pizza_toppings pt
    ON pt.topping_id = CAST(e.value AS INT)
WHERE co.exclusions NOT IN ('null', '')
GROUP BY CAST(pt.topping_name AS VARCHAR(50))
ORDER BY exclusion_count DESC;




-- C4. Generate an order item for each record in the customers_orders table in the format of one of the following:
-- 		Meat Lovers
-- 		Meat Lovers - Exclude Beef
-- 		Meat Lovers - Extra Bacon
-- 		Meat Lovers - Exclude Cheese, Bacon - Extra Mushroom, Peppers

-- SHorter version
-- step 1 : remove duplicate records from customer_orders table. 
WITH cte_order_records AS
(
	SELECT order_id, customer_id, pizza_id, exclusions, extras, order_time,
			ROW_NUMBER() OVER(PARTITION BY order_id, customer_id, pizza_id, exclusions, extras, order_time ORDER BY order_id) AS row_id
	FROM customer_orders
	-- row_id=1 are unique records
),

-- step 2 : exclude list aggregated
cte_exclude AS
(
	SELECT c.order_id, c.pizza_id,
		   CONCAT(' - Exclude ', STRING_AGG(CAST(pt.topping_name AS VARCHAR(MAX)), ', ')) AS exclusion_names  
	FROM cte_order_records c
	CROSS APPLY STRING_SPLIT(c.exclusions, ',') s
	LEFT JOIN pizza_toppings pt
		ON TRY_CAST(s.value AS INT) = pt.topping_id
	WHERE c.row_id=1 AND c.exclusions NOT IN ('null', '')
	GROUP BY c.order_id, c.pizza_id
-- SELECT / GROUP BY c.order_id, c.pizza_id : solved 'Exclude Cheese Cheese' problem
),

-- step 3 : extra list aggregated
cte_extra AS
(
	SELECT c.order_id, c.pizza_id,
		CONCAT(' - Extra ', STRING_AGG(CAST(pt.topping_name AS VARCHAR(MAX)), ', ')) AS extras_names     
	FROM cte_order_records c
	CROSS APPLY STRING_SPLIT(c.extras, ',') t
	LEFT JOIN pizza_toppings pt
		ON TRY_CAST(t.value AS INT) = pt.topping_id
	WHERE c.row_id=1 AND c.extras NOT IN ('null', '')
	GROUP BY c.order_id, c.pizza_id
)

-- step 4 : pizza_name + exclude + extras for each record in customer_orders table
SELECT c.order_id, c.customer_id, c.pizza_id, c.exclusions, c.extras, c.order_time,
		CONCAT(pn.pizza_name, exclusion_names, extras_names) AS order_item
FROM cte_order_records c
LEFT JOIN pizza_names pn
		ON c.pizza_id = pn.pizza_id
LEFT JOIN cte_exclude exclude
		ON c.order_id = exclude.order_id
LEFT JOIN cte_extra extra
		ON c.order_id = extra.order_id
WHERE c.row_id=1;


--  OR
-- Longer version
WITH cte_exclude_list AS
(
	-- exclusions list non-repeating
	SELECT DISTINCT o.order_id, o.pizza_id,
		   CAST(pt.topping_name as varchar(100)) AS topping_name
	FROM customer_orders o
	CROSS APPLY STRING_SPLIT(o.exclusions, ',') s
	LEFT JOIN pizza_toppings pt
		ON TRY_CAST(s.value AS INT) = pt.topping_id
	WHERE o.exclusions NOT IN ('null', '')
	
),
cte_exclusion AS
(
	-- aggregating exclusion items together
	SELECT order_id, pizza_id,
		CONCAT(' - Exclude ', STRING_AGG(CAST(topping_name AS VARCHAR(MAX)), ', ')) AS exclusion_names
	FROM cte_exclude_list
	GROUP BY order_id, pizza_id
),
cte_extras_list AS
(
	-- extras list non-repeating
	SELECT DISTINCT o.order_id, o.pizza_id,
		   CAST(pt.topping_name as varchar(100)) AS topping_name --
	FROM customer_orders o
	CROSS APPLY STRING_SPLIT(o.extras, ',') s
	LEFT JOIN pizza_toppings pt
		ON TRY_CAST(s.value AS INT) = pt.topping_id
	WHERE o.extras NOT IN ('null', '')
),
cte_extras AS
(
	-- extras aggregated
	SELECT order_id, pizza_id,
		CONCAT(' - Extra ', STRING_AGG(CAST(topping_name AS VARCHAR(MAX)), ', ')) AS extras_names
	FROM cte_extras_list
	GROUP BY order_id, pizza_id
)

-- aggregate pizza name, exclusion name, extras names
SELECT o.*, 
	CASE WHEN exclusion_names=null AND extras_names=NULL THEN p.pizza_name
		WHEN exclusion_names=NULL THEN CONCAT(p.pizza_name, extras_names)
		WHEN extras_names=NULL THEN CONCAT(p.pizza_name, exclusion_names)
		ELSE CONCAT(p.pizza_name, exclusion_names, extras_names)
	END AS order_item
FROM customer_orders o
LEFT JOIN pizza_names p
	ON o.pizza_id = p.pizza_id
LEFT JOIN cte_exclusion e1
	ON o.order_id=e1.order_id AND o.pizza_id=e1.pizza_id
LEFT JOIN cte_extras e2
	ON o.order_id=e2.order_id AND o.pizza_id=e2.pizza_id








-- C5. Generate an alphabetically ordered comma separated ingredient list for each pizza order from the customer_orders table and add a 2x in front of any relevant ingredients
-- 		For example: "Meat Lovers: 2xBacon, Beef, ... , Salami"

-- step 1 : remove duplicate records from customer_orders table. 
WITH cte_order_records AS
(
	SELECT order_id, customer_id, pizza_id, exclusions, extras, order_time,
			ROW_NUMBER() OVER(PARTITION BY order_id, customer_id, pizza_id, exclusions, extras, order_time ORDER BY order_id) AS row_id
	FROM customer_orders
	-- row_id=1 are unique records
),

-- step 2 : separate column 'topping_id' of all ingredients (standard + extra - exlusions) for each unique record.
cte_all_ingredients AS
(
	-- Standard Ingredients
	SELECT c.order_id, c.customer_id, c.pizza_id, c.exclusions, c.extras, c.order_time,
			pt.topping_id  
	FROM cte_order_records c
	LEFT JOIN pizza_recipes r
		ON c.pizza_id = r.pizza_id
	CROSS APPLY STRING_SPLIT(CAST(r.toppings AS VARCHAR(MAX)), ',') s
	LEFT JOIN pizza_toppings pt
		ON TRY_CAST(s.value AS INT) = pt.topping_id
	WHERE c.row_id=1 AND 
	-- Exclude exclusions
	NOT EXISTS
    (
        SELECT 1
        FROM STRING_SPLIT(c.exclusions, ',') e
        WHERE TRY_CAST(e.value AS INT) = pt.topping_id
    )

	UNION ALL

	-- Extra ingredients
	SELECT c.order_id, c.customer_id, c.pizza_id, c.exclusions, c.extras, c.order_time,
			pt.topping_id   
	FROM cte_order_records c
	CROSS APPLY STRING_SPLIT(CAST(c.extras AS VARCHAR(MAX)), ',') s
	LEFT JOIN pizza_toppings pt
		ON TRY_CAST(s.value AS INT) = pt.topping_id
	WHERE c.row_id=1 AND c.extras NOT IN ('null', '')
),

-- step 3 : Columns: 'topping_name' , their 'count'. Eg. “Bacon” , “2”
cte_ingredient_count AS
(
	SELECT i.order_id, i.customer_id, i.pizza_id, i.exclusions, i.extras, i.order_time, CAST(pt.topping_name AS VARCHAR(MAX)) AS topping_name,
			COUNT(CAST(pt.topping_name AS VARCHAR(MAX))) AS ingredient_count
	FROM cte_all_ingredients i
	LEFT JOIN pizza_toppings pt
		ON i.topping_id = pt.topping_id
	GROUP BY i.order_id, i.customer_id, i.pizza_id, i.exclusions, i.extras, i.order_time, CAST(pt.topping_name AS VARCHAR(MAX))
)

-- step 4 : Concatenate (2x + topping_name) if required. Eg. “2xBacon”
,cte_2x AS
(
	SELECT order_id, customer_id, pizza_id, exclusions, extras, order_time, 
			CASE WHEN ingredient_count>1 THEN CONCAT(ingredient_count,'x',topping_name)
					ELSE topping_name
			END AS ingredient
	FROM cte_ingredient_count
)			


-- step 5 : aggregate ingredients. Eg. “2xBacon, BBQ Sauce, Beef, Cheese, Chicken, Mushrooms, Pepperoni, Salami”
, cte_ingredient_aggregate AS
(
	SELECT order_id, customer_id, pizza_id, exclusions, extras, order_time, 
			STRING_AGG(ingredient, ', ') AS ingredient_name
	FROM cte_2x
	GROUP BY order_id, customer_id, pizza_id, exclusions, extras, order_time 
)


-- step 6 : pizza_name + ingredients for each record in customer_orders table. Eg. “Meatlovers : 2xBacon, BBQ Sauce, Beef, Cheese, Chicken, Mushrooms, Pepperoni, Salami”
SELECT o.order_id, o.customer_id, o.pizza_id, o.exclusions, o.extras, o.order_time,
		 CONCAT(pizza_name, ' : ', i.ingredient_name) AS ingredient_names
FROM customer_orders o
LEFT JOIN cte_ingredient_aggregate i
	ON o.order_id=i.order_id AND o.pizza_id=i.pizza_id AND o.exclusions=i.exclusions AND ISNULL(o.extras,'null')=ISNULL(i.extras,'null')
LEFT JOIN pizza_names pn
	ON o.pizza_id=pn.pizza_id

-- To improve in query : Data Cleaning - replace null/NULL in columns with ''





-- C6. What is the total quantity of each ingredient used in all delivered pizzas sorted by most frequent first?
-- STEP 1 : delivered orders
WITH cte_delivered_orders AS
(
	SELECT o.*
	FROM customer_orders o
	JOIN runner_orders ro
		ON o.order_id=ro.order_id
	WHERE pickup_time!='null'
)

-- step 2 : separate column 'topping_id' of all ingredients (standard + extra - exlusions) for each unique record.
,cte_all_ingredients AS
(
	-- Standard Ingredients
	SELECT c.order_id, c.customer_id, c.pizza_id, c.exclusions, c.extras, c.order_time,
			pt.topping_id  
	FROM cte_delivered_orders c
	LEFT JOIN pizza_recipes r
		ON c.pizza_id = r.pizza_id
	CROSS APPLY STRING_SPLIT(CAST(r.toppings AS VARCHAR(MAX)), ',') s
	LEFT JOIN pizza_toppings pt
		ON TRY_CAST(s.value AS INT) = pt.topping_id 
	-- Exclude exclusions
	WHERE NOT EXISTS
    (
        SELECT 1
        FROM STRING_SPLIT(c.exclusions, ',') e
        WHERE TRY_CAST(e.value AS INT) = pt.topping_id
    )

	UNION ALL

	-- Extra ingredients
	SELECT c.order_id, c.customer_id, c.pizza_id, c.exclusions, c.extras, c.order_time,
			pt.topping_id   
	FROM cte_delivered_orders c
	CROSS APPLY STRING_SPLIT(CAST(c.extras AS VARCHAR(MAX)), ',') s
	LEFT JOIN pizza_toppings pt
		ON TRY_CAST(s.value AS INT) = pt.topping_id
	WHERE c.extras NOT IN ('null', '')
)

-- step 3 : Columns: 'topping_name' , their 'count'. Eg. “Bacon” , “2”
SELECT CAST(pt.topping_name AS VARCHAR(MAX)) AS topping_name,
		COUNT(CAST(pt.topping_name AS VARCHAR(MAX))) AS ingredient_count
FROM cte_all_ingredients i
LEFT JOIN pizza_toppings pt
	ON i.topping_id = pt.topping_id
GROUP BY CAST(pt.topping_name AS VARCHAR(MAX))
ORDER BY ingredient_count DESC, topping_name;





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



-- E. Bonus Questions
-- If Danny wants to expand his range of pizzas - how would this impact the existing data design? 
-- Write an INSERT statement to demonstrate what would happen if a new Supreme pizza with all the toppings was added to the Pizza Runner menu?
DECLARE @new_pizza_id INT;

SELECT @new_pizza_id = ISNULL(MAX(pizza_id), 0) + 1
FROM pizza_names;

-- Add Supreme to the menu
INSERT INTO pizza_names (pizza_id, pizza_name)
VALUES (@new_pizza_id, 'Supreme');

-- Assign every existing topping to Supreme
INSERT INTO pizza_recipes (pizza_id, toppings)
SELECT
    @new_pizza_id,
    STRING_AGG(CAST(topping_id AS VARCHAR(10)), ',')
FROM pizza_toppings;

