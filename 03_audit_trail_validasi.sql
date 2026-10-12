
-- SOAL 3: AUDIT TRAIL
-- Menambahkan kolom audit pada header jurnal

ALTER TABLE journal_headers
ADD COLUMN IF NOT EXISTS created_by UUID;

ALTER TABLE journal_headers
ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ
DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE journal_headers
ADD COLUMN IF NOT EXISTS hash_checksum TEXT;


-- 1. FUNCTION PROTEKSI HEADER JURNAL

CREATE OR REPLACE FUNCTION prevent_posted_journal_change()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF OLD.posting_status = 'POSTED' THEN
        RAISE EXCEPTION
        'Jurnal POSTED tidak boleh diubah/dihapus langsung. Gunakan jurnal koreksi/pembalik.';
    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;

    RETURN NEW;
END;
$$;


-- TRIGGER PROTEKSI UPDATE DAN DELETE HEADER

DROP TRIGGER IF EXISTS trg_prevent_posted_update
ON journal_headers;

CREATE TRIGGER trg_prevent_posted_update
BEFORE UPDATE ON journal_headers
FOR EACH ROW
EXECUTE FUNCTION prevent_posted_journal_change();


DROP TRIGGER IF EXISTS trg_prevent_posted_delete
ON journal_headers;

CREATE TRIGGER trg_prevent_posted_delete
BEFORE DELETE ON journal_headers
FOR EACH ROW
EXECUTE FUNCTION prevent_posted_journal_change();


-- 2. FUNCTION PROTEKSI BARIS JURNAL

CREATE OR REPLACE FUNCTION prevent_posted_journal_line_change()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_status VARCHAR(10);
BEGIN
    IF TG_OP = 'INSERT' THEN
        SELECT posting_status
        INTO v_status
        FROM journal_headers
        WHERE id = NEW.header_id
        FOR UPDATE;
    ELSE
        SELECT posting_status
        INTO v_status
        FROM journal_headers
        WHERE id = OLD.header_id
        FOR UPDATE;
    END IF;

    IF v_status = 'POSTED' THEN
        RAISE EXCEPTION
        'Baris jurnal POSTED tidak boleh diubah atau dihapus langsung.';
    END IF;

    IF TG_OP = 'UPDATE'
       AND NEW.header_id IS DISTINCT FROM OLD.header_id THEN

        SELECT posting_status
        INTO v_status
        FROM journal_headers
        WHERE id = NEW.header_id
        FOR UPDATE;

        IF v_status = 'POSTED' THEN
            RAISE EXCEPTION
            'Baris tidak boleh dipindahkan ke jurnal POSTED.';
        END IF;
    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;

    RETURN NEW;
END;
$$;


-- TRIGGER PROTEKSI BARIS JURNAL

DROP TRIGGER IF EXISTS trg_protect_posted_journal_lines
ON journal_lines;

CREATE TRIGGER trg_protect_posted_journal_lines
BEFORE INSERT OR UPDATE OR DELETE ON journal_lines
FOR EACH ROW
EXECUTE FUNCTION prevent_posted_journal_line_change();


-- 3. FUNCTION VALIDASI SEBELUM POSTING

CREATE OR REPLACE FUNCTION validate_journal_before_posting()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_line_count BIGINT;
    v_total_debit NUMERIC(15,2);
    v_total_credit NUMERIC(15,2);
BEGIN
    IF NEW.posting_status = 'POSTED'
       AND OLD.posting_status IS DISTINCT FROM 'POSTED' THEN

        SELECT COUNT(*),
               COALESCE(SUM(debit), 0),
               COALESCE(SUM(credit), 0)
        INTO v_line_count, v_total_debit, v_total_credit
        FROM journal_lines
        WHERE header_id = NEW.id;

        IF v_line_count = 0 THEN
            RAISE EXCEPTION
            'Jurnal tidak dapat diposting tanpa baris jurnal.';
        END IF;

        IF v_total_debit <> v_total_credit THEN
            RAISE EXCEPTION
            'Jurnal tidak seimbang. Total debit: %, total kredit: %',
            v_total_debit, v_total_credit;
        END IF;

        IF v_total_debit <= 0 THEN
            RAISE EXCEPTION
            'Total debit dan kredit harus lebih dari nol.';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;


-- TRIGGER VALIDASI SEBELUM POSTING

DROP TRIGGER IF EXISTS trg_validate_journal_before_posting
ON journal_headers;

CREATE TRIGGER trg_validate_journal_before_posting
BEFORE UPDATE OF posting_status
ON journal_headers
FOR EACH ROW
EXECUTE FUNCTION validate_journal_before_posting();
