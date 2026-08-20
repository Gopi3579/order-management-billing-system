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