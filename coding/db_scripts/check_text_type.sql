create or replace function check_text_type(srcTxt text) returns boolean 
as $$
declare
    vCheckTxt float;
begin
    raise notice 'Check executing...';

    select to_number(srcTxt, '99G999D9S') into vCheckTxt;

    raise notice 'Well done!';
    
	return true;
exception
    when invalid_text_representation then
        raise notice 'It was text, not number.';
        return false;

end;
$$ language plpgsql;