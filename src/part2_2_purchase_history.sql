-- ## Part 2. Создание представлений

DROP VIEW IF EXISTS vw_purchase_history CASCADE;


CREATE OR REPLACE VIEW vw_purchase_history AS (
    WITH purchase_history AS (
    SELECT c2.customer_id, t.transaction_id, t.transaction_datetime, 
        pg.group_id, s.sku_purchase_price * c.sku_amount AS Group_Cost,
        c.sku_summ, c.SKU_Summ_Paid, c.sku_discount
    FROM transaction AS t
    INNER JOIN checks AS c ON t.transaction_id = c.transaction_id
    INNER JOIN product_grid AS pg ON c.sku_id = pg.sku_id
    INNER JOIN cards AS c2 ON t.customer_card_id = c2.customer_card_id
    INNER JOIN stores AS s ON t.transaction_store_id = s.transaction_store_id
    AND s.sku_id = c.sku_id
)
SELECT ph.customer_id, ph.transaction_id, ph.transaction_datetime, 
        ph.group_id, SUM(ph.Group_Cost) AS Group_Cost,
        SUM(ph.sku_summ) AS Group_Summ, SUM(ph.SKU_Summ_Paid) AS Group_Summ_Paid,
        SUM(ph.sku_discount) AS Group_Summ_Discount
FROM purchase_history AS ph
-- WHERE ph.transaction_datetime <= FN_Get_Date_Analysis()
GROUP BY 1,2,3,4
ORDER BY customer_id, group_id, transaction_id DESC
);

SELECT * FROM vw_purchase_history;