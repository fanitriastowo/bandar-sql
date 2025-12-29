-- public.stock_fundamentals definition

-- Drop table

-- DROP TABLE public.stock_fundamentals;

CREATE TABLE public.stock_fundamentals (
	security_code text NOT NULL,
	shares_outstanding int8 NOT NULL,
	last_updated date NOT NULL,
	"source" text NULL,
	CONSTRAINT stock_fundamentals_pkey PRIMARY KEY (security_code)
);

INSERT INTO public.stock_fundamentals (security_code,shares_outstanding,last_updated,"source") VALUES
	 ('BBRI',124186187163,'2024-12-31','Annual Report 2024'),
	 ('BBCA',24217088667,'2024-12-31','Annual Report 2024'),
	 ('BMRI',86034524425,'2024-12-31','Annual Report 2024'),
	 ('BBNI',17392920370,'2024-12-31','Annual Report 2024'),
	 ('ASII',40484000000,'2024-12-31','Annual Report 2024'),
	 ('UNTR',3730313322,'2024-12-31','Annual Report 2024'),
	 ('TLKM',99766326000,'2024-12-31','Annual Report 2024'),
	 ('EXCL',26446363703,'2024-12-31','Annual Report 2024'),
	 ('UNVR',7630000000,'2024-12-31','Annual Report 2024'),
	 ('ICBP',3681231699,'2024-12-31','Annual Report 2024');
INSERT INTO public.stock_fundamentals (security_code,shares_outstanding,last_updated,"source") VALUES
	 ('PTBA',3230000000,'2024-12-31','Annual Report 2024'),
	 ('ADRO',31985962000,'2024-12-31','Annual Report 2024'),
	 ('GOTO',75000000000,'2024-12-31','IPO Prospectus'),
	 ('AMMN',7584000000,'2024-12-31','Annual Report 2024');

