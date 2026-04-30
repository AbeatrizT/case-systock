-- 1. Concatenar produto_id + descricao_produto, formatar data
--    e filtrar produtos requisitados mais de 10 vezes no período
SELECT 
    produto_id || ' - ' || descricao_produto AS produto,
    TO_CHAR(MIN(data_pedido), 'DD/MM/YYYY') AS data_solicitacao,
    SUM(qtde_pedida) AS qtde_requisitada
FROM pedido_compra
GROUP BY produto_id, descricao_produto
HAVING SUM(qtde_pedida) > 10
ORDER BY qtde_requisitada DESC;

-- 2. Trigger que gera idfornecedor numérico automaticamente
CREATE SEQUENCE seq_idfornecedor START 1;

CREATE OR REPLACE FUNCTION gerar_idfornecedor()
RETURNS TRIGGER AS $$
BEGIN
    NEW.idfonecedor := nextval('seq_idfornecedor');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_idfornecedor
BEFORE INSERT ON produtos_filial
FOR EACH ROW
EXECUTE FUNCTION gerar_idfornecedor();

INSERT INTO produtos_filial (filial_id, produto_id, descricao, estoque, preco_unitario, preco_compra, preco_venda)
VALUES (1, 'P99', 'Produto Teste Trigger', 10, 50.00, 30.00, 70.00);

SELECT produto_id, descricao, idfonecedor FROM produtos_filial WHERE produto_id = 'P99';

DELETE FROM produtos_filial WHERE produto_id = 'P99';