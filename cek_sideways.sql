select
	*
from
	sideways_state
where
	trade_date = (
	select
		MAX(trade_date)
	from
		sideways_state)
	and is_sideways = true
order by
	range_ratio asc;