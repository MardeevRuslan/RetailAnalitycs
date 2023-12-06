-- ## Part 2. Создание представлений

------ FN_Get_Rate --------
DROP FUNCTION IF EXISTS FN_Get_Segment CASCADE;
CREATE OR REPLACE FUNCTION FN_Get_Segment(number bigint, count_item bigint, top VARCHAR, med VARCHAR, bot VARCHAR)
RETURNS VARCHAR AS $$
    SELECT 
      (CASE 
        WHEN persent = 0 OR persent > 0.25 THEN bot
        WHEN persent > 0.1 THEN med
        ELSE top
        END)
    FROM (
      SELECT 
        (CAST(number AS NUMERIC) / count_item) AS persent) AS pr
$$ LANGUAGE SQL;
------ FN_Get_Rate END--------


------ Customer_Average_Check --------
DROP FUNCTION IF EXISTS fn_customer_Average_Check CASCADE;
CREATE OR REPLACE FUNCTION fn_customer_Average_Check(c_id BIGINT)
RETURNS NUMERIC AS $$
    SELECT avg(Transaction_Summ) FROM fn_customer_transactions(c_id)
$$ LANGUAGE SQL;

------ Customer_Average_Check END--------


------ VW_Customer_Average_Rate --------
DROP VIEW IF EXISTS VW_Customer_Average_Rate CASCADE;
CREATE OR REPLACE VIEW VW_Customer_Average_Rate AS (
  SELECT 
    customer_id, 
    asumm,
    ROW_NUMBER() OVER () AS number 
  FROM (
    SELECT
      customer_id, 
      fn_Customer_Average_Check(customer_id) AS asumm
    FROM personal_information
    ORDER BY 2 DESC) AS ca
  WHERE asumm IS NOT NULL
);
------ VW_Customer_Average_Numbers END--------

------ Customer_Average_Number --------
DROP FUNCTION IF EXISTS fn_customer_Average_Number;
CREATE OR REPLACE FUNCTION fn_customer_Average_Number(c_id BIGINT)
RETURNS BIGINT AS $$
  SELECT number FROM VW_Customer_Average_Rate
  WHERE customer_id = c_id
  LIMIT 1
$$ LANGUAGE SQL;
------ Customer_Average_Check END--------

------ Customer_Average_Check_Segment --------
DROP FUNCTION IF EXISTS fn_customer_Average_Check_Segment;

CREATE OR REPLACE FUNCTION fn_customer_Average_Check_Segment(c_id BIGINT)
RETURNS VARCHAR AS $$
  SELECT FN_Get_Segment(
    fn_customer_Average_Number(c_id),
    (SELECT count(*) FROM VW_Customer_Average_Rate),
    'Hight', 'Medium', 'Low');
$$ LANGUAGE SQL;

------ Customer_Average_Check_Segment END--------


------ FN_Customer_Frequency --------
DROP FUNCTION IF EXISTS FN_Customer_Frequency CASCADE;
CREATE OR REPLACE FUNCTION FN_Customer_Frequency(c_id BIGINT)
RETURNS NUMERIC AS $$
  SELECT EXTRACT(epoch FROM (max(ct.Transaction_DateTime) - min(ct.transaction_datetime)))/86400 / 
    count(*)
  FROM fn_customer_transactions(c_id) AS ct
$$ LANGUAGE SQL;
------ FN_Customer_Frequency END--------



------ VW_Customer_Frequency_Rate --------
DROP VIEW IF EXISTS VW_Customer_Frequency_Rate CASCADE;
CREATE OR REPLACE VIEW VW_Customer_Frequency_Rate AS (
  SELECT 
    customer_id, 
    frenq,
    ROW_NUMBER() OVER () AS number 
  FROM (
    SELECT
      customer_id, 
      FN_Customer_Frequency(customer_id) AS frenq
    FROM personal_information
    ORDER BY 2 ASC) AS list
  WHERE frenq > 0
);
------ VW_Customer_Frequency_Rate END--------

------ FN_Customer_Frequency_Number --------
DROP FUNCTION IF EXISTS FN_Get_Customer_Frequency_Segment CASCADE;
CREATE OR REPLACE FUNCTION FN_Get_Customer_Frequency_Segment(c_id BIGINT)
RETURNS VARCHAR AS $$
    SELECT FN_Get_Segment(
      number,
      (SELECT count(*) FROM personal_information),
      'Often', 'Occasionally', 'Rarely') 
    FROM (
      SELECT number FROM VW_Customer_Frequency_Rate
      WHERE customer_id = c_id
      LIMIT 1) AS cn
$$ LANGUAGE SQL;
------ FN_Customer_Frequency_Number END--------

------ FN_Customer_Churn_Rate --------
DROP FUNCTION IF EXISTS FN_Customer_Churn_Rate CASCADE;
CREATE OR REPLACE FUNCTION FN_Customer_Churn_Rate(c_id BIGINT)
RETURNS NUMERIC AS $$
    SELECT CAST (FN_Customer_Inactive_Period(c_id) AS NUMERIC) / 
    (CASE WHEN FN_Customer_Frequency(c_id) > 0 THEN FN_Customer_Frequency(c_id)
    ELSE 1
    END)
$$ LANGUAGE SQL;
------ FN_Customer_Churn_Rate END--------

------ VW_Customer_Frequency_Rate --------
DROP VIEW IF EXISTS VW_Customer_Churn_Rate CASCADE;
CREATE OR REPLACE VIEW VW_Customer_Churn_Rate AS (
  SELECT 
    customer_id, 
    churn,
    ROW_NUMBER() OVER () AS number 
  FROM (
    SELECT
      customer_id, 
      FN_Customer_Churn_Rate(customer_id) AS churn
    FROM personal_information
    ORDER BY 2 DESC) AS list
);

