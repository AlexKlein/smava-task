create or replace procedure order_upload ()
as $$
declare
    vOrderUk integer;          -- Unique Key of new row in Order Hub
    r public."order"%rowtype;  -- rows of Order query
	
	cOrders cursor for 
		select * from public."order";
begin
    -- clean up all tables with temporary data
	truncate hub_order_delta;
	truncate sat_order_date_delta;
	truncate sat_order_item_delta;
	
	-- upload hub and satellite tables
	for r in cOrders loop
		-- new unique key for order row getting
		vOrderUk := nextval('public.s_hub_order');
		
		insert into hub_order_delta (uk,
									 load_date,
									 record_source,
									 order_id) values (vOrderUk,
										 			   current_date,
													   'External Excel. Order',
													   r.order_id);
		insert into sat_order_date_delta (order_uk,
									      load_date,
									      record_source,
									      order_date) values (vOrderUk,
													 	      current_date,
														      'External Excel. Order',
														      r.order_date);
		insert into sat_order_item_delta (order_uk,
									      load_date,
									      record_source,
									      total,
										  item_count) values (vOrderUk,
													 	      current_date,
														      'External Excel. Order',
														      r.total,
															  r.item_count);
    end loop;
	commit;
    
	-- upload data in target tables
	call upload ('public',
				 'hub_order_delta',
				 'public',
				 'hub_order',
			 	 1);
	call upload ('public',
				 'sat_order_date_delta',
				 'public',
				 'sat_order_date',
				 2);
	call upload ('public',
				 'sat_order_item_delta',
				 'public',
				 'sat_order_item',
				 2);
end;
$$ language plpgsql;