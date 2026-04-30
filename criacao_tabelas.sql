CREATE TABLE public.venda(
	venda_id int8 NOT NULL,
	data_emissao date NOT NULL,
	horariomov varchar(8) DEFAULT '00:00:00' NOT NULL,
	produto_id varchar(25) DEFAULT '' NOT NULL,
	qtde_vendida float8 NULL,
	valor_unitario numeric(12, 4) DEFAULT 0 NOT NULL,
	filial_id int8 DEFAULT 1 NOT NULL,
	item int4 DEFAULT 0 NOT NULL,
	unidade_medida varchar(3) NULL,
	CONSTRAINT pk_consumo PRIMARY KEY (filial_id, venda_id, data_emissao, produto_id, item, horariomov)
);

CREATE TABLE public.pedido_compra(
	pedido_id float8 DEFAULT 0 NOT NULL,
	data_pedido date NULL,
	item float8 DEFAULT 0 NOT NULL,
	produto_id varchar(25) DEFAULT '0' NOT NULL,
	descricao_produto varchar(255) NULL,
	ordem_compra float8 DEFAULT 0 NOT NULL,
	qtde_pedida float8 NULL,
	filial_id int4 NULL,
	data_entrega date NULL,
	qtde_entregue float8 DEFAULT 0 NOT NULL,
	qtde_pendente float8 DEFAULT 0 NOT NULL,
	preco_compra float8 DEFAULT 0 NULL,
	fornecedor_id int4 DEFAULT 0 NULL,
	CONSTRAINT pedido_compra_pkey PRIMARY KEY (pedido_id, produto_id, item)
);

CREATE TABLE public.entradas_mercadoria (
	data_entrada date NULL,
	nro_nfe varchar(255) NOT NULL,
	item float8 DEFAULT 0 NOT NULL,
	produto_id varchar(25) DEFAULT '0' NOT NULL,
	descricao_produto varchar(255) NULL,
	qtde_recebida float8 NULL,
	filial_id int4 NULL,
	custo_unitario numeric(12, 4) DEFAULT 0 NOT NULL,
	ordem_compra float8 DEFAULT 0 NOT NULL,
	CONSTRAINT entradas_mercadoria_pkey PRIMARY KEY (ordem_compra, item, produto_id, nro_nfe)
);

CREATE TABLE public.fornecedor(
	idforncedor varchar(25) NOT NULL,
	razao_social varchar(255) NOT NULL,
	CONSTRAINT fornecedor_pkey PRIMARY KEY (idforncedor)
);

CREATE TABLE public.produtos_filial(
	filial_id int4 NULL,
	produto_id varchar(255) NOT NULL,
	descricao varchar(255) NOT NULL,
	estoque float8 DEFAULT 0 NOT NULL,
	preco_unitario float8 DEFAULT 0 NOT NULL,
	preco_compra float8 DEFAULT 0 NOT NULL,
	preco_venda float8 DEFAULT 0 NOT NULL,
	idfonecedor int4 NULL,
	CONSTRAINT produtos_filial_pkey PRIMARY KEY (filial_id, produto_id)
);

SELECT * FROM fornecedor;

SELECT * FROM produtos_filial;

ALTER TABLE produtos_filial ALTER COLUMN idfonecedor TYPE varchar(25);

SELECT * FROM pedido_compra;

ALTER TABLE pedido_compra ALTER COLUMN filial_id TYPE float8;

ALTER TABLE pedido_compra ADD COLUMN qtde_pendente float8 DEFAULT 0;

ALTER TABLE pedido_compra ALTER COLUMN fornecedor_id TYPE float8;

SELECT 
    v.produto_id,
    p.descricao,
    SUM(v.qtde_vendida) AS total_quantidade,
    SUM(v.qtde_vendida * v.valor_unitario) AS total_valor
FROM venda v
JOIN produtos_filial p ON v.produto_id = p.produto_id
WHERE EXTRACT(MONTH FROM v.data_emissao) = 2
AND EXTRACT(YEAR FROM v.data_emissao) = 2025
GROUP BY v.produto_id, p.descricao
ORDER BY total_valor DESC;

SELECT pedido_id, data_pedido, produto_id, descricao_produto, ordem_compra, qtde_pedida
FROM pedido_compra
WHERE ordem_compra NOT IN (
    SELECT ordem_compra FROM entradas_mercadoria);

