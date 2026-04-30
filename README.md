# Case Técnico – Analista de Integração de Dados | Systock

## Tecnologias Utilizadas
- PostgreSQL 16
- pgAdmin 4

---

## Parte 1 – Documentação do Processo de Importação

### Ferramenta utilizada
A importação foi realizada em duas etapas:
1. **pgAdmin 4 (Import/Export)** para tentativa de importação direta do CSV — processo que evidenciou incompatibilidades de tipos de dados entre a planilha e as DDLs fornecidas
2. **Scripts SQL (INSERT)** para garantir controle total sobre os tipos e valores inseridos no banco PostgreSQL 16

### Estrutura da planilha
A planilha `base_teste_systock.xlsx` continha 5 abas, cada uma correspondendo a uma tabela do banco:

| Aba | Registros | Colunas principais |
|---|---|---|
| venda | 33 | venda_id, data_emissao, produto_id, qtde_vendida, valor_unitario |
| pedido_compra | 29 | pedido_id, data_pedido, produto_id, ordem_compra, qtde_pedida |
| entradas_mercadoria | 20 | nro_nfe, data_entrada, produto_id, ordem_compra, qtde_recebida |
| produtos_filial | 20 | produto_id, descricao, estoque, preco_venda, idfornecedor |
| fornecedor | 20 | idfornecedor, razao_social |

### Erros intencionais identificados nas DDLs

Durante a análise das DDLs fornecidas, foram identificados os seguintes erros:

**1. Tabela `entradas_mercadoria`**
A coluna `ordem_compra` era utilizada na PRIMARY KEY mas não estava declarada no `CREATE TABLE`. Correção: coluna adicionada na definição da tabela.

**2. Tabela `produtos_filial`**
- PRIMARY KEY referenciava `idproduto`, mas a coluna declarada era `produto_id`
- Nome da coluna `decricao` com erro de digitação (faltava o 's')
- Faltava vírgula antes da CONSTRAINT
- Coluna `idfonecedor` declarada como `integer`, mas os dados reais usavam formato texto (ex: F8, F9)

Correções aplicadas: padronização dos nomes, adição da vírgula e alteração do tipo para `varchar(25)`.

**3. Tabela `fornecedor`**
PRIMARY KEY referenciava `idproduto`, coluna inexistente nessa tabela. Correção: PRIMARY KEY ajustada para apenas `idforncedor`.

### Tratamentos aplicados

- **Conversão de datas**: campos de data convertidos para o formato `YYYY-MM-DD` compatível com PostgreSQL
- **Remoção de colunas extras**: a aba `pedido_compra` continha 11 colunas vazias (`Unnamed: 12` a `Unnamed: 22`) ignoradas na importação
- **Conversão de tipos numéricos**: campos float com valores como `1.0` foram tratados para compatibilidade com os tipos da tabela
- **Coluna `qtde_pendente`**: presente na DDL original mas ausente na planilha — mantida na tabela com valor default 0
- **Coluna `idfonecedor`** em `produtos_filial`: tipo alterado de `integer` para `varchar(25)` para aceitar os valores da planilha (F1, F2...)

### Método de importação final
Devido a incompatibilidades entre os tipos de dados do CSV e as colunas do banco, os dados foram importados via **scripts INSERT gerados por Python**, garantindo controle total sobre os tipos e valores inseridos.

---

## Parte 2 – Consultas SQL Básicas

### Consumo por produto em fevereiro/2025
```sql
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
```

### Produtos requisitados mas não recebidos
```sql
SELECT 
    pedido_id,
    data_pedido,
    produto_id,
    descricao_produto,
    ordem_compra,
    qtde_pedida
FROM pedido_compra
WHERE ordem_compra NOT IN (
    SELECT ordem_compra FROM entradas_mercadoria
);
```

---

## Parte 3 – Transformações de Dados

### Concatenação, formatação de data e filtro por requisições > 10
```sql
SELECT 
    pc.pedido_id,
    pc.produto_id || ' - ' || pc.descricao_produto AS produto,
    TO_CHAR(pc.data_pedido, 'DD/MM/YYYY') AS data_solicitacao,
    SUM(pc.qtde_pedida) AS qtde_requisitada
FROM pedido_compra pc
GROUP BY pc.pedido_id, pc.produto_id, pc.descricao_produto, pc.data_pedido
HAVING SUM(pc.qtde_pedida) > 10
ORDER BY qtde_requisitada DESC;
```

### Trigger para geração automática de idfornecedor numérico
```sql
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
```

---

## Parte 4 – Estratégia de Validação com o Cliente

### Contexto
A reunião de validação tem como objetivo garantir que os dados importados para o banco refletem fielmente a realidade operacional do cliente. O cliente precisa sair da reunião confiante de que o sistema está recebendo as informações corretas antes de entrar em produção.

### 1. Principais pontos a validar

**Volume e integridade das vendas**
A base contém vendas de janeiro a março de 2025. O foco da validação é fevereiro/2025, conforme solicitado no case. Confirmar com o cliente o total de transações do período — quantidade de notas, produtos vendidos e valor total faturado. Qualquer divergência em relação ao sistema de origem precisa ser investigada antes do próximo periodo.

**Pedidos de compra pendentes**
Apresentar a lista de pedidos que foram feitos mas ainda não tiveram entrada registrada. O cliente precisa confirmar se esses pedidos realmente estão em aberto ou se houve falha no registro da entrada.

**Consistência entre pedido e recebimento**
Mostrar os casos onde a quantidade pedida é diferente da quantidade recebida. O cliente precisa validar se as divergências são esperadas (entregas parciais) ou se indicam erro de lançamento.

**Cadastro de produtos e fornecedores**
Verificar se todos os produtos ativos estão cadastrados com preço, estoque e fornecedor corretos. Produtos com estoque zerado ou sem fornecedor vinculado precisam de atenção especial.

**Rastreabilidade das entradas**
Confirmar que todas as entradas de mercadoria estão vinculadas a um pedido de compra pela . Entradas sem pedido vinculado podem indicar compras não planejadas ou erro de digitação.

### 2. Técnicas para garantir exatidão e precisão

- **Confronto com sistema de origem**: comparar os totais do banco com relatórios exportados do ERP ou sistema atual do cliente — se os números baterem, a importação foi bem-sucedida
- **Contagem de registros**: validar que o número de linhas importadas corresponde ao número de registros na planilha original
- **Verificação de nulos**: checar se campos obrigatórios como ,  e  estão todos preenchidos
- **Validação de chaves**: garantir que não existem registros duplicados nas chaves primárias
- **Cruzamento de tabelas**: cruzar pedidos x entradas x vendas para garantir rastreabilidade ponta a ponta

### Consultas de apoio para a reunião
```sql
-- Total de vendas em fevereiro/2025
SELECT COUNT(*) AS total_transacoes,
       SUM(qtde_vendida) AS total_quantidade,
       SUM(qtde_vendida * valor_unitario) AS total_faturado
FROM venda
WHERE EXTRACT(MONTH FROM data_emissao) = 2
AND EXTRACT(YEAR FROM data_emissao) = 2025;

-- Pedidos sem entrada vinculada
SELECT pedido_id, produto_id, descricao_produto, data_pedido, qtde_pedida
FROM pedido_compra
WHERE ordem_compra NOT IN (
    SELECT ordem_compra FROM entradas_mercadoria
);

-- Produtos com estoque zerado
SELECT produto_id, descricao, estoque
FROM produtos_filial
WHERE estoque = 0;

-- Divergência entre qtde pedida e recebida
SELECT pc.pedido_id, pc.produto_id, pc.descricao_produto,
       pc.qtde_pedida, em.qtde_recebida,
       (pc.qtde_pedida - em.qtde_recebida) AS divergencia
FROM pedido_compra pc
JOIN entradas_mercadoria em ON pc.ordem_compra = em.ordem_compra
WHERE pc.qtde_pedida <> em.qtde_recebida;

-- Vendas por filial em fevereiro/2025
SELECT filial_id,
       COUNT(*) AS total_vendas,
       SUM(qtde_vendida * valor_unitario) AS total_faturado
FROM venda
WHERE EXTRACT(MONTH FROM data_emissao) = 2
AND EXTRACT(YEAR FROM data_emissao) = 2025
GROUP BY filial_id;
```
