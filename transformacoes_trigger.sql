-- 1. Concatenar produto_id + descricao_produto e formatar data
SELECT 
    pc.pedido_id,
    pc.produto_id || ' - ' || pc.descricao_produto AS produto,
    TO_CHAR(pc.data_pedido, 'DD/MM/YYYY') AS data_solicitacao,
    SUM(pc.qtde_pedida) AS qtde_requisitada
FROM pedido_compra pc
GROUP BY pc.pedido_id, pc.produto_id, pc.descricao_produto, pc.data_pedido
HAVING SUM(pc.qtde_pedida) > 10
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
