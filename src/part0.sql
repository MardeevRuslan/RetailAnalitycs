------ get_personal_cart --------
DROP FUNCTION IF EXISTS fn_get_personal_cart;
CREATE OR REPLACE FUNCTION fn_get_personal_cart(c_id BIGINT)
RETURNS TABLE(a cards) AS $$
BEGIN
    RETURN QUERY SELECT *
    FROM cards
    WHERE customer_id = c_id;
END;
$$ LANGUAGE plpgsql STABLE;
------ get_personal_cart END ------

------ FN_Get_Date_Analysis --------
DROP FUNCTION IF EXISTS FN_Get_Date_Analysis CASCADE;
CREATE OR REPLACE FUNCTION FN_Get_Date_Analysis()
RETURNS timestamp AS $$
    SELECT MAX(Analysis_Formation) FROM date_of_analysis
$$ LANGUAGE SQL;
------ FN_Get_Date_Analysis END ------

------ fn_customer_transactions --------
/* Отдает транзакции покупателя ограниченные датой анализа */
DROP FUNCTION IF EXISTS fn_customer_transactions;
CREATE OR REPLACE FUNCTION fn_customer_transactions(c_id BIGINT)
RETURNS TABLE(a "transaction") AS $$
BEGIN
    RETURN QUERY 
    SELECT
      tr.transaction_id,
      tr.customer_card_id,
      tr.transaction_summ,
      tr.transaction_datetime,
      tr.transaction_store_id
    FROM "transaction" AS tr
    LEFT JOIN fn_get_personal_cart(c_id) AS pc 
      ON pc.Customer_Card_ID = tr.Customer_Card_ID
    WHERE pc.Customer_Card_ID IS NOT NULL
    AND tr.transaction_datetime < FN_Get_Date_Analysis()
    ;
END;
$$ LANGUAGE plpgsql STABLE;
------ fn_customer_transactions END ------



------ fn_customer_transactions_in_date_range --------
DROP FUNCTION IF EXISTS fn_customer_transactions_in_date_range;
CREATE OR REPLACE FUNCTION fn_customer_transactions_in_date_range(
  c_id BIGINT, 
  first_date timestamp,
  last_date timestamp)
RETURNS TABLE(a "transaction") AS $$
BEGIN
    RETURN QUERY 
    SELECT
      *
    FROM fn_customer_transactions(c_id) AS tr
    WHERE tr.transaction_datetime BETWEEN first_date AND last_date;
END;
$$ LANGUAGE plpgsql STABLE;
------ fn_customer_transactions END ------

------ FN_Customer_Last_Transaction ------
/*Отдает количество неактивных дней с на день анализа */
DROP FUNCTION IF EXISTS FN_Customer_Inactive_Period CASCADE;
CREATE OR REPLACE FUNCTION FN_Customer_Inactive_Period(c_id BIGINT)
RETURNS FLOAT AS $$
    SELECT EXTRACT (epoch FROM (
      FN_Get_Date_Analysis() - tr_date)) / 86400
    FROM (
      SELECT COALESCE(
        (SELECT max(transaction_datetime) FROM fn_customer_transactions(c_id)), 
        now()) AS tr_date) AS tr_dt
$$ LANGUAGE SQL;
------ FN_Customer_Last_Transaction END ------



------ FN_Customer_Last_Transaction ------
/*Отдает округленные вверх на 5 проценты (НЕ ПРОПОРЦИИ)*/
DROP FUNCTION IF EXISTS FN_ROUND_FIVE CASCADE;
CREATE OR REPLACE FUNCTION FN_ROUND_FIVE(val NUMERIC)
RETURNS NUMERIC AS $$
    SELECT ceil(round(val, 2) / 0.05) * 5;
$$ LANGUAGE SQL;
------ FN_Customer_Last_Transaction END ------









