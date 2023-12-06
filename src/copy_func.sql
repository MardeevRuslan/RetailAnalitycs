------ FN_Customer_Frequency --------
DROP FUNCTION IF EXISTS FN_Customer_Frequency CASCADE;
CREATE OR REPLACE FUNCTION FN_Customer_Frequency(c_id BIGINT)
RETURNS NUMERIC AS $$
  SELECT  (max(ct.Transaction_DateTime)::DATE - min(ct.transaction_datetime)::DATE - 1)::NUMERIC / 
    count(*)
  FROM fn_customer_transactions(c_id) AS ct
$$ LANGUAGE SQL;
------ FN_Customer_Frequency END-------- 
-- у меня ругался EXTRACT