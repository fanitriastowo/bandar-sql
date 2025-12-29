-- public.orderbook definition

-- Drop table

-- DROP TABLE public.orderbook;

CREATE TABLE public.orderbook (
	ts timestamp NOT NULL,
	security_code varchar(10) NOT NULL,
	side bpchar(1) NOT NULL,
	"level" int4 NOT NULL,
	frequency int4 NOT NULL,
	price numeric(12, 2) NOT NULL,
	volume int8 NOT NULL,
	CONSTRAINT orderbook_pkey PRIMARY KEY (security_code, ts, side, level),
	CONSTRAINT orderbook_unique_key UNIQUE (security_code, ts, side, level)
);

CREATE INDEX idx_orderbook_code_side ON public.orderbook USING btree (security_code, side);
CREATE INDEX idx_orderbook_security_ts_desc ON public.orderbook USING btree (security_code, ts DESC);
CREATE INDEX idx_orderbook_symbol_ts ON public.orderbook USING btree (security_code, ts);
CREATE INDEX idx_orderbook_ts_date ON public.orderbook USING btree (((ts)::date));
CREATE INDEX idx_orderbook_ts_date_range ON public.orderbook USING btree (ts DESC);
CREATE INDEX idx_orderbook_ts_symbol_side ON public.orderbook USING btree (ts, security_code, side);
CREATE INDEX orderbook_ts_idx ON public.orderbook USING btree (ts DESC);

INSERT INTO orderbook (ts,security_code,side,"level",frequency,price,volume) VALUES
	 ('2025-11-25 23:00:25','DADA','O',1,1,49.00,50000),
	 ('2025-11-25 22:49:59','BKSL','B',1,20,126.00,29321),
	 ('2025-11-25 22:49:59','BKSL','B',2,487,125.00,226668),
	 ('2025-11-25 22:49:59','BKSL','B',3,258,124.00,170263),
	 ('2025-11-25 22:49:59','BKSL','B',4,165,123.00,127156),
	 ('2025-11-25 22:49:59','BKSL','B',5,183,122.00,180029),
	 ('2025-11-25 22:49:59','BKSL','B',6,115,121.00,131747),
	 ('2025-11-25 22:49:59','BKSL','B',7,238,120.00,288259),
	 ('2025-11-25 22:49:59','BKSL','B',8,55,119.00,59679),
	 ('2025-11-25 22:49:59','BKSL','B',9,47,118.00,20487);
