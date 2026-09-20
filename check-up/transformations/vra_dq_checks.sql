-- ===================================================================
-- Pipeline de Data Quality para VoeBem — voebem.silver.vra
-- Arquitetura: Marcação → Auditoria → Quarentena
-- Objetivo: Validar qualidade e integridade dos dados sem alterar a Silver
-- ===================================================================

-- ===================================================================
-- ETAPA 1 — MARCAÇÃO
-- View intermediária que enriquece a VRA com flags de referência cruzada
-- contra aeródromos e empresas cadastradas. Não altera a Silver.
-- ===================================================================
CREATE TEMPORARY VIEW vra_marcado AS
SELECT
  v.icao_empresa_aerea,
  v.numero_voo,
  v.codigo_autorizacao_di,
  v.codigo_tipo_linha,
  v.icao_aerodromo_origem,
  v.icao_aerodromo_destino,
  v.partida_prevista,
  v.partida_real,
  v.chegada_prevista,
  v.chegada_real,
  v.situacao_voo,
  v.codigo_justificativa,
  v._arquivo_origem,
  v._ingerido_em,
  v.atraso_partida_min,
  v.atraso_chegada_min,
  v.minutos_recuperados,
  v.partida_real_data,
  v.partida_prevista_data,
  v.chegada_real_data,
  v.chegada_prevista_data,
  ae.icao IS NOT NULL AS empresa_no_cadastro,
  ao.icao IS NOT NULL AS origem_no_cadastro,
  ad.icao IS NOT NULL AS destino_no_cadastro
FROM voebem.silver.vra v
LEFT JOIN (
  SELECT icao FROM voebem.silver.aerodromos
  WHERE icao IS NOT NULL AND icao != ''
) ao ON v.icao_aerodromo_origem = ao.icao
LEFT JOIN (
  SELECT icao FROM voebem.silver.aerodromos
  WHERE icao IS NOT NULL AND icao != ''
) ad ON v.icao_aerodromo_destino = ad.icao
LEFT JOIN (
  SELECT icao FROM voebem.silver.empresas
  WHERE icao IS NOT NULL AND icao != ''
) ae ON v.icao_empresa_aerea = ae.icao;

-- ===================================================================
-- ETAPA 2 — AUDITORIA
-- View intermediária com Expectations em modo WARN.
-- Todas as regras apenas medem e registram qualidade; nenhuma linha
-- é removida ou rejeitada. Não utilizar ON VIOLATION FAIL UPDATE.
-- ===================================================================
CREATE LIVE VIEW vra_auditado(
  CONSTRAINT partida_prevista_preenchida EXPECT (partida_prevista IS NOT NULL),
  CONSTRAINT chegada_prevista_preenchida EXPECT (chegada_prevista IS NOT NULL),
  CONSTRAINT situacao_voo_valida EXPECT (situacao_voo IN ('REALIZADO', 'CANCELADO')),
  CONSTRAINT chegada_prevista_posterior_partida EXPECT (
    partida_prevista IS NULL OR chegada_prevista IS NULL OR chegada_prevista > partida_prevista
  ),
  CONSTRAINT chegada_real_posterior_partida EXPECT (
    partida_real IS NULL OR chegada_real IS NULL OR chegada_real > partida_real
  ),
  CONSTRAINT atraso_partida_faixa_valida EXPECT (
    atraso_partida_min IS NULL OR (atraso_partida_min >= -120 AND atraso_partida_min <= 1440)
  ),
  CONSTRAINT atraso_chegada_faixa_valida EXPECT (
    atraso_chegada_min IS NULL OR (atraso_chegada_min >= -120 AND atraso_chegada_min <= 1440)
  ),
  CONSTRAINT empresa_no_cadastro_valida EXPECT (empresa_no_cadastro = TRUE),
  CONSTRAINT origem_no_cadastro_valida EXPECT (origem_no_cadastro = TRUE),
  CONSTRAINT destino_no_cadastro_valida EXPECT (destino_no_cadastro = TRUE)
)
AS
SELECT * FROM vra_marcado;

-- ===================================================================
-- ETAPA 3 — QUARENTENA
-- Materialized view com registros que violaram pelo menos uma Expectation.
-- Espelho diagnóstico: NÃO remove nem altera registros da Silver.
-- motivos_quarentena lista todas as regras violadas, separadas por " | ".
-- ===================================================================
CREATE OR REFRESH MATERIALIZED VIEW vra_quarentena
COMMENT 'Registros de VRA em quarentena por violacao de regras de qualidade'
AS
SELECT
  *,
  trim(concat_ws(' | ',
    CASE WHEN partida_prevista IS NULL THEN 'partida_prevista_preenchida' END,
    CASE WHEN chegada_prevista IS NULL THEN 'chegada_prevista_preenchida' END,
    CASE WHEN situacao_voo IS NULL OR situacao_voo NOT IN ('REALIZADO', 'CANCELADO') THEN 'situacao_voo_valida' END,
    CASE WHEN partida_prevista IS NOT NULL AND chegada_prevista IS NOT NULL AND chegada_prevista <= partida_prevista THEN 'chegada_prevista_posterior_partida' END,
    CASE WHEN partida_real IS NOT NULL AND chegada_real IS NOT NULL AND chegada_real <= partida_real THEN 'chegada_real_posterior_partida' END,
    CASE WHEN atraso_partida_min IS NOT NULL AND (atraso_partida_min < -120 OR atraso_partida_min > 1440) THEN 'atraso_partida_faixa_valida' END,
    CASE WHEN atraso_chegada_min IS NOT NULL AND (atraso_chegada_min < -120 OR atraso_chegada_min > 1440) THEN 'atraso_chegada_faixa_valida' END,
    CASE WHEN empresa_no_cadastro IS NOT TRUE THEN 'empresa_no_cadastro_valida' END,
    CASE WHEN origem_no_cadastro IS NOT TRUE THEN 'origem_no_cadastro_valida' END,
    CASE WHEN destino_no_cadastro IS NOT TRUE THEN 'destino_no_cadastro_valida' END
  )) AS motivos_quarentena,
  current_timestamp() AS _quarentenado_em
FROM vra_marcado
WHERE partida_prevista IS NULL
   OR chegada_prevista IS NULL
   OR (situacao_voo IS NULL OR situacao_voo NOT IN ('REALIZADO', 'CANCELADO'))
   OR (partida_prevista IS NOT NULL AND chegada_prevista IS NOT NULL AND chegada_prevista <= partida_prevista)
   OR (partida_real IS NOT NULL AND chegada_real IS NOT NULL AND chegada_real <= partida_real)
   OR (atraso_partida_min IS NOT NULL AND (atraso_partida_min < -120 OR atraso_partida_min > 1440))
   OR (atraso_chegada_min IS NOT NULL AND (atraso_chegada_min < -120 OR atraso_chegada_min > 1440))
   OR empresa_no_cadastro IS NOT TRUE
   OR origem_no_cadastro IS NOT TRUE
   OR destino_no_cadastro IS NOT TRUE;
