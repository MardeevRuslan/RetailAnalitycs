------ fn_get_first_date ------

/*
 Возвращает дату первой транзакции по определённой группе
 (для столбца 3 Group_Affinity_Index)
 */

DROP FUNCTION
    IF EXISTS fn_get_first_date (c_id BIGINT, id_group BIGINT);

CREATE
OR REPLACE FUNCTION fn_get_first_date(c_id BIGINT, id_group BIGINT) RETURNS TIMESTAMP AS $$
BEGIN
    RETURN 
    (SELECT first_group_purchase_date
    FROM vw_periods AS p
    WHERE p.customer_id = c_id AND p.group_id = id_group);
END;
$$ LANGUAGE plpgsql STABLE;


------ fn_get_first_date END ------
------ fn_get_last_date ------
/*
 Возвращает дату последней транзакции по определённой группе
 (для столбца 3 Group_Affinity_Index)
 */
DROP FUNCTION
    IF EXISTS fn_get_last_date (c_id BIGINT, id_group BIGINT);

CREATE
OR REPLACE FUNCTION fn_get_last_date(c_id BIGINT, id_group BIGINT) RETURNS TIMESTAMP AS $$
BEGIN
    RETURN 
    (SELECT last_group_purchase_date
    FROM vw_periods AS p
    WHERE p.customer_id = c_id AND p.group_id = id_group);
END;
$$ LANGUAGE plpgsql STABLE;
------ fn_get_last_date END ------
------ fn_count_customer_transactions --------
/*
 Возвращает общее количество транзакций за период, в котором проводились транзакции по определённой группе
 (для столбца 3 Group_Affinity_Index)
 */
DROP FUNCTION
    IF EXISTS fn_count_customer_transactions(c_id BIGINT, id_group BIGINT) CASCADE;

CREATE
OR REPLACE FUNCTION fn_count_customer_transactions(c_id BIGINT, id_group BIGINT) RETURNS NUMERIC AS $$
DECLARE first_group_purchase_date TIMESTAMP := fn_get_first_date(c_id, id_group);
DECLARE last_group_purchase_date TIMESTAMP := fn_get_last_date(c_id, id_group);
BEGIN
    RETURN (
    WITH trans AS (
    SELECT *
    FROM "transaction" AS tr
    INNER JOIN cards AS c ON tr.customer_card_id = c.customer_card_id
    INNER JOIN vw_purchase_history AS ph ON tr.transaction_id = ph.transaction_id AND c.customer_id = ph.customer_id
    WHERE tr.transaction_datetime BETWEEN first_group_purchase_date AND last_group_purchase_date
    AND ph.customer_id = c_id
    )
    SELECT COUNT(*) FROM trans
    )::numeric;
END;
$$ LANGUAGE plpgsql STABLE;

------ fn_count_customer_transactions END ------


------ fn_count_customer_transactions_group --------
/*
 Возвращает количество транзакций по группе за период, в котором проводились транзакции по определённой группе
 (для столбца 3 Group_Affinity_Index)
 */
DROP FUNCTION
    IF EXISTS fn_count_customer_transactions_group(c_id BIGINT, id_group BIGINT) CASCADE;

CREATE
OR REPLACE FUNCTION fn_count_customer_transactions_group(c_id BIGINT, id_group BIGINT) RETURNS NUMERIC AS $$
DECLARE first_group_purchase_date DATE := fn_get_first_date(c_id, id_group);
DECLARE last_group_purchase_date DATE := fn_get_last_date(c_id, id_group);
BEGIN
    RETURN (
    SELECT group_purchase
    FROM vw_periods AS p
    WHERE p.customer_id = c_id AND p.group_id = id_group    
    );
END;
$$ LANGUAGE plpgsql STABLE;
------ fn_count_customer_transactions_group END ------




------ fn_count_days --------
/*
 Возвращает  количество дней прошедших с даты последней транзакции по группе до даты проведения анализа
 (для столбца 4 Group_Churn_Rate)
 */
DROP FUNCTION
    IF EXISTS fn_count_days(c_id BIGINT, id_group BIGINT) CASCADE;

CREATE
OR REPLACE FUNCTION fn_count_days(c_id BIGINT, id_group BIGINT)
RETURNS NUMERIC
AS $$
DECLARE last_group_purchase_date TIMESTAMP := fn_get_last_date(c_id, id_group);
DECLARE date_analysis_formation TIMESTAMP := FN_Get_Date_Analysis();
BEGIN
    RETURN (
      SELECT EXTRACT (epoch FROM (
      date_analysis_formation - last_group_purchase_date ))/ 86400
    );
END;
$$ LANGUAGE plpgsql STABLE;

------ fn_count_days END ------



-------------------------fn_consumption_intervals-------------
/*
 Расчет интервалов потребления группы
 (для столбца 5)
 */
DROP FUNCTION
    IF EXISTS fn_consumption_intervals;

CREATE
OR REPLACE FUNCTION fn_consumption_intervals () RETURNS TABLE (
    customer_id INTEGER,
    group_id INTEGER,
    interval_all INTEGER
) AS $$
BEGIN
  RETURN QUERY
  WITH purchase_history AS (
    SELECT ph.customer_id, ph.group_id, ph.transaction_datetime
    FROM vw_purchase_history AS ph
    ORDER BY 1,2,3 DESC
  ),
  purchase_history2 AS (
  SELECT ph.customer_id,
    ph.group_id,
    ph.transaction_datetime,
    LAG(ph.transaction_datetime, 1) 
    OVER ( PARTITION BY ph.customer_id, ph.group_id
      ORDER BY ph.customer_id, ph.group_id) AS previous_datetime
  FROM purchase_history AS ph
  )
  SELECT ph2.customer_id, ph2.group_id,
    (ph2.previous_datetime::date - ph2.transaction_datetime::date)::INTEGER AS interval_all
  FROM purchase_history2 AS ph2;
END;
$$ LANGUAGE plpgsql STABLE;

------------------------fn_consumption_intervals END----------------
-------------- fn_relative_deviation --------------
/*
 Подсчет абсолютного отклонения каждого интервала от средней
 частоты покупок группы
 Подсчет относительного отклонения каждого интервала от средней
 частоты покупок группы
 (для столбца 5)
 */
DROP FUNCTION
    IF EXISTS fn_relative_deviation;

CREATE
OR REPLACE FUNCTION fn_relative_deviation() RETURNS TABLE (
    customer_id INTEGER,
    group_id INTEGER,
    relative_deviation NUMERIC
) AS $$
BEGIN
    RETURN QUERY
SELECT ci.customer_id, ci.group_id,
CASE WHEN ci.interval_all - p.group_frequency < 0 
       THEN -(ci.interval_all::numeric - p.group_frequency) / p.group_frequency
       ELSE (ci.interval_all::numeric - p.group_frequency) / p.group_frequency
END AS relative_deviation
FROM fn_consumption_intervals() AS ci
JOIN vw_periods AS p
ON ci.customer_id = p.customer_id
AND ci.group_id = p.group_id;
END;
$$ LANGUAGE plpgsql;

-----------------fn_relative_deviation END-------
---------------- fn_group_stability_index --------------
/*
 Определение стабильности потребления группы (столбец 5)
 */
DROP FUNCTION
    IF EXISTS fn_group_stability_index CASCADE;

CREATE
OR REPLACE FUNCTION fn_group_stability_index(id_customer INTEGER, id_group INTEGER)
RETURNS NUMERIC
AS $$
BEGIN
    RETURN 
    (SELECT  AVG(rd.relative_deviation) AS stability_index
    FROM fn_relative_deviation() AS rd
    WHERE rd.customer_id = id_customer
    AND rd.group_id = id_group
    GROUP BY rd.customer_id, rd.group_id);
END;
$$ LANGUAGE plpgsql;

-----------------fn_group_stability_index END-------
---------------------- fn_group_margin_transaction --------------
/*
 Расчет фактической маржи по транзакциям (для столбца 6)
 */
DROP FUNCTION
    IF EXISTS fn_group_margin_transaction;

CREATE
OR REPLACE FUNCTION fn_group_margin_transaction(parametr_count INTEGER, id_customer BIGINT, id_group BIGINT)
RETURNS NUMERIC
AS $$
DECLARE 
  count_trans INTEGER := 0;
  id_customer INTEGER;
  id_group INTEGER;
BEGIN
IF count_trans < parametr_count THEN
FOR id_customer, id_group 
IN SELECT p.customer_id, p.group_id FROM vw_periods AS p LOOP
  WHILE count_trans < parametr_count LOOP
          RETURN 
          (SELECT 
            SUM(ph.group_summ_paid - ph.group_cost::NUMERIC) AS Group_Margin
          FROM vw_purchase_history AS ph
          WHERE ph.customer_id = id_customer
          AND ph.group_id = id_group
          GROUP BY ph.customer_id, ph.group_id,ph.transaction_id
          LIMIT 1);
          count_trans := count_trans + 1;
  END LOOP;
END LOOP;
ELSE
  RETURN 0.0 AS Group_Margin;
END IF;
END;
$$ LANGUAGE plpgsql;
-----------------fn_group_margin_transaction END-------



---------------- fn_group_margin --------------
/*
 Расчет фактической маржи по группе (столбец 6)
 Входные праметры:
 calculation_method - метод расчета маржи:
 1 - метод расчета маржи по периоду,второй параметр
 указывает, за какое количество дней от даты формирования анализа в обратном
 хронологическом порядке необходимо рассчитать маржу
 2 - метод расчета маржи по количеству транзакций
 второй параметр указывает количество транзакций, для которых
 необходимо рассчитать маржу
 default - маржа рассчитывается для всех транзакций в рамках анализируемого периода
 parametr_count - количество дней(транзакций) 
 */
DROP FUNCTION
    IF EXISTS fn_group_margin;

CREATE
OR REPLACE FUNCTION fn_group_margin(
    calculation_method INTEGER,
    parametr_count INTEGER,
    id_customer INTEGER,
    id_group INTEGER)
RETURNS NUMERIC
AS $$
DECLARE 
  date_end DATE := FN_Get_Date_Analysis();
  date_start DATE := date_trunc('day', date_end) 
  - INTERVAL '1 days' * parametr_count;
BEGIN
    IF calculation_method = 1
    THEN
        RETURN
        (SELECT 
         SUM(ph.group_summ_paid - group_cost)::NUMERIC AS Group_Margin
        FROM vw_purchase_history AS ph
        WHERE ph.transaction_datetime BETWEEN date_start AND date_end
        AND ph.customer_id = id_customer
        AND ph.group_id = id_group
        GROUP BY ph.customer_id, ph.group_id);
    ELSIF calculation_method = 2
    THEN
        RETURN 
        (SELECT * FROM fn_group_margin_transaction(parametr_count, id_customer, id_group));
    ELSE
        RETURN 
        (SELECT 
         SUM(ph.group_summ_paid - group_cost)::NUMERIC AS Group_Margin
        FROM vw_purchase_history AS ph
        WHERE ph.transaction_datetime <= date_end
        AND ph.customer_id = id_customer
        AND ph.group_id = id_group
        GROUP BY ph.customer_id, ph.group_id);
    END IF;
END;
$$ LANGUAGE plpgsql;
-----------------fn_group_margin END-------




-------------------fn_count_transactions_discount------------
/*
 Определение количества транзакций клиента со скидкой по группе (для столбца 7)
 */
DROP FUNCTION
    IF EXISTS fn_count_transactions_discount;

CREATE
OR REPLACE FUNCTION fn_count_transactions_discount() RETURNS TABLE (
    customer_id INTEGER,
    group_id INTEGER,
    count_transactions BIGINT
) AS $$
BEGIN
    RETURN QUERY
    WITH cte AS (
      SELECT DISTINCT c2.customer_id, t.transaction_id, 
        pg.group_id
    FROM transaction AS t
    INNER JOIN checks AS c ON t.transaction_id = c.transaction_id
    INNER JOIN product_grid AS pg ON c.sku_id = pg.sku_id
    INNER JOIN cards AS c2 ON t.customer_card_id = c2.customer_card_id
    WHERE c.sku_discount <> 0
    )
    SELECT cte.customer_id, cte.group_id, COUNT(cte.transaction_id) AS count_transactions
    FROM cte
    GROUP BY cte.customer_id, cte.group_id;
END;
$$ LANGUAGE plpgsql;

-----------------fn_count_transactions_discount END-------
-------------------fn_all_count_transactions------------
/*
 Определение общего количества транзакций клиента  по группе (для столбца 7)
 */
DROP FUNCTION
    IF EXISTS fn_all_count_transactions;

