-- Count orderbook
select
	count(o.ts)
from
	orderbook o;



-- Count Trades (Realtime)
select
	count(t.ts)
from
	trades t;



-- Count Stock_summary (EOL)
select
	count(ss.ts)
from
	stock_summary ss;