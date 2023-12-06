CREATE OR REPLACE FUNCTION export_table_to_csv(table_name TEXT)
    RETURNS VOID AS $$
DECLARE
    csv_file TEXT;
BEGIN
    csv_file :=
    -- Тут нужно поменять путь на свой путь (я хз как сделать относительный путь)
    '/Users/hanalesh/work/SQL3_RetailAnalitycs_v1.0-1/src/'|| 'export' || '/' ||
     table_name || '.tsv';  -- Имя CSV файла будет совпадать с именем таблицы
    EXECUTE format('COPY %I TO %L WITH DELIMITER E''\t''', table_name, csv_file);
END; $$
LANGUAGE plpgsql;


CREATE OR REPLACE PROCEDURE TABLE_EXPORT()
AS $$
DECLARE
  table_name TEXT;
BEGIN
    -- Получаем список имен всех таблиц в текущей схеме
    FOR table_name IN SELECT ist.table_name FROM information_schema.tables AS ist WHERE table_schema = 'public' LOOP
        -- Выполняем экспорт каждой таблицы в CSV
        EXECUTE 'SELECT export_table_to_csv(''' || table_name || ''')';
    END LOOP;
END; 
$$ LANGUAGE PLPGSQL;

CALL TABLE_EXPORT();