CREATE
OR REPLACE FUNCTION fn_all_count_transactions() RETURNS TABLE (
    customer_id INTEGER,
    group_id INTEGER,
    count_transactions BIGINT
) AS $$
BEGIN
    RETURN QUERY
    WITH cte AS (
      SELECT DISTINCT c2.customer_id, t.transaction_id, 
        pg.group_id
    FROM transaction AS t
    INNER JOIN checks AS c ON t.transaction_id = c.transaction_id
    INNER JOIN product_grid AS pg ON c.sku_id = pg.sku_id
    INNER JOIN cards AS c2 ON t.customer_card_id = c2.customer_card_id
    )
    SELECT cte.customer_id, cte.group_id, COUNT(cte.transaction_id) AS count_transactions
    FROM cte
    GROUP BY cte.customer_id, cte.group_id;
END;
$$ LANGUAGE plpgsql;

-----------------fn_all_count_transactions END-------
-------------------fn_proportion_transactions_discount------------
/*
 Определение доли транзакций со скидкой по группе (столбец 7)
 */
DROP FUNCTION
    IF EXISTS fn_proportion_transactions_discount;

CREATE
OR REPLACE FUNCTION fn_proportion_transactions_discount(id_customer INTEGER,
    id_group INTEGER)
    RETURNS NUMERIC
    AS $$
BEGIN
    RETURN 
    (SELECT (d.count_transactions / n.count_transactions::NUMERIC) AS Group_Discount_Share
    FROM fn_count_transactions_discount() AS d 
    JOIN fn_all_count_transactions() AS n
    ON d.customer_id = n.customer_id AND d.group_id = n.group_id
    WHERE d.customer_id = id_customer
    AND d.group_id = id_group);
END;
$$ LANGUAGE plpgsql;

-----------------fn_proportion_transactions_discount END-------
-------------------fn_group_minimum_discount------------
/*
 Определение минимального размера скидки по группе. (столбец 8)
 */
DROP FUNCTION
    IF EXISTS fn_group_minimum_discount;

CREATE
OR REPLACE FUNCTION fn_group_minimum_discount(id_customer INTEGER, id_group INTEGER)
 RETURNS NUMERIC
 AS $$
BEGIN
    RETURN 
    (SELECT  d.group_min_discount::NUMERIC AS group_minimum_discount
    FROM vw_periods AS d
    WHERE d.customer_id = id_customer
    AND d.group_id = id_group);
END;
$$ LANGUAGE plpgsql;


-----------------fn_group_minimum_discount END-------



-------------------fn_group_average_discount------------
/*
 Определение среднего размера скидки по группе (столбец 9)
 */
DROP FUNCTION
    IF EXISTS fn_group_average_discount;

CREATE
OR REPLACE FUNCTION fn_group_average_discount(id_customer INTEGER, id_group INTEGER)
RETURNS NUMERIC
AS $$
BEGIN
    RETURN (SELECT SUM(group_summ_paid) / SUM(group_summ)
    FROM vw_purchase_history AS ph
    WHERE ph.customer_id = id_customer
    AND ph.group_id = id_group
    AND ph.transaction_datetime < FN_Get_Date_Analysis()
    GROUP BY ph.customer_id, ph.group_id);
END;
$$ LANGUAGE plpgsql;

-----------------fn_group_average_discount END-------
DROP VIEW
    IF EXISTS vw_groups CASCADE;

CREATE
OR REPLACE VIEW vw_groups AS (
    SELECT customer_id,
group_id,
fn_count_customer_transactions_group(p.customer_id, p.group_id) / fn_count_customer_transactions(p.customer_id, p.group_id) AS Group_Affinity_Index,
fn_count_days(p.customer_id, p.group_id) :: numeric / p.group_frequency :: numeric AS Group_Churn_Rate,
fn_group_stability_index(p.customer_id, p.group_id) AS Group_Stability_Index,
fn_group_margin(0,0,p.customer_id,p.group_id) AS Group_Margin,
fn_proportion_transactions_discount(p.customer_id, p.group_id) AS Group_Discount_Share,
fn_group_minimum_discount(p.customer_id, p.group_id) AS Group_Minimum_Discount,
fn_group_average_discount(p.customer_id, p.group_id) AS Group_Average_Discount
FROM vw_periods AS p
WHERE fn_count_customer_transactions(p.customer_id, p.group_id) > 0
);

SELECT * FROM vw_groups;

