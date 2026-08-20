create or replace function get_order_status(p_order_id number) return varchar2 is
v_order_status varchar2(20);
begin 
select order_status into v_order_status from walmart_orders where order_id=p_order_id;
return v_order_status;
exception 
when no_data_found then 
return null;
when others then 
raise;
end;


create or replace function get_customer_total_spent(p_customer_id number)return number is
v_total_amount number;
begin 
select sum(total_amount) into v_total_amount from walmart_orders where customer_id=p_customer_id and order_status=
'CONFIRMED';
return NVL(v_total_amount, 0);
exception
when no_data_found then 
return 0;
when others then raise;
end;