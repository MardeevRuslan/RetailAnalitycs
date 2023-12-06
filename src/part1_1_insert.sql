-------- INSERT --------
INSERT INTO sku_group (Group_Name) VALUES 
  ('Крупы'),
  ('Мясо'),
  ('Зелень'),
  ('Молочная продукция'),
  ('Алкоголь');


INSERT INTO product_grid (SKU_Name, GROUP_ID) VALUES 
  ('Рис', 1),
  ('Гречка', 1),
  ('Кускус', 1),
  ('Говядина', 2),
  ('Свинина', 2),
  ('Курица', 2),
  ('Укроп', 3),
  ('Петрушка', 3),
  ('Зеленый лук', 3),
  ('Ряженка', 4),
  ('Молоко', 4),
  ('Йогурт', 4),
  ('Виски', 5),
  ('Пиво', 5),
  ('Аппероль', 5);

INSERT INTO stores (
  SELECT 
  st,
  SKU_ID, 
  random() * 100 AS SKU_Purchase_Price,
  random() * 100 AS SKU_Retail_Price
  FROM product_grid
  CROSS JOIN generate_series(1, 5) AS st
);

------ INSERT Customer --------
CREATE PROCEDURE PR_GENERATE_CUSTOMERS()
AS $$
  BEGIN
    FOR i IN 1..20
    LOOP
      INSERT INTO personal_information (Customer_Name, Customer_Surname, Customer_Primary_Email, Customer_Primary_Phone)
      VALUES 
        ((substr(md5(random()::text), 1, 1) || 'bobo'), 
        (substr(md5(random()::text), 1, 1)|| 'abubu'), 
        (substr(md5(random()::text), 0, 10) || '@' || substr(md5(random()::text), 0, 10) || '.ru'),
        ('+' || CAST(20000000000 + floor(random() * 90000000000) AS TEXT)));
    END LOOP;
  END;
$$ LANGUAGE PLPGSQL;

CALL PR_GENERATE_CUSTOMERS();
------ INSERT Customer  END --------

------ INSERT cards --------
DELETE FROM cards;

CREATE PROCEDURE PR_GENERATE_CART()
AS $$
  BEGIN
    FOR i IN 1..20
    LOOP
      INSERT INTO cards (Customer_ID) 
      VALUES
        (CAST(floor(1 + random() * (SELECT max(Customer_ID) - 1 FROM personal_information)) AS BIGINT));
    END LOOP;
  END;
$$ LANGUAGE PLPGSQL;

CALL PR_GENERATE_CART();
------ INSERT cards END --------

------ INSERT "transaction" --------
DELETE FROM "transaction";

CREATE PROCEDURE PR_GENERATE_TRANSACTION()
AS $$
  BEGIN
    FOR i IN 0..50 
    LOOP
    INSERT INTO "transaction" (
      customer_card_id, Transaction_Summ, Transaction_DateTime, Transaction_Store_ID)
      VALUES (
        CAST(floor(1 + random() * (SELECT max(Customer_Card_ID) - 1 FROM cards)) AS BIGINT),
        CAST(floor(random() * 900000) AS FLOAT) * 0.943,
        timestamp '2022-01-20 20:00:00' + random() * (timestamp '2023-01-20 20:00:00' - timestamp '2023-01-10 10:00:00'),
        (1 + floor(random() * 5)))
      LIMIT floor(random() * 20);
    END LOOP;
  END;
$$ LANGUAGE PLPGSQL;

CALL PR_GENERATE_TRANSACTION();
------ INSERT "transaction" END --------


INSERT INTO checks(Transaction_ID, SKU_ID, SKU_Amount, SKU_Summ, SKU_Summ_Paid, SKU_Discount)
  SELECT 
  tr.Transaction_ID,
  tr.SKU_ID,
  tr.SKU_Amount,
  (tr.SKU_Amount * s.SKU_Retail_Price) AS SKU_Summ,
  (tr.SKU_Amount * s.SKU_Retail_Price * tr.Sale) AS SKU_Summ_Paid,
  (tr.SKU_Amount * s.SKU_Retail_Price * (1 - tr.Sale)) AS SKU_Discount
  FROM (
    SELECT 
    (1 + floor(random() * 5)) AS Transaction_ID,
    (1 + floor(random() * 14)) AS SKU_ID,
    (1 + floor(random() * 100)) AS SKU_Amount,
    (0.94 + random() * 0.06) AS Sale
    FROM "transaction") AS tr
  CROSS JOIN product_grid AS pg
  JOIN stores AS s ON s.SKU_ID = pg.SKU_ID;


INSERT INTO date_of_analysis (Analysis_Formation)
VALUES ('2022.01.20 20:00:00');