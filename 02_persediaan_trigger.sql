
-- SOAL 2: TABEL PERSEDIAAN

CREATE TABLE IF NOT EXISTS inventory_items (
    item_id VARCHAR(10) PRIMARY KEY,
    item_name VARCHAR(100),
    stock_qty INT NOT NULL DEFAULT 0,
    unit_cost NUMERIC(15, 2) NOT NULL
);

CREATE TABLE IF NOT EXISTS inventory_transactions (
    trx_id SERIAL PRIMARY KEY,
    item_id VARCHAR(10) REFERENCES inventory_items(item_id),
    trx_type VARCHAR(10)
        CHECK (trx_type IN ('PURCHASE', 'SALE', 'ADJUSTMENT')),
    qty INT NOT NULL,
    trx_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- FUNCTION UNTUK MEMPERBARUI STOK

CREATE OR REPLACE FUNCTION trg_update_stock_and_journal()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    current_stock INT;
    new_stock INT;
BEGIN
    IF NEW.trx_type IN ('PURCHASE', 'SALE') AND NEW.qty <= 0 THEN
        RAISE EXCEPTION 'Kuantitas pembelian/penjualan harus lebih dari 0';
    END IF;

    SELECT stock_qty
    INTO current_stock
    FROM inventory_items
    WHERE item_id = NEW.item_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Barang dengan ID % tidak ditemukan', NEW.item_id;
    END IF;

    IF NEW.trx_type = 'PURCHASE' THEN
        new_stock := current_stock + NEW.qty;
    ELSIF NEW.trx_type = 'SALE' THEN
        new_stock := current_stock - NEW.qty;
    ELSIF NEW.trx_type = 'ADJUSTMENT' THEN
        new_stock := current_stock + NEW.qty;
    ELSE
        RAISE EXCEPTION 'Jenis transaksi tidak valid';
    END IF;

    IF new_stock < 0 THEN
        RAISE EXCEPTION
            'Stok tidak cukup. Stok tersedia: %, diminta: %',
            current_stock, NEW.qty;
    END IF;

    UPDATE inventory_items
    SET stock_qty = new_stock
    WHERE item_id = NEW.item_id;

    RETURN NEW;
END;
$$;

-- TRIGGER OTOMATIS

DROP TRIGGER IF EXISTS trg_inventory_stock
ON inventory_transactions;

CREATE TRIGGER trg_inventory_stock
AFTER INSERT ON inventory_transactions
FOR EACH ROW
EXECUTE FUNCTION trg_update_stock_and_journal();
