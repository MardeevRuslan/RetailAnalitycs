-- Part 1 Создание базы данных --

-- Напишите скрипт *part1.sql*, создающий базу данных и таблицы, описанные выше в разделе [входные данные](#входные-данные).

-- Также внесите в скрипт процедуры, позволяющие импортировать и экспортировать данные для каждой таблицы из файлов/в файлы с расширением *.csv* и *.tsv*. \
-- В качестве параметра каждой процедуры для импорта из *csv* файла указывается разделитель.

-- В каждую из таблиц внесите как минимум по 5 записей.
-- По мере выполнения задания вам потребуются новые данные, чтобы проверить все варианты работы.
-- Эти новые данные также должны быть добавлены в этом скрипте. \
-- Некоторые тестовые данные могут быть найдены в папке *datasets*.

-- Если для добавления данных в таблицы использовались *csv* или *tsv* файлы, они также должны быть выгружены в GIT репозиторий.

-------- DROP --------
DROP DOMAIN IF EXISTS email_domain, phone_domain CASCADE;

DROP PROCEDURE IF EXISTS PR_GENERATE_TRANSACTION CASCADE;
DROP PROCEDURE IF EXISTS PR_GENERATE_CART CASCADE;
DROP PROCEDURE IF EXISTS PR_GENERATE_CUSTOMERS CASCADE;

DROP TABLE IF EXISTS "transaction" CASCADE;
DROP TABLE IF EXISTS checks CASCADE;


DROP TABLE IF EXISTS 
  personal_information, 
  cards, 
  "transaction", 
  checks, 
  product_grid, 
  stores, 
  sku_group,
  date_of_analysis
CASCADE;
-------- DROP END --------



-------- DOMAIN --------
CREATE DOMAIN phone_domain AS TEXT
CHECK(
   VALUE ~ '^((8|\+[0-9])[\- ]?)?(\(?\d{3}\)?[\- ]?)?[\d\- ]{7,10}$'
);

CREATE DOMAIN email_domain AS TEXT
CHECK(
   VALUE ~ '^[a-zA-Z0-9_]+@[a-zA-Z0-9_]+?\.[a-zA-Z]{2,3}$'
);
-------- DOMAIN END--------


-------- TABLES --------
CREATE TABLE IF NOT EXISTS
  date_of_analysis (
    Analysis_Formation timestamp without time zone
  );


CREATE TABLE IF NOT EXISTS
  sku_group(
    Group_ID SERIAL PRIMARY KEY,
    Group_Name VARCHAR CHECK (
      Group_Name ~ '[[:alnum:][:cntrl:]]'
    )
  );

CREATE TABLE IF NOT EXISTS
  product_grid(
    SKU_ID SERIAL PRIMARY KEY,
    SKU_Name VARCHAR CHECK (
      SKU_Name ~ '[[:alnum:][:cntrl:]]'
    ),
    GROUP_ID SERIAL REFERENCES sku_group(Group_ID)
  );
  
CREATE TABLE IF NOT EXISTS
  stores(
    Transaction_Store_ID INT NOT NULL,
    SKU_ID SERIAL NOT NULL REFERENCES product_grid(SKU_ID),
    SKU_Purchase_Price FLOAT CHECK (
      SKU_Purchase_Price > 0
    ),
    SKU_Retail_Price FLOAT CHECK (
      SKU_Retail_Price > 0
    ),
    UNIQUE (Transaction_Store_ID, SKU_ID)
  );

CREATE TABLE IF NOT EXISTS
  personal_information(
    Customer_ID SERIAL PRIMARY KEY,
    Customer_Name VARCHAR 
    CHECK (
      Customer_Name ~ '[[:alnum:]]'
    ),
    Customer_Surname VARCHAR,
    Customer_Primary_Email email_domain,
    Customer_Primary_Phone phone_domain
  );

CREATE TABLE IF NOT EXISTS
  cards(
    Customer_Card_ID SERIAL PRIMARY KEY,
    Customer_ID SERIAL REFERENCES personal_information(Customer_ID)
  );

CREATE TABLE IF NOT EXISTS
  "transaction"(
    Transaction_ID SERIAL PRIMARY KEY,
    Customer_Card_ID SERIAL REFERENCES cards(Customer_Card_ID),
    Transaction_Summ NUMERIC,
    Transaction_DateTime timestamp NOT NULL,
    Transaction_Store_ID INT
  );

CREATE TABLE IF NOT EXISTS
  checks(
    Transaction_ID SERIAL REFERENCES "transaction"(Transaction_ID),
    SKU_ID SERIAL REFERENCES product_grid(SKU_ID),
    SKU_Amount FLOAT NOT NULL,
    SKU_Summ FLOAT NOT NULL,
    SKU_Summ_Paid FLOAT NOT NULL,
    SKU_Discount FLOAT
  );
-------- TABLES END --------
