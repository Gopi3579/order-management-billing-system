create or replace PROCEDURE batch_cancel_stale_orders IS
TYPE t_order_ids IS TABLE OF WALMART_ORDERS.ORDER_ID%TYPE;
V_ORDER_IDS T_ORDER_IDS;
BEGIN 
SELECT ORDER_ID BULK COLLECT INTO V_ORDER_IDS FROM WALMART_ORDERS WHERE ORDER_STATUS = 'PENDING' AND SYSDATE-ORDER_DATE>1;
FOR  I IN 1..V_ORDER_IDS.COUNT LOOP
CANCEL_ORDER(V_ORDER_IDS(i));
END LOOP;
END;

create or replace PROCEDURE cancel_order(P_ORDER_ID NUMBER) IS 
TYPE BCEMP IS RECORD(P_ORDER_STATUS WALMART_ORDERS.ORDER_STATUS%TYPE,P_ORDER_QUANTITY WALMART_ORDERITEMS.ORDER_QUANTITY%TYPE
,P_STOCK_QUANTITY WALMART_PRODUCTS.STOCK_QUANTITY%TYPE,P_PRODUCT_ID WALMART_PRODUCTS.PRODUCT_ID%TYPE);
TYPE DCEMP IS TABLE OF  BCEMP;
FCEMP DCEMP;
BEGIN 
SELECT O.ORDER_STATUS,OI.ORDER_QUANTITY,P.STOCK_QUANTITY,P.PRODUCT_ID BULK COLLECT INTO FCEMP FROM WALMART_ORDERS O JOIN 
WALMART_ORDERITEMS OI ON O.ORDER_ID=OI.ORDER_ID
JOIN WALMART_PRODUCTS P ON OI.PRODUCT_ID=P.PRODUCT_ID WHERE O.ORDER_ID=P_ORDER_ID AND O.ORDER_STATUS<>'CANCELLED';
FORALL I IN 1..FCEMP.COUNT 
UPDATE 
WALMART_PRODUCTS P SET STOCK_QUANTITY=STOCK_QUANTITY+FCEMP(I).P_ORDER_QUANTITY WHERE P.PRODUCT_ID=FCEMP(I).P_PRODUCT_ID;
UPDATE WALMART_ORDERS SET ORDER_STATUS = 'CANCELLED' WHERE ORDER_ID = P_ORDER_ID;
END;

create or replace PROCEDURE confirm_order(p_order_id number) IS
type gcemp is record(P_ORDER_STATUS WALMART_ORDERS.ORDER_STATUS%TYPE,P_ORDER_QUANTITY WALMART_ORDERITEMS.ORDER_QUANTITY%TYPE
,P_STOCK_QUANTITY WALMART_PRODUCTS.STOCK_QUANTITY%TYPE,P_PRODUCT_ID WALMART_PRODUCTS.PRODUCT_ID%TYPE);
type hcemp is table of gcemp;
icemp hcemp;
begin 
validate_order_stock (p_order_id);
SELECT O.ORDER_STATUS,OI.ORDER_QUANTITY,P.STOCK_QUANTITY,P.PRODUCT_ID BULK COLLECT INTO ICEMP FROM WALMART_ORDERS O JOIN 
WALMART_ORDERITEMS OI ON O.ORDER_ID=OI.ORDER_ID
JOIN WALMART_PRODUCTS P ON OI.PRODUCT_ID=P.PRODUCT_ID WHERE O.ORDER_ID=P_ORDER_ID AND O.ORDER_STATUS<>'CONFIRMED';
--select * from user_constraints where table_name='WALMART_ORDERS'--
FORALL I IN 1..ICEMP.COUNT UPDATE 
WALMART_PRODUCTS P SET STOCK_QUANTITY=STOCK_QUANTITY-ICEMP(I).P_ORDER_QUANTITY WHERE P.PRODUCT_ID=ICEMP(I).P_PRODUCT_ID;
UPDATE WALMART_ORDERS SET ORDER_STATUS = 'CONFIRMED' WHERE ORDER_ID = P_ORDER_ID;
END;

create or replace PROCEDURE CREATE_WALMART_ORDER(P_CUSTOMER_ID NUMBER)IS 
BEGIN 
VALIDATE_CUSTOMER_ACTIVE(P_CUSTOMER_ID);
INSERT INTO WALMART_ORDERS(order_id, customer_id, order_date, order_status, total_amount)
VALUES(CREATE_WALMART_ORDERS_SEQ.NEXTVAL,P_CUSTOMER_ID,SYSDATE,'PENDING',0);
END;

create or replace procedure validate_customer_active(p_customer_id number) is
vaccount_status varchar2(30);
begin 
select account_status into vaccount_status from walmart_customers where customer_id=p_customer_id;
if not vaccount_status ='ACTIVE' THEN
raise_application_error(-20002,'account_not_active_please_activate_before_placing_order');
end if;
exception 
when no_data_found then
raise_application_error(-20003,'new_customer_please_create_account');
end;

create or replace procedure validate_order_stock(p_order_id number) is
type cemp is record(p_product_name walmart_products.product_name%type,p_order_quantity walmart_orderitems.order_quantity%type,
p_stock_quantity walmart_products.stock_quantity%type);
type acemp is table of cemp;
vcemp acemp;
begin 
select pi.product_name,oi.order_quantity,pi.stock_quantity bulk collect into vcemp from walmart_orderitems oi join
walmart_products pi on oi.product_id=pi.product_id where oi.order_id=p_order_id;
for i in 1..vcemp.count loop
if vcemp(i).p_order_quantity>vcemp(i).p_stock_quantity then 
raise_application_error
(-20001,'only'||' '||vcemp(i).p_stock_quantity||' ' ||'are_left'||' '||'with_product_name'||' '||vcemp(i).p_product_name);
end if;
end loop;
end;


create or replace procedure validate_payment_amount(p_order_id number, p_payment_amount number) is
vsum number;
begin 
select total_amount into vsum from walmart_orders where order_id=p_order_id;
if vsum<>p_payment_amount
then raise_application_error(-20004,'payment amount does not match order total');
end if;
end;