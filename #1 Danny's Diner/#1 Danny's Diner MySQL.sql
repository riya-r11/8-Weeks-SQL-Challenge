
-- ==================================== DATABASE CREATION ================================================

CREATE SCHEMA dannys_diner;

USE dannys_diner;

CREATE TABLE sales (
  customer_id VARCHAR(1),
  order_date DATE,
  product_id INTEGER
);

INSERT INTO sales
  (customer_id, order_date, product_id)
VALUES
  ('A', '2021-01-01', '1'),
  ('A', '2021-01-01', '2'),
  ('A', '2021-01-07', '2'),
  ('A', '2021-01-10', '3'),
  ('A', '2021-01-11', '3'),
  ('A', '2021-01-11', '3'),
  ('B', '2021-01-01', '2'),
  ('B', '2021-01-02', '2'),
  ('B', '2021-01-04', '1'),
  ('B', '2021-01-11', '1'),
  ('B', '2021-01-16', '3'),
  ('B', '2021-02-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-07', '3');
 

CREATE TABLE menu (
  product_id INTEGER,
  product_name VARCHAR(5),
  price INTEGER
);

INSERT INTO menu
  (product_id, product_name, price)
VALUES
  ('1', 'sushi', '10'),
  ('2', 'curry', '15'),
  ('3', 'ramen', '12');
  

CREATE TABLE members (
  customer_id VARCHAR(1),
  join_date DATE
);

INSERT INTO members
  (customer_id, join_date)
VALUES
  ('A', '2021-01-07'),
  ('B', '2021-01-09');
  
  
  
  
  
  
  
-- ==================================== QUERIES ================================================

/* --------------------
   Case Study Questions
   --------------------*/

-- 1. What is the total amount each customer spent at the restaurant?
SELECT
    s.customer_id,
    SUM(m.price) AS total_amount_spent
FROM sales AS s
JOIN menu AS m
    ON s.product_id = m.product_id
GROUP BY s.customer_id
ORDER BY s.customer_id;

-- 2. How many days has each customer visited the restaurant?
SELECT customer_id,
       COUNT(DISTINCT order_date) AS num_visits
FROM sales
GROUP BY customer_id;

-- 3. What was the first item from the menu purchased by each customer?
SELECT customer_id, product_name
FROM (
	SELECT s.customer_id, 
			m.product_name,
			DENSE_RANK() OVER(PARTITION BY customer_id ORDER BY order_date) AS rnk
	FROM sales s
	LEFT JOIN menu m
		ON s.product_id=m.product_id) t
WHERE rnk=1;

-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?
WITH item_counts AS(
	SELECT	m.product_name, 
			COUNT(s.customer_id) AS total_customers
	FROM sales s
	LEFT JOIN menu m
		ON s.product_id=m.product_id
	GROUP BY m.product_name),

rnk_items AS(
	SELECT *,
			DENSE_RANK() OVER(ORDER BY total_customers DESC) AS rnk
	FROM item_counts)

SELECT product_name, 
		total_customers
FROM rnk_items
WHERE rnk=1;


-- 5. Which item was the most popular for each customer?
WITH item_counts AS(
	SELECT	s.customer_id,
			m.product_name, 
			COUNT(s.customer_id) AS total_customers
	FROM sales s
	LEFT JOIN menu m
		ON s.product_id=m.product_id
	GROUP BY s.customer_id, m.product_name),

rnk_items AS(
	SELECT *,
			DENSE_RANK() OVER(PARTITION BY customer_id ORDER BY total_customers DESC) AS rnk
	FROM item_counts)

SELECT customer_id,
		product_name
FROM rnk_items
WHERE rnk=1
ORDER BY customer_id, product_name;


-- 6. Which item was purchased first by the customer after they became a member?
WITH customer_order AS(
	SELECT s.customer_id,
			s.order_date,
			m.product_name,
			mem.join_date,
			RANK() OVER(PARTITION BY s.customer_id ORDER BY s.order_date) AS rnk
	FROM sales s
	LEFT JOIN members mem
		ON s.customer_id=mem.customer_id
	LEFT JOIN menu m
		ON s.product_id=m.product_id
	WHERE s.order_date>=mem.join_date)
