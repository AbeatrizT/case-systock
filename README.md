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

### Tratamentos aplicados na planilha

**1. Conversão de datas**
Os campos de data (`data_emissao`, `data_pedido`, `data_entrega`, `data_entrada`) estavam no formato padrão do Excel. Foram convertidos para o formato `YYYY-MM-DD` exigido pelo PostgreSQL para o tipo `date`.

**2. Remoção de colunas extras**
A aba `pedido_compra` continha 11 colunas completamente vazias (`Unnamed: 12` até `Unnamed: 22`), provavelmente resultado de formatação residual da planilha. Essas colunas foram ignoradas na importação pois não correspondiam a nenhuma coluna da tabela.

**3. Incompatibilidade de tipos numéricos**
Campos como `fornecedor_id` e `filial_id` estavam armazenados como float (`1.0`, `2.0`) na planilha, mas a DDL original os definia como `integer`. Isso causou falha na importação direta via pgAdmin. Solução: os tipos das colunas foram ajustados para `float8` via `ALTER TABLE` para aceitar os valores da planilha sem perda de dados.

**4. Coluna `qtde_pendente` ausente na planilha**
A DDL do `pedido_compra` define a coluna `qtde_pendente float8 DEFAULT 0 NOT NULL`, porém essa coluna não existe na planilha fornecida. Trata-se de um campo calculado (qtde_pedida - qtde_entregue) que deveria ser derivado, não fornecido diretamente. A coluna foi mantida na tabela com valor `DEFAULT 0` e pode ser atualizada posteriormente com:
```sql
UPDATE pedido_compra SET qtde_pendente = qtde_pedida - qtde_entregue;
```

**5. Coluna `idfonecedor` com tipo incompatível**
Na DDL original, `idfonecedor` em `produtos_filial` foi definida como `integer`. Porém, na planilha os valores são alfanuméricos no formato `F1`, `F2`, ..., `F20`. O tipo foi alterado para `varchar(25)` via `ALTER TABLE` para aceitar os dados reais:
```sql
ALTER TABLE produtos_filial ALTER COLUMN idfonecedor TYPE varchar(25);
```

### Ajustes e correções nas DDLs originais

As DDLs fornecidas no case continham erros intencionais que impediam a criação das tabelas. Abaixo estão todos os erros identificados e as correções aplicadas:

**Erro 1 — `entradas_mercadoria`: coluna `ordem_compra` ausente na definição**
A PRIMARY KEY da tabela referenciava `ordem_compra`, mas essa coluna não estava declarada no `CREATE TABLE`. Sem ela, o banco retornaria erro ao tentar criar a tabela.
```sql
-- Correção: coluna adicionada na definição
ordem_compra float8 DEFAULT 0 NOT NULL
```

**Erro 2 — `produtos_filial`: PRIMARY KEY referenciando coluna inexistente**
A CONSTRAINT definia `PRIMARY KEY (filial_id, idproduto)`, mas a coluna declarada na tabela era `produto_id`. Nomes diferentes = erro na criação.
```sql
-- Correção: PRIMARY KEY ajustada
CONSTRAINT produtos_filial_pkey PRIMARY KEY (filial_id, produto_id)
```

**Erro 3 — `produtos_filial`: erro de digitação no nome da coluna**
A coluna `decricao` estava com erro de digitação (faltava o 's'). Corrigido para `descricao` para manter consistência com os dados da planilha.

**Erro 4 — `produtos_filial`: vírgula faltando antes da CONSTRAINT**
A linha anterior à CONSTRAINT não tinha vírgula, o que causaria erro de sintaxe no SQL.
```sql
-- Incorreto
idfonecedor int4 NULL
CONSTRAINT produtos_filial_pkey ...

-- Correto
idfonecedor int4 NULL,
CONSTRAINT produtos_filial_pkey ...
```

**Erro 5 — `fornecedor`: PRIMARY KEY referenciando coluna inexistente**
A CONSTRAINT definia `PRIMARY KEY (idforncedor, idproduto)`, mas `idproduto` não existe na tabela `fornecedor`. A tabela de fornecedor só tem `idforncedor` e `razao_social`.
```sql
-- Correção: PRIMARY KEY ajustada para apenas a coluna existente
CONSTRAINT fornecedor_pkey PRIMARY KEY (idforncedor)
```

### Método de importação final

A tentativa inicial de importação via **pgAdmin 4 (Import/Export CSV)** falhou devido às incompatibilidades de tipos descritas acima. Para garantir a integridade dos dados, a importação foi realizada via **scripts SQL com comandos INSERT**, executados diretamente no Query Tool do pgAdmin. Essa abordagem permitiu controle total sobre os valores inseridos e gerou um log auditável de toda a carga de dados.

As tabelas `fornecedor` e `produtos_filial` foram importadas com sucesso via CSV após os ajustes de tipo. As tabelas `pedido_compra`, `entradas_mercadoria` e `venda` foram importadas via scripts INSERT.

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
    produto_id || ' - ' || descricao_produto AS produto,
    TO_CHAR(MIN(data_pedido), 'DD/MM/YYYY') AS data_solicitacao,
    SUM(qtde_pedida) AS qtde_requisitada
FROM pedido_compra
GROUP BY produto_id, descricao_produto
HAVING SUM(qtde_pedida) > 10
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
A base contém vendas de janeiro a março de 2025. O foco da validação é fevereiro/2025, conforme solicitado no case. Confirmar com o cliente o total de transações do período — quantidade de notas, produtos vendidos e valor total faturado. Qualquer divergência em relação ao sistema de origem precisa ser investigada antes da virada.

**Pedidos de compra pendentes**
Apresentar a lista de pedidos que foram feitos mas ainda não tiveram entrada registrada. O cliente precisa confirmar se esses pedidos realmente estão em aberto ou se houve falha no registro da entrada.

**Consistência entre pedido e recebimento**
Mostrar os casos onde a quantidade pedida é diferente da quantidade recebida. O cliente precisa validar se as divergências são esperadas (entregas parciais) ou se indicam erro de lançamento.

**Cadastro de produtos e fornecedores**
Verificar se todos os produtos ativos estão cadastrados com preço, estoque e fornecedor corretos. Produtos com estoque zerado ou sem fornecedor vinculado precisam de atenção especial.

**Rastreabilidade das entradas**
Confirmar que todas as entradas de mercadoria estão vinculadas a um pedido de compra pelo campo `ordem_compra`. Entradas sem pedido vinculado podem indicar compras não planejadas ou erro de digitação.

### 2. Técnicas para garantir exatidão e precisão

- **Confronto com sistema de origem**: comparar os totais do banco com relatórios exportados do ERP ou sistema atual do cliente — se os números baterem, a importação foi bem-sucedida
- **Contagem de registros**: validar que o número de linhas importadas corresponde ao número de registros na planilha original
- **Verificação de nulos**: checar se campos obrigatórios como `produto_id`, `data_emissao` e `valor_unitario` estão todos preenchidos
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
