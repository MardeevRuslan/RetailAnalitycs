

------------------------- fn_sku_name ----------------------
DROP FUNCTION IF EXISTS fn_sku_name;
CREATE OR REPLACE FUNCTION fn_get_sku_name(id_SKU INTEGER)
RETURNS VARCHAR
AS $$
BEGIN
    RETURN (SELECT product_grid.sku_name FROM product_grid WHERE product_grid.sku_id = id_SKU);
END;
$$ LANGUAGE plpgsql;
-------------------fn_sku_name END-------



---------------- fn_sku_max_marg ------------
/*
Для клиента и группы выбираются  SKU_ID отвечающие следующим
условиям:
Максимальная маржа в группе
*/
DROP FUNCTION IF EXISTS fn_sku_max_marg;
CREATE OR REPLACE FUNCTION fn_sku_max_marg (customer INTEGER, id_group INTEGER)
RETURNS INTEGER
AS $$
BEGIN
RETURN(
    WITH cte AS (SELECT c.sku_id, (p.group_summ_paid - p.group_cost)::NUMERIC  AS max_marg
    FROM vw_purchase_history AS p
    JOIN checks AS c ON p.transaction_id = c.transaction_id
    WHERE p.customer_id = customer
    AND p.group_id = id_group
    ORDER BY max_marg DESC
    LIMIT 1)
    SELECT cte.sku_id
    FROM cte
);
END;
$$ LANGUAGE plpgsql;
------------------ fn_sku_max_marg END --------



-- ---------------- fn_proportion_transactions ------------
/*
Определение доли SKU в группе
*/
DROP FUNCTION IF EXISTS fn_proportion_transactions;
CREATE OR REPLACE FUNCTION fn_proportion_transactions (id_SKU INTEGER)
RETURNS NUMERIC
AS $$
DECLARE
    trans_group NUMERIC;
    trans_SKU NUMERIC;
BEGIN
    SELECT
        (SELECT COUNT(DISTINCT t.transaction_id)
        FROM "transaction" AS t
        JOIN checks AS c ON t.transaction_id = c.transaction_id
        WHERE c.sku_id = id_SKU
        AND t.transaction_datetime <= (SELECT analysis_formation FROM date_of_analysis)) INTO trans_SKU;

    SELECT
        (SELECT COUNT(DISTINCT t.transaction_id)
        FROM "transaction" AS t
        JOIN checks AS c ON t.transaction_id = c.transaction_id
        JOIN product_grid AS p ON c.sku_id = p.sku_id
        WHERE p.group_id = (SELECT group_id FROM product_grid WHERE sku_id = id_SKU)
        AND t.transaction_datetime <= (SELECT analysis_formation FROM date_of_analysis)) INTO trans_group;

    RETURN CASE WHEN trans_group > 0 THEN trans_SKU / trans_group ELSE 0 END;
END;
$$ LANGUAGE plpgsql;
----------------- fn_proportion_transactions END----------




------------------ fn_valid_Churn_Rate_Stability_Rate ------------
/*
Для каждого клиента выбираются все
группы  отвечающие следующим
условиям:
Индекс оттока по группе не более заданного пользователем значения.
Индекс стабильности потребления группы составляет менее заданного пользователем значения.
*/
DROP FUNCTION IF EXISTS fn_valid_Churn_Rate_Stability_Rate;
CREATE OR REPLACE FUNCTION fn_valid_Churn_Rate_Stability_Rate (
    max_Group_Churn_Rate NUMERIC,
    max_Group_Stability_Rate NUMERIC)
RETURNS TABLE (Customer_ID INTEGER, 
                group_id INTEGER)
AS $$
BEGIN
                    RETURN QUERY 
                    SELECT g.customer_id, g.group_id
                    FROM vw_groups AS g
                    WHERE 
                    g.group_churn_rate <= max_Group_Churn_Rate
                    AND g.group_stability_index < max_Group_Stability_Rate;
                    
                    
END;
$$ LANGUAGE plpgsql STABLE;
------------------------------ fn_valid_Churn_Rate_Stability_Rate END --------------------


-------------------- fn_calc_discount ------------
/*
Расчет скидки
*/
DROP FUNCTION IF EXISTS fn_calc_discount;
CREATE OR REPLACE FUNCTION fn_calc_discount(allowable_margin_share NUMERIC, id_customer INTEGER, id_SKU INTEGER)
RETURNS NUMERIC
AS $$
BEGIN
    RETURN (
        SELECT allowable_margin_share * (sku_retail_price - sku_purchase_price) / sku_retail_price
        FROM stores AS s
        WHERE s.sku_id = id_SKU
        );
END;
$$ LANGUAGE plpgsql;
------------------- fn_calc_discount END -------



-- ------------------ fn_min_discount_ceil ------------
/*
Расчет минимальной скидки
*/
DROP FUNCTION IF EXISTS fn_min_discount_ceil;
CREATE OR REPLACE FUNCTION fn_min_discount_ceil(id_customer INTEGER, id_group INTEGER)
RETURNS NUMERIC
AS $$
BEGIN
    RETURN (
        SELECT
        CEIL(((v.group_minimum_discount) * 100) / 5.0) * 5.0
        FROM vw_groups AS v
        WHERE v.customer_id = id_customer
        AND v.group_id = id_group
        );
END;
$$ LANGUAGE plpgsql;
------------------ fn_min_discount_ceil END -------



------ fn_cross_selling --------
/*
Параметры функции:
количество групп
максимальный индекс оттока
максимальный индекс стабильности потребления
максимальная доля SKU (в процентах)
допустимая доля маржи (в процентах)
*/

DROP FUNCTION IF EXISTS fn_cross_selling;
CREATE OR REPLACE FUNCTION fn_cross_selling(number_of_groups INT,
    max_Group_Churn_Rate NUMERIC,
    max_Group_Stability_Rate NUMERIC,
    max_rotation_SKU NUMERIC,
    allowable_margin_share NUMERIC)
RETURNS TABLE (Customer_ID INTEGER, 
                SKU_Name VARCHAR, 
                Offer_Discount_Depth NUMERIC)
AS $$
DECLARE 
BEGIN
    RETURN QUERY
   SELECT 
    v.customer_id,
    fn_get_sku_name(fn_sku_max_marg(v.customer_id, v.group_id)),
    fn_min_discount_ceil(v.customer_id, v.group_id) AS min_discount
FROM fn_valid_Churn_Rate_Stability_Rate(max_Group_Churn_Rate, max_Group_Stability_Rate) AS v
WHERE
fn_proportion_transactions(fn_sku_max_marg(v.customer_id, v.group_id)) <= max_rotation_SKU
AND
fn_calc_discount(allowable_margin_share, v.customer_id, fn_sku_max_marg(v.customer_id, v.group_id)) >= fn_min_discount_ceil(v.customer_id, v.group_id);
END;
$$ LANGUAGE plpgsql STABLE;
------ fn_cross_selling END ------

SELECT * FROM fn_cross_selling(5, 3, 0.5, 100, 30);