SELECT customer_id,
		product_name
FROM customer_order
WHERE rnk=1;

-- 7. Which item was purchased just before the customer became a member?
WITH previous_order AS(
	SELECT s.customer_id,
			s.order_date,
			m.product_name,
			mem.join_date,
			RANK() OVER(PARTITION BY s.customer_id ORDER BY s.order_date DESC) AS rnk
	FROM sales s
	LEFT JOIN members mem
		ON s.customer_id=mem.customer_id
	LEFT JOIN menu m
		ON s.product_id=m.product_id
	WHERE s.order_date<mem.join_date)
SELECT customer_id,
		product_name
FROM previous_order
WHERE rnk=1
ORDER BY customer_id, product_name;

-- 8. What is the total items and amount spent for each member before they became a member?
SELECT s.customer_id,
		COUNT(s.product_id) AS total_products,
		SUM(m.price) AS total_amount
FROM sales s
LEFT JOIN members mem
	ON s.customer_id=mem.customer_id
LEFT JOIN menu m
	ON s.product_id=m.product_id
WHERE s.order_date<mem.join_date
GROUP BY s.customer_id
ORDER BY s.customer_id;

-- 9.  If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
SELECT s.customer_id,
SUM(
	CASE WHEN m.product_name='sushi' THEN 20*m.price
		 ELSE 10*m.price
	END
)AS total_points
FROM sales s
LEFT JOIN menu m
	ON s.product_id=m.product_id
GROUP BY s.customer_id
ORDER BY s.customer_id;

-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?
SELECT
    s.customer_id,
    SUM(
        CASE
            WHEN s.order_date BETWEEN mem.join_date
                AND DATE_ADD(mem.join_date, INTERVAL 6 DAY)
                THEN 20 * m.price
            WHEN m.product_name = 'sushi'
                THEN 20 * m.price
            ELSE 10 * m.price
        END
    ) AS total_points
FROM sales s
JOIN menu m
    ON s.product_id = m.product_id
JOIN members mem
    ON s.customer_id = mem.customer_id
WHERE s.order_date < '2021-02-01'
GROUP BY s.customer_id
ORDER BY s.customer_id;

-- In MySQL : WHEN s.order_date BETWEEN mem.join_date AND DATE_ADD(mem.join_date, INTERVAL 6 DAY)
-- In PostgreSQL : WHEN s.order_date BETWEEN mem.join_date AND mem.join_date + INTERVAL '6 days'
-- In SQL Server : WHEN s.order_date BETWEEN mem.join_date AND DATEADD(DAY, 6, mem.join_date)


# Bonus Questions
-- Q. Join All the Things
SELECT
    s.customer_id,
    s.order_date,
    m.product_name,
    m.price,
    CASE
        WHEN mem.join_date IS NOT NULL
             AND s.order_date >= mem.join_date
            THEN 'Y'
        ELSE 'N'
    END AS member
FROM sales AS s
JOIN menu AS m
    ON s.product_id = m.product_id
LEFT JOIN members AS mem
    ON s.customer_id = mem.customer_id
ORDER BY
    s.customer_id,
    s.order_date,
    m.product_name;

-- Q. Rank All the Things
WITH customer_orders AS(
SELECT
    s.customer_id,
    s.order_date,
    m.product_name,
    m.price,
    CASE
        WHEN mem.join_date IS NOT NULL
             AND s.order_date >= mem.join_date
            THEN 'Y'
        ELSE 'N'
    END AS member
FROM sales AS s
JOIN menu AS m
    ON s.product_id = m.product_id
LEFT JOIN members AS mem
    ON s.customer_id = mem.customer_id
)
SELECT customer_id,
    order_date,
    product_name,
    price,
	member,
	CASE WHEN member='Y' THEN RANK() OVER(PARTITION BY customer_id,member ORDER BY order_date)
		 ELSE NULL
	END AS ranking
FROM customer_orders
ORDER BY customer_id, order_date, product_name;
