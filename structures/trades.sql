-- public.trades definition

-- Drop table

-- DROP TABLE public.trades;

CREATE TABLE public.trades (
	trade_no int8 NOT NULL,
	trade_date bpchar(8) NOT NULL,
	trade_time bpchar(6) NOT NULL,
	ts timestamp NOT NULL,
	security_code varchar(10) NOT NULL,
	board_code varchar(2) NOT NULL,
	price numeric(12, 2) NOT NULL,
	volume int8 NOT NULL,
	CONSTRAINT trades_pkey PRIMARY KEY (trade_no, ts),
	CONSTRAINT trades_trade_no_key UNIQUE (trade_no)
);

CREATE INDEX idx_trades_symbol_ts ON public.trades USING btree (security_code, ts);
CREATE INDEX idx_trades_ts_symbol ON public.trades USING btree (ts, security_code);

INSERT INTO trades (trade_no,trade_date,trade_time,ts,security_code,board_code,price,volume) VALUES
	 (3129600,'20251111','162854','2025-11-11 23:28:54','BBRI','NG',3890.00,9300),
	 (3129599,'20251111','162833','2025-11-11 23:28:33','BBCA','NG',8400.00,1000),
	 (3129598,'20251111','162109','2025-11-11 23:21:09','BBCA','NG',8410.00,16590000),
	 (3129597,'20251111','162109','2025-11-11 23:21:09','BBCA','NG',8410.00,14330000),
	 (3129596,'20251111','162109','2025-11-11 23:21:09','BBCA','NG',8410.00,3320000),
	 (3129595,'20251111','162109','2025-11-11 23:21:09','BBCA','NG',8410.00,21590000),
	 (3129594,'20251111','162109','2025-11-11 23:21:09','BBCA','NG',8410.00,2170000),
	 (3129593,'20251111','162032','2025-11-11 23:20:32','ISAT','NG',2164.00,12180000),
	 (3129592,'20251111','162032','2025-11-11 23:20:32','ISAT','NG',2164.00,16340000),
	 (3129591,'20251111','162032','2025-11-11 23:20:32','ISAT','NG',2164.00,1330000);

