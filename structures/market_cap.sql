CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE market_cap (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT,
  listed_stocks TEXT,
  number_of_listed_shares BIGINT,
  market_capitalization BIGINT,
  percentage NUMERIC,
  month INTEGER,
  year INTEGER
);


INSERT INTO public.market_cap (id,code,listed_stocks,number_of_listed_shares,market_capitalization,percentage,"month","year") VALUES
	 ('bd7163d8-c4ef-4db1-b80e-4ef471d01abe'::uuid,'BBCA','Bank Central Asia Tbk.',122042299500,1104482810,11.28,4,2023),
	 ('3751600a-6967-48b4-ac69-1e8ffd2d3e1c'::uuid,'BBRI','PT Bank Rakyat Indonesia (Persero) Tbk',150043411587,765221399,7.82,4,2023),
	 ('cf635b25-8ca2-4d17-9185-5f8090c6da9d'::uuid,'BYAN','Bayan Resources Tbk',33333335000,716666703,7.32,4,2023),
	 ('88475248-47fe-4fb2-816f-824d78abe415'::uuid,'BMRI','Bank Mandiri (Persero) Tbk.',92399999996,478170000,4.88,4,2023),
	 ('b208ee5f-667a-4c7b-8938-62cfb33393a5'::uuid,'TLKM','Telkom Indonesia (Persero) Tbk.',99062216600,421014421,4.3,4,2023),
	 ('ce6a9a61-c362-4716-a3e9-b9523cdb7b2d'::uuid,'ASII','Astra International Tbk',40483553140,273263984,2.79,4,2023),
	 ('d6262c98-18cd-445f-9f90-39aba8398ffd'::uuid,'TPIA','PT Chandra Asri Pacific Tbk',86511545092,204167246,2.09,4,2023),
	 ('56232de4-25af-4cce-a61c-bb4afa04b9ba'::uuid,'BBNI','PT Bank Negara Indonesia (Persero) Tbk',18462169893,174005951,1.78,4,2023),
	 ('412e537b-db01-4de6-86b5-cc3ac7ec9f83'::uuid,'UNVR','Unilever Indonesia Tbk.',38150000000,167860000,1.71,4,2023),
	 ('9778c893-f091-4e49-815c-4ad7b2b4670a'::uuid,'ICBP','Indofood CBP Sukses Makmur Tbk',11661908000,123324677,1.26,4,2023);
