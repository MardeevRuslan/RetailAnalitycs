-- ## Part 2. Создание представлений

DROP VIEW IF EXISTS vw_periods CASCADE;

CREATE OR REPLACE VIEW vw_periods AS (
    WITH period AS (
    SELECT c2.customer_id, pg.group_id,
        MIN(t.transaction_datetime) AS First_Group_Purchase_Date,
        MAX(t.transaction_datetime) AS Last_Group_Purchase_Date, 
        COUNT(t.transaction_id) AS Group_Purchase
    FROM transaction AS t
    INNER JOIN checks AS c ON t.transaction_id = c.transaction_id
    INNER JOIN product_grid AS pg ON c.sku_id = pg.sku_id
    INNER JOIN cards AS c2 ON t.customer_card_id = c2.customer_card_id
    GROUP BY c2.customer_id, pg.group_id
    ORDER BY 1,2,3
    ),

     discount1 AS (
    SELECT p.customer_id, p.group_id, MIN(ph.group_summ_discount / ph.group_summ)
        AS Group_Min_Discount
    FROM vw_purchase_history AS ph
    JOIN period AS p
    ON p.customer_id = ph. customer_id
    AND p.group_id = ph.group_id
    GROUP BY 1,2
    UNION
    SELECT p.customer_id, p.group_id, MIN(ph.group_summ_discount / ph.group_summ)
        AS Group_Min_Discount
    FROM vw_purchase_history AS ph
    JOIN period AS p
    ON p.customer_id = ph. customer_id
    AND p.group_id = ph.group_id
    WHERE group_summ_discount <> 0
    GROUP BY 1,2
    ORDER BY 1,2,3),

    discount AS (
        SELECT customer_id, group_id, MAX(Group_Min_Discount)
        AS Group_Min_Discount
        FROM discount1
        GROUP BY 1,2
    )

SELECT p.customer_id, p.group_id, p.First_Group_Purchase_Date,
    p.Last_Group_Purchase_Date, p.Group_Purchase,
    ((p.Last_Group_Purchase_Date::date - p.First_Group_Purchase_Date::date)::NUMERIC + 1) / p.Group_Purchase AS Group_Frequency,
    d.Group_Min_Discount
FROM discount AS d
JOIN period AS p
ON p.customer_id = d.customer_id
AND p.group_id = d.group_id
ORDER BY 1,2

);

SELECT * FROM vw_periods;



