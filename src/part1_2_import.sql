CREATE OR REPLACE FUNCTION import_table_to_csv(table_name TEXT)
    RETURNS VOID AS $$
DECLARE
    csv_file TEXT;
BEGIN
    csv_file := 
    '/Users/sommerha/SQL3_RetailAnalitycs_v1.0-1/src/' || 'import' || '/' ||
     table_name || '.tsv';  -- Имя TSV файла будет совпадать с именем таблицы
    EXECUTE format('COPY %I FROM %L WITH DELIMITER E''\t'' ', table_name, csv_file);
END; $$
LANGUAGE plpgsql;


CREATE OR REPLACE PROCEDURE TABLE_IMPORT()
AS $$
DECLARE
  tables_order_list VARCHAR[] := ARRAY[  
    'personal_information', 
    'cards',
    'sku_group',
    'transaction',
    'product_grid',
    'checks', 
    'stores', 
    'date_of_analysis'];
  table_name TEXT;
BEGIN
    -- Получаем список имен всех таблиц в текущей схеме
    FOREACH table_name IN ARRAY tables_order_list
    LOOP
        -- Выполняем импорт каждой таблицы в CSV
        EXECUTE 'SELECT import_table_to_csv(''' || table_name || ''')';
    END LOOP;
END; 
$$ LANGUAGE PLPGSQL;

SET datestyle = GERMAN, DMY;
CALL TABLE_IMPORT();
