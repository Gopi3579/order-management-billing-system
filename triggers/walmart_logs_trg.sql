create or replace TRIGGER walmart_logs_trg
AFTER INSERT OR DELETE OR UPDATE ON walmart_orders
FOR EACH ROW
DECLARE
    v_dml_type VARCHAR2(20);
    v_order_id walmart_orders.order_id%TYPE;
BEGIN
    IF INSERTING THEN
        v_dml_type := 'INSERT';
        v_order_id := :NEW.order_id;
    ELSIF DELETING THEN
        v_dml_type := 'DELETE';
        v_order_id := :OLD.order_id;
    ELSIF UPDATING THEN
        v_dml_type := 'UPDATE';
        v_order_id := :NEW.order_id;
    END IF;

    INSERT INTO walmart_logs (log_id, order_id, action, old_status, new_status, changed_by, changed_on)
    VALUES (walmart_logs_sequence.NEXTVAL, v_order_id, v_dml_type, :OLD.order_status, :NEW.order_status, USER, SYSDATE);
END;