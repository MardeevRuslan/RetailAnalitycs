-- ## Part 5. Формирование персональных предложений, ориентированных на рост частоты визитов


--------------------- fn_get_group_name ----------------------
DROP FUNCTION IF EXISTS fn_get_group_name;
CREATE OR REPLACE FUNCTION fn_get_group_name(id_group INTEGER)
RETURNS VARCHAR
AS $$
BEGIN
  RETURN (SELECT sku_group.group_name FROM sku_group WHERE sku_group.group_id = id_group);
END;
$$ LANGUAGE plpgsql;
-------------------fn_get_group_name END-------


------------------ fn_get_min_discount ----------------------
DROP FUNCTION IF EXISTS fn_get_min_discount;
CREATE OR REPLACE FUNCTION fn_get_min_discount(id_customer INTEGER, id_group INTEGER)
RETURNS NUMERIC
AS $$
BEGIN
  RETURN (SELECT p.group_min_discount FROM vw_periods AS p WHERE p.group_id = id_group AND p.customer_id = id_customer);
END;
$$ LANGUAGE plpgsql;
----------------------fn_get_min_discount END-------


------------------- fn_get_Group_Affinity_Index ----------------------
DROP FUNCTION IF EXISTS fn_get_Group_Affinity_Index;
CREATE OR REPLACE FUNCTION fn_get_Group_Affinity_Index(id_customer INTEGER, id_group INTEGER)
RETURNS NUMERIC
AS $$
BEGIN
  RETURN (SELECT g.Group_Affinity_Index FROM vw_groups AS g WHERE g.customer_id = id_customer AND g.group_id = id_group);
END;
$$ LANGUAGE plpgsql;
-------------------fn_get_Group_Affinity_Index END-------




------------------------- fn_required_transactions_count ----------------------
/*
Целевое количество транзакций
*/
DROP FUNCTION IF EXISTS fn_required_transactions_count;
CREATE OR REPLACE FUNCTION fn_required_transactions_count(date_start TIMESTAMP, 
  date_end TIMESTAMP, coutn_transactions INTEGER, id_customer INTEGER)
RETURNS NUMERIC
AS $$
BEGIN
  RETURN 
    (SELECT 
        CASE 
            WHEN c.fn_customer_frequency = 0 THEN coutn_transactions
            ELSE
            (EXTRACT(epoch FROM (date_end - date_start))/86400 + coutn_transactions)::integer
        END AS Required_Transactions_Count
    FROM vw_custormers AS c
    WHERE c.customer_id = id_customer);
END;
$$ LANGUAGE plpgsql;
-------------------fn_required_transactions_count END-------



--------------------- fn_group_award ----------------
/*
Определение группы для формирования вознаграждения
*/
DROP FUNCTION IF EXISTS fn_group_award();
CREATE OR REPLACE FUNCTION fn_group_award(max_group_churn_rate NUMERIC, 
max_group_discount_share NUMERIC)
RETURNS TABLE (Customer_ID INTEGER,group_id INTEGER, Group_Affinity_Index NUMERIC)
AS $$
BEGIN
  RETURN QUERY
  WITH cte AS (SELECT *
  FROM vw_groups AS g
  WHERE g.group_churn_rate <= max_group_churn_rate
  AND g.group_discount_share * 100 < max_group_discount_share)
  SELECT c.customer_id, c.group_id, c.Group_Affinity_Index::NUMERIC
  FROM cte AS c;
END;
$$ LANGUAGE plpgsql;
-------------------fn_group_award END-------




---------------- fn_group_middle_marg ------------
/*
Средняя маржа для  группы
*/
DROP FUNCTION IF EXISTS fn_group_middle_marg;
CREATE OR REPLACE FUNCTION fn_group_middle_marg (customer INTEGER, id_group INTEGER)
RETURNS NUMERIC
AS $$
BEGIN
RETURN(
    SELECT (sum(group_summ) - SUM(group_cost)) / SUM(group_summ) AS middle_marg
    FROM vw_purchase_history AS p
    WHERE p.customer_id = customer
    AND p.group_id = id_group
    GROUP BY p.group_id, p.customer_id
);
END;
$$ LANGUAGE plpgsql;
------------------ fn_group_middle_marg END --------



------------ fn_personal_offers ----------------------
/*
Параметры функции:

первая и последняя даты периода
добавляемое число транзакций
максимальный индекс оттока
максимальная доля транзакций со скидкой (в процентах)
допустимая доля маржи (в процентах)
*/
DROP FUNCTION IF EXISTS fn_personal_offers;
CREATE OR REPLACE FUNCTION fn_personal_offers(date_start TIMESTAMP, date_end TIMESTAMP,
coutn_transactions INTEGER, max_group_churn_rate NUMERIC, 
max_group_discount_share NUMERIC, valid_group_margin NUMERIC)
RETURNS TABLE (Customer_ID INTEGER, Start_Date TIMESTAMP, End_Date TIMESTAMP,
    Required_Transactions_Count NUMERIC, Group_Name VARCHAR,
    Offer_Discount_Depth NUMERIC)
AS $$
BEGIN
  RETURN QUERY
  WITH cte AS
(SELECT 
  ga.Customer_ID,
  ga.group_id,
  fn_get_group_name(ga.group_id) AS group_name,
  fn_group_middle_marg(ga.Customer_ID, ga.group_id) * valid_group_margin AS group_middle_marg,
  fn_get_min_discount(ga.Customer_ID, ga.group_id) * 100,
  (CEIL(fn_get_min_discount(ga.Customer_ID, ga.group_id) / 0.05) * 5) AS Offer_Discount_Depth,
  fn_get_Group_Affinity_Index(ga.Customer_ID, ga.group_id) AS Group_Affinity_Index
  FROM fn_group_award(max_group_churn_rate, max_group_discount_share) AS ga
  WHERE fn_group_middle_marg(ga.Customer_ID, ga.group_id) * valid_group_margin >= CEIL(fn_get_min_discount(ga.Customer_ID, ga.group_id) / 0.05) * 5)
  SELECT 
  c.Customer_ID,
  date_start,
  date_end,
  fn_required_transactions_count(date_start, date_end, coutn_transactions, c.Customer_ID),
  c.group_name,
  c.Offer_Discount_Depth
  FROM cte AS c
  WHERE c.Group_Affinity_Index = (SELECT MAX(c2.Group_Affinity_Index) FROM cte AS c2 WHERE c2.customer_id = c.customer_id);
END;
$$ LANGUAGE plpgsql;
-------------------fn_personal_offers END-------

SELECT * FROM fn_personal_offers('2022-08-18', '2022-08-18', 1, 3, 70, 30);