------ VW_Customer_Frequency_Rate END--------

------ FN_Customer_Frequency_Number --------
DROP FUNCTION IF EXISTS FN_Get_Customer_Church_Segment CASCADE;
CREATE OR REPLACE FUNCTION FN_Get_Customer_Church_Segment(c_id BIGINT)
RETURNS VARCHAR AS $$
    SELECT FN_Get_Segment(
      number,
      (SELECT count(*) FROM VW_Customer_Frequency_Rate),
      'Hight', 'Medium', 'Low') 
    FROM (
      SELECT number FROM VW_Customer_Churn_Rate
      WHERE customer_id = c_id
      LIMIT 1) AS cn
$$ LANGUAGE SQL;
------ FN_Customer_Frequency_Number END--------


------ MW_Customer_Check_Segment --------
DROP MATERIALIZED VIEW IF EXISTS MW_Customer_Segments;

CREATE MATERIALIZED VIEW MW_Customer_Segments AS (
  SELECT 
    ROW_NUMBER() OVER () AS number,
    average_check,
    frequency_puerchases,
    churn_probability
  FROM 
  unnest(array['Rarely', 'Occasionally', 'Often']) AS frequency_puerchases,
  unnest(array['Low', 'Medium', 'Hight']) AS churn_probability,
  unnest(array['Low', 'Medium', 'Hight']) AS average_check
);
------ MW_Customer_Check_Segment END --------

------ FN_Customer_Segment --------
DROP FUNCTION IF EXISTS FN_Customer_Segment CASCADE;
CREATE OR REPLACE FUNCTION FN_Customer_Segment(c_id BIGINT)
RETURNS VARCHAR AS $$
    SELECT number
    FROM MW_Customer_Segments
    WHERE fn_customer_Average_Check_Segment(c_id) = average_check
    AND FN_Get_Customer_Frequency_Segment(c_id) = frequency_puerchases
    AND FN_Get_Customer_Church_Segment(c_id) = churn_probability
$$ LANGUAGE SQL;
------ FN_Customer_Segment END--------



------ FN_Customer_Stores --------
DROP FUNCTION IF EXISTS FN_Customer_Stores CASCADE;
CREATE OR REPLACE FUNCTION FN_Customer_Stores(c_id BIGINT)
RETURNS TABLE(a BIGINT) AS $$
    SELECT DISTINCT
      st.Transaction_Store_ID
    FROM stores AS st
    LEFT JOIN fn_customer_transactions(c_id) AS ct 
      ON ct.transaction_store_id = st.transaction_store_id
    WHERE ct.transaction_store_id IS NOT NULL
$$ LANGUAGE SQL;
------ FN_Customer_Stores END--------



------ FN_Customer_Stores --------
DROP FUNCTION IF EXISTS FN_Customer_Stores CASCADE;
CREATE OR REPLACE FUNCTION FN_Customer_Stores(c_id BIGINT)
RETURNS TABLE(Transaction_Store_ID BIGINT) AS $$
    SELECT DISTINCT
      st.Transaction_Store_ID
    FROM stores AS st
    LEFT JOIN fn_customer_transactions(c_id) AS ct 
      ON ct.transaction_store_id = st.transaction_store_id
    WHERE ct.transaction_store_id IS NOT NULL
$$ LANGUAGE SQL;
------ FN_Customer_Stores END--------



------ FN_Customer_Store_Part --------
DROP FUNCTION IF EXISTS FN_Customer_Store_Part CASCADE;
CREATE OR REPLACE FUNCTION FN_Customer_Store_Part(c_id BIGINT)
RETURNS 
TABLE(Transaction_Store_ID BIGINT, transaction_count BIGINT, sum NUMERIC, last_trans date) AS $$
    SELECT 
      cs.Transaction_Store_ID,
      count(*),
      CAST (count(*) AS NUMERIC) / (select count(*) FROM fn_customer_transactions(c_id)),
      max(Transaction_DateTime)
    FROM FN_Customer_Stores(c_id) AS cs
    JOIN fn_customer_transactions(c_id) AS ct 
      ON ct.Transaction_Store_ID = cs.Transaction_Store_ID
    GROUP BY cs.Transaction_Store_ID
    ORDER BY 2 DESC, 4 DESC
$$ LANGUAGE SQL;

------ FN_Customer_Store_Part END--------



------ FN_Customer_Primary_Store --------
DROP FUNCTION IF EXISTS FN_Customer_Primary_Store CASCADE;
CREATE OR REPLACE FUNCTION FN_Customer_Primary_Store(c_id BIGINT)
RETURNS BIGINT AS $$
      SELECT Transaction_Store_ID FROM FN_Customer_Store_Part(c_id)
      LIMIT 1
    $$ LANGUAGE SQL;
------ Customer_Primary_Store END--------


------ vw_customers --------
DROP VIEW IF EXISTS vw_customers CASCADE;

CREATE OR REPLACE VIEW vw_custormers AS (
  SELECT * FROM (
    SELECT 
    customer_id,
    fn_customer_Average_Check(customer_id),
    fn_customer_Average_Check_Segment(customer_id),
    fn_customer_Frequency(customer_id),
    FN_Get_Customer_Frequency_Segment(customer_id),
    FN_Customer_Inactive_Period(customer_id),
    FN_Customer_Churn_Rate(customer_id),
    FN_Get_Customer_Church_Segment(customer_id),
    FN_Customer_Segment(customer_id),
    FN_Customer_Primary_Store(customer_id)
    FROM personal_information) AS gnr
  WHERE gnr.fn_customer_Average_Check IS NOT NULL
);

SELECT * FROM vw_custormers;
------ vw_customers END --------
