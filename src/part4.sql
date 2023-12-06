-- Active: 1689044315190@@127.0.0.1@5433@retail
-- ## Part 4. Формирование персональных предложений, ориентированных на рост среднего чека


---- FN_Customer_Average_Date_Check --------
-- Пользователь выбирает методику расчета **по периоду**, после чего
-- указывает первую и последнюю даты периода, за который
-- необходимо рассчитать средний чек для всей совокупности
-- клиентов, попавших в выборку.
DROP FUNCTION IF EXISTS FN_Customer_Average_Date_Check CASCADE;
CREATE OR REPLACE FUNCTION FN_Customer_Average_Date_Check(
  c_id BIGINT, 
  first_date timestamp, 
  last_date timestamp)
RETURNS NUMERIC 
AS $$
  SELECT COALESCE(
    (SELECT sum(Transaction_Summ) / count(*)
    FROM fn_customer_transactions_in_date_range(c_id, LEAST(first_date, last_date), GREATEST(first_date, last_date)) AS tr), 
    0);
$$ LANGUAGE SQL;
------ FN_Customer_Average_Date_Check END--------

---- FN_Customer_Average_Count_Check --------
-- Пользователь выбирает методику расчета **по количеству последних
-- транзакций**, после чего вручную указывает количество
-- транзакций, по которым необходимо рассчитать средний чек.
DROP FUNCTION IF EXISTS FN_Customer_Average_Count_Check CASCADE;
CREATE OR REPLACE FUNCTION FN_Customer_Average_Count_Check(c_id BIGINT, count INT)
RETURNS NUMERIC 
AS $$
  SELECT COALESCE(
    (SELECT avg(Transaction_Summ)
    FROM (SELECT * FROM fn_customer_transactions(c_id) LIMIT count) AS tr), 
    0);
$$ LANGUAGE SQL;
------ FN_Customer_Average_Count_Check END--------


------ fn_customer_group_margin_persent ------
/*
Расчет фактической маржи по транзакциям (для столбца 6)
*/
DROP FUNCTION IF EXISTS fn_customer_group_margin_persent CASCADE;
CREATE OR REPLACE FUNCTION fn_customer_group_margin_persent(c_id INTEGER, g_id INTEGER)
RETURNS NUMERIC 
AS $$
  SELECT COALESCE(
    (SELECT sum(group_summ_paid) / sum(group_cost) FROM vw_purchase_history AS ph
    WHERE ph.customer_id = c_id AND ph.group_id = g_id
    GROUP BY group_id),
  0)
$$ LANGUAGE SQL;

-- SELECT group_id, fn_customer_group_margin_persent(1, group_id) FROM sku_group;
------ fn_customer_group_margin_persent END ------



---- VW_Customers_group_margin ----
DROP VIEW IF EXISTS VW_Customers_group_margin CASCADE;
CREATE OR REPLACE VIEW VW_Customers_group_margin AS (
    SELECT * FROM (
      SELECT 
      customer_id,
      group_id,
      group_affinity_index,
      group_churn_rate,
      group_discount_share,
      group_minimum_discount,
      fn_customer_group_margin_persent(customer_id, group_id) AS group_margin_discount
    FROM vw_groups) AS sub
    WHERE group_discount_share IS NOT NULL
);
-- SELECT * FROM VW_Customers_group_margin;
---- VW_Customers_group_margin END----


---- FN_Customers_Group_Margin_With_Discount --------
DROP FUNCTION IF EXISTS FN_Customers_Group_Margin_With_Discount CASCADE;
CREATE OR REPLACE FUNCTION FN_Customers_Group_Margin_With_Discount(max_margin_percent NUMERIC)
RETURNS TABLE(
  customer_id INT,
  group_id INT,
  group_affinity_index NUMERIC,
  group_churn_rate NUMERIC,
  group_discount_share NUMERIC,
  group_minimum_discount NUMERIC,
  group_margin NUMERIC)
AS $$
  SELECT
      customer_id,
      group_id,
      group_affinity_index,
      group_churn_rate,
      group_discount_share,
      FN_ROUND_FIVE(group_minimum_discount),
      ((group_margin_discount - 1)) * 100 * ((100 - max_margin_percent) / 100)
  FROM VW_Customers_group_margin
  ORDER BY group_affinity_index DESC
$$ LANGUAGE SQL;
---- FN_Customers_Group_Margin_With_Discount END --------


---- FN_Customers_must_group --------
DROP FUNCTION IF EXISTS FN_Customers_must_group CASCADE;
CREATE OR REPLACE FUNCTION FN_Customers_must_group(
  max_churn_rate NUMERIC, 
  max_sale_part NUMERIC, 
  max_margin_percent NUMERIC)
RETURNS TABLE (
  customer_id INT,
  group_id INT,
  group_affinity_index NUMERIC,
  group_churn_rate NUMERIC,
  group_minimum_discount NUMERIC) 
AS $$
  SELECT 
    customer_id,
    group_id,
    group_affinity_index,
    group_churn_rate,
    group_minimum_discount
FROM FN_Customers_Group_Margin_With_Discount(30) AS sm
WHERE 
  group_margin > 0 AND group_churn_rate < 3
  AND group_discount_share < 70 / 100::NUMERIC
  AND group_minimum_discount < group_margin
ORDER BY customer_id, group_affinity_index DESC
$$ LANGUAGE SQL;
------ FN_Customers_must_group END--------



-- ------ FN_Average_Check_Growth --------
DROP FUNCTION IF EXISTS FN_Average_Check_Growth CASCADE;
CREATE OR REPLACE FUNCTION FN_Average_Check_Growth(
  method INT, -- метод расчета среднего чека (1 - за период, 2 - за количество)
  first_date timestamp, -- первая и последняя даты периода (для 1 метода)
  last_date timestamp,
  transaction_cout INT, -- количество транзакций (для 2 метода)
  koeff_average_check NUMERIC, -- коэффициент увеличения среднего чека
  max_churn_rate NUMERIC, -- максимальный индекс оттока
  max_sale_part NUMERIC, -- максимальная доля транзакций со скидкой (в процентах)
  max_margin_percent NUMERIC) -- допустимая доля маржи (в процентах)
RETURNS 
TABLE (
  Customer_ID INTEGER,
  Required_Check_Measure NUMERIC, -- Целевое значение среднего чека, необходимое для получения вознаграждения.
  Group_Name VARCHAR, -- Название группы предложения, на которой начисляется вознаграждение при выполнении условия.
  Offer_Discount_Depth NUMERIC) -- Максимально возможный размер скидки для предложения.
AS $$
  SELECT 
    mg.customer_id,
    koeff_average_check * round((CASE 
    WHEN method = 1 THEN FN_Customer_Average_Date_Check(customer_id, first_date, last_date)
    WHEN method = 2 THEN FN_Customer_Average_Count_Check(customer_id, transaction_cout)
    ELSE 0 
    END), 2) AS Required_Check_Measure,
    -- mg.group_id,
    sku.Group_Name,
    group_minimum_discount
  FROM FN_Customers_must_group(max_churn_rate, max_sale_part, max_margin_percent) AS mg
  JOIN sku_group AS sku ON sku.group_id = mg.group_id
  WHERE group_minimum_discount > 0
$$ LANGUAGE SQL;
-- ------ FN_Average_Check_Growth END--------

-- SELECT * FROM vw_groups;

SELECT * FROM FN_Average_Check_Growth(
2,
'2021-01-20 20:00:00',
'2023-01-20 20:00:00',
100,
1.15,
3,
70,
30) AS ag;
