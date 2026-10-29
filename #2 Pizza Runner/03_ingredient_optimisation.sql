-- Pizza Runner - SQL Server

use pizza_runner;


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



