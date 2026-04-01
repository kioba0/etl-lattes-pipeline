-- ==============================================================================
-- Arquivo: fts_tutorial_lattes.sql
-- Descrição: Tutorial prático de Full Text Search (FTS) no PostgreSQL.
-- Referência: "Busca Textual no PostgreSQL é boa o suficiente" (Artigo InfoQ)
-- Contexto: Base de Currículos Lattes (Tabelas: pesquisadores e producoes)
-- ==============================================================================

-- ==============================================================================
-- PASSO 1: O Básico de tsvector e tsquery
-- ==============================================================================

-- Exemplo: Buscando por produções que tenham as palavras "rede" ou "complexa" no título.
SELECT 
    nomeartigo
FROM 
    producoes
WHERE 
    to_tsvector('portuguese', nomeartigo) @@ to_tsquery('portuguese', 'rede | complexa');


-- ==============================================================================
-- PASSO 2: Juntando tabelas para criar o "Documento" da busca
-- ==============================================================================
SELECT 
    p.nomeartigo,
    pesq.nome AS pesquisador
FROM 
    producoes p
JOIN 
    pesquisadores pesq ON p.pesquisadores_id = pesq.pesquisadores_id
WHERE 
    to_tsvector('portuguese', p.nomeartigo || ' ' || pesq.nome) @@ to_tsquery('portuguese', 'tecnologia & inovacao');
-- Nota: O operador '&' no tsquery exige que ambas as palavras estejam em algum lugar do documento gerado.


-- ==============================================================================
-- PASSO 3: Atribuição de Pesos (Weights)
-- ==============================================================================
SELECT 
    p.nomeartigo,
    pesq.nome AS pesquisador
FROM 
    producoes p
JOIN 
    pesquisadores pesq ON p.pesquisadores_id = pesq.pesquisadores_id
WHERE 
    (
        setweight(to_tsvector('portuguese', coalesce(p.nomeartigo, '')), 'A') || 
        setweight(to_tsvector('portuguese', coalesce(pesq.nome, '')), 'B')
    ) @@ to_tsquery('portuguese', 'logistica');


-- ==============================================================================
-- PASSO 4: Ranqueamento (Ordering / Ranking)
-- ==============================================================================
SELECT 
    p.nomeartigo,
    pesq.nome AS pesquisador,
    ts_rank(
        (setweight(to_tsvector('portuguese', coalesce(p.nomeartigo, '')), 'A') || 
         setweight(to_tsvector('portuguese', coalesce(pesq.nome, '')), 'B')), 
        to_tsquery('portuguese', 'redes | inovacao')
    ) AS relevancia
FROM 
    producoes p
JOIN 
    pesquisadores pesq ON p.pesquisadores_id = pesq.pesquisadores_id
WHERE 
    (
        setweight(to_tsvector('portuguese', coalesce(p.nomeartigo, '')), 'A') || 
        setweight(to_tsvector('portuguese', coalesce(pesq.nome, '')), 'B')
    ) @@ to_tsquery('portuguese', 'redes | inovacao')
ORDER BY 
    relevancia DESC;


-- ==============================================================================
-- PASSO 5: Otimização Definitiva (Índices GIN e Coluna Materializada)
-- ==============================================================================

-- 5.1 Adicionamos uma nova coluna do tipo tsvector na tabela de produções
ALTER TABLE producoes ADD COLUMN documento_fts tsvector;

-- 5.2 Preenchemos a nova coluna juntando os pesos de Título e Autor
UPDATE producoes p
SET documento_fts = 
    setweight(to_tsvector('portuguese', coalesce(p.nomeartigo, '')), 'A') || 
    setweight(to_tsvector('portuguese', coalesce((SELECT nome FROM pesquisadores WHERE pesquisadores_id = p.pesquisadores_id), '')), 'B');

-- 5.3 Criamos o Índice Invertido Generalizado (GIN). 
CREATE INDEX idx_producoes_fts ON producoes USING GIN (documento_fts);


-- ==============================================================================
-- PASSO 6: A Consulta Final
-- ==============================================================================
SELECT 
    nomeartigo,
    ts_rank(documento_fts, to_tsquery('portuguese', 'robo')) AS rank
FROM 
    producoes
WHERE 
    documento_fts @@ to_tsquery('portuguese', 'robo')
ORDER BY 
    rank DESC;
