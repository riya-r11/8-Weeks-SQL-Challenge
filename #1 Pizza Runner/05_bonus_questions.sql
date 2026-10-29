-- Pizza Runner - SQL Server

use pizza_runner;


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

