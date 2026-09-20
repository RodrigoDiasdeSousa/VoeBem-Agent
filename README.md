# VoeBem ✈️

Projeto de engenharia de dados desenvolvido no Databricks para organizar e transformar dados de voos da ANAC, seguindo uma arquitetura em camadas **Bronze, Silver e Gold**.

O objetivo é transformar arquivos brutos em dados tratados e estruturados para análises de times de negócio e base de conhecimentode agentes de IA.

## Arquitetura

```text
Arquivos CSV
    │
    ▼
┌──────────────┐
│    BRONZE    │  Dados brutos + metadados de ingestão
└──────┬───────┘
       │
       ▼
┌──────────────┐
│    SILVER    │  Limpeza, padronização e tratamento
└──────┬───────┘
       │
       ▼
┌──────────────┐
│     GOLD     │  Modelo analítico e dados enriquecidos
└──────────────┘
       │
       ▼
  Análises / Genie
```

## Camadas

### 🥉 Bronze

A camada Bronze recebe os arquivos da ANAC praticamente em seu formato original.

São carregados:

- Dados de voos da VRA (Voo Regular Ativo);
- Dados de aeródromos;
- Empresas aéreas nacionais;
- Empresas aéreas estrangeiras;
- Códigos de operação e tipos de linha.

Os dados são armazenados no schema `voebem.bronze`.

Também são adicionados metadados para rastreabilidade:

- `_arquivo_origem`: arquivo de origem do registro;
- `_ingerido_em`: momento da ingestão.

### 🥈 Silver

A camada Silver transforma os dados brutos em dados mais confiáveis e padronizados.

Entre os tratamentos realizados estão:

- Limpeza de valores nulos ou inválidos;
- Remoção de espaços desnecessários;
- Conversão de campos de data e hora para `TIMESTAMP`;
- Padronização dos dados de aeroportos e empresas;
- Criação de tabelas Silver com estruturas adequadas para análise.

As principais tabelas utilizadas são:

```text
voebem.silver.vra
voebem.silver.aerodromos
voebem.silver.empresas
voebem.silver.codigos_operacao
```

### 🥇 Gold

A camada Gold organiza os dados para consumo analítico.

Principais elementos:

- `voebem.gold.fato_voos`
- `voebem.gold.dim_aeroporto`
- `voebem.gold.obt_voos`

A dimensão de aeroportos é construída a partir dos aeroportos presentes nos dados de voos e enriquecida com informações do cadastro da ANAC.

Os dados de voos também são enriquecidos com:

- Nome da companhia;
- Informações dos aeroportos de origem e destino;
- Município e UF;
- País de origem e destino;
- Descrição dos códigos de operação;
- Descrição do tipo de linha;
- Classificação entre voo doméstico e internacional;
- Rota;
- Informações de data e horário;
- Indicador de atraso fora de uma faixa considerada plausível.

## OBT

A `obt_voos` concentra as principais informações necessárias para análise em uma única tabela.

Ela combina os dados da fato de voos com as dimensões de aeroportos, empresas e códigos de referência.

## Tecnologias utilizadas

- **Databricks**
- **Apache Spark / PySpark**
- **SQL**
- **Delta Lake**
- **Unity Catalog**
- **Python**
- **Git / GitHub**

## Estrutura do projeto

```text
VoeBem-Agent/
│
├── bronze_vra_1
├── bronze_referencias_1
├── silver-tables_2
├── gold_governanca_3
├── README.md
└── ...
```

Os notebooks representam as principais etapas do pipeline de dados.

## Fluxo dos dados

```text
ANAC
 │
 │ CSV
 ▼
Bronze
 │
 │ limpeza + padronização
 ▼
Silver
 │
 │ joins + enriquecimento + modelagem
 ▼
Gold
 │
 ├── fato_voos
 ├── dim_aeroporto
 └── obt_voos
 │
 ▼
Análises e consultas
```

## Objetivo do projeto

O VoeBem foi desenvolvido como um projeto prático de **Data Engineering**, explorando um fluxo completo de dados no Databricks: ingestão, armazenamento em Delta, transformação com PySpark/SQL, modelagem analítica e preparação dos dados para consumo.

Além da parte de engenharia de dados, o projeto possui integração com recursos de análise do Databricks, incluindo um agente **Genie** para interação com os dados.

## Fonte dos dados

Os dados utilizados no projeto são provenientes de bases públicas da **ANAC (Agência Nacional de Aviação Civil)**, incluindo a VRA e bases de referência de aeroportos e empresas aéreas.
