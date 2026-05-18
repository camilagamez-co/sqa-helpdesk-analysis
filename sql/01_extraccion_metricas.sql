-- =============================================================================
-- ARCHIVO: 01_extraccion_metricas.sql
-- PROYECTO: Análisis Operativo de Helpdesk — SQA Portfolio
-- AUTORA: Camila Gámez · Data Analyst
-- DESCRIPCIÓN: Queries de extracción con lógica de negocio ITSM.
--              Diseñadas para PostgreSQL (sistema original).
--              En el proyecto se ejecutan sobre SQLite via Python (sqlite3).
-- RESULTADOS REALES: verificados sobre 32,726 tickets clasificados.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- QUERY 1 · MTTR por prioridad
-- KPI: Mean Time to Resolve
-- Resultado real: Blocker mediana 90.6h · Medium mediana 238.5h
-- NOTA: el promedio está distorsionado por outliers extremos (máx 48,926h).
--       La mediana, calculada en pandas, es el KPI correcto.
-- -----------------------------------------------------------------------------

SELECT
    issue_priority,
    COUNT(*)                                                              AS total_tickets,
    ROUND(AVG(
        EXTRACT(EPOCH FROM (issue_resolution_date::timestamptz
                          - issue_created::timestamptz)) / 3600
    ), 1)                                                                 AS mttr_promedio_horas,
    ROUND(MIN(
        EXTRACT(EPOCH FROM (issue_resolution_date::timestamptz
                          - issue_created::timestamptz)) / 3600
    ), 1)                                                                 AS mttr_minimo_horas,
    ROUND(MAX(
        EXTRACT(EPOCH FROM (issue_resolution_date::timestamptz
                          - issue_created::timestamptz)) / 3600
    ), 1)                                                                 AS mttr_maximo_horas,
    -- PERCENTILE_CONT disponible en PostgreSQL (no en SQLite)
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (
        ORDER BY EXTRACT(EPOCH FROM (issue_resolution_date::timestamptz
                                   - issue_created::timestamptz)) / 3600
    )::NUMERIC, 1)                                                        AS mttr_mediana_horas
FROM issues
WHERE issue_resolution_date IS NOT NULL
  AND issue_created         IS NOT NULL
  AND issue_priority NOT IN ('unknown')
GROUP BY issue_priority
ORDER BY
    CASE issue_priority
        WHEN 'Blocker'  THEN 1
        WHEN 'Highest'  THEN 2
        WHEN 'High'     THEN 3
        WHEN 'Medium'   THEN 4
        WHEN 'Low'      THEN 5
        WHEN 'Lowest'   THEN 6
    END;

-- Versión SQLite (usada en el notebook con JULIANDAY):
-- ROUND(AVG((JULIANDAY(issue_resolution_date) - JULIANDAY(issue_created)) * 24), 1)


-- -----------------------------------------------------------------------------
-- QUERY 2 · FCR y Escalation Rate — INNER JOIN entre dos tablas
-- KPIs: First Contact Resolution Rate · Escalation Rate
-- Resultado real: FCR 57.1% · Escalation Rate 42.9% global
--                 Blocker: Escalation Rate 73.8% (3 de cada 4 escalan)
-- NOTA: esta query es imposible sin el JOIN.
--       issues solo guarda el asignado final, no el historial de reasignaciones.
-- -----------------------------------------------------------------------------

SELECT
    ch.issueid,
    i.issue_priority,
    i.issue_type,
    SUM(CASE WHEN ch.field = 'assignee' THEN 1 ELSE 0 END)   AS num_reasignaciones,
    SUM(CASE WHEN ch.field = 'status'   THEN 1 ELSE 0 END)   AS num_cambios_estado,
    CASE
        WHEN SUM(CASE WHEN ch.field = 'assignee' THEN 1 ELSE 0 END) <= 1
        THEN 'fcr'
        ELSE 'escalado'
    END                                                        AS tipo_resolucion
FROM issues_change_history ch
    INNER JOIN issues i ON ch.issueid = i.id
WHERE i.issue_priority NOT IN ('unknown')
GROUP BY ch.issueid, i.issue_priority, i.issue_type;

-- Resumen agregado por prioridad (ejecutar sobre la query anterior como subquery):
-- SELECT
--     issue_priority,
--     COUNT(*)                                                  AS total,
--     SUM(CASE WHEN tipo_resolucion = 'escalado' THEN 1 END)   AS escalados,
--     ROUND(AVG(CASE WHEN tipo_resolucion = 'escalado' THEN 1.0 ELSE 0 END) * 100, 1)
--                                                               AS escalation_rate_pct
-- FROM (...) sub
-- GROUP BY issue_priority;


-- -----------------------------------------------------------------------------
-- QUERY 3 · Ticket Volume mensual (2018–2022)
-- KPI: Ticket Volume YoY
-- Resultado real: +382% crecimiento total · 2019 fue el año de mayor salto (+253%)
-- -----------------------------------------------------------------------------

SELECT
    DATE_TRUNC('month', issue_created::timestamptz)           AS mes,
    issue_priority,
    COUNT(*)                                                   AS tickets_creados,
    SUM(CASE WHEN issue_resolution = 'Done' THEN 1 ELSE 0 END)
                                                               AS tickets_resueltos,
    ROUND(
        SUM(CASE WHEN issue_resolution = 'Done' THEN 1.0 ELSE 0 END)
        / COUNT(*) * 100, 1
    )                                                          AS resolution_rate_mensual_pct
FROM issues
WHERE issue_priority NOT IN ('unknown')
  AND issue_created::timestamptz >= '2018-01-01'
  AND issue_created::timestamptz <  '2023-01-01'
GROUP BY mes, issue_priority
ORDER BY mes, issue_priority;

-- Versión SQLite (usada en el notebook):
-- SUBSTR(issue_created, 1, 7) AS mes


-- -----------------------------------------------------------------------------
-- QUERY 4 · Carga por turno de asignación — desde issues_snapshot
-- Objetivo: cuantificar el tiempo promedio por nivel de escalación
-- turn=1: primer asignado (resolución directa)
-- turn>1: escalaciones sucesivas
-- Resultado real: el patrón de horas varía por prioridad y turno
-- -----------------------------------------------------------------------------

SELECT
    turn                                                        AS turno_asignacion,
    issue_priority,
    COUNT(*)                                                    AS registros,
    ROUND(AVG(
        EXTRACT(EPOCH FROM (ended::timestamptz
                          - started::timestamptz)) / 3600
    ), 1)                                                       AS horas_promedio,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (
        ORDER BY EXTRACT(EPOCH FROM (ended::timestamptz
                                   - started::timestamptz)) / 3600
    )::NUMERIC, 1)                                              AS horas_mediana
FROM issues_snapshot
WHERE issue_priority NOT IN ('unknown')
  AND started IS NOT NULL
  AND ended   IS NOT NULL
  AND ended::timestamptz > started::timestamptz
GROUP BY turn, issue_priority
ORDER BY turn, issue_priority;


-- -----------------------------------------------------------------------------
-- QUERY 5 · SLA Compliance Rate por prioridad — proxy con umbrales estándar
-- KPI: SLA Compliance Rate
-- Resultado real: Blocker 22.5% · Highest 34.8% · High 35.1% · Medium 35.5%
-- Umbrales estándar ITSM: Blocker <8h · Highest <24h · High <48h · Medium <120h
-- NOTA: estos umbrales son proxy — el dataset no tiene SLA contractual definido.
-- -----------------------------------------------------------------------------

SELECT
    issue_priority,
    COUNT(*)                                                    AS total_tickets,
    SUM(CASE
        WHEN issue_priority = 'Blocker'
             AND EXTRACT(EPOCH FROM (issue_resolution_date::timestamptz
                                   - issue_created::timestamptz)) / 3600 <= 8
        THEN 1
        WHEN issue_priority = 'Highest'
             AND EXTRACT(EPOCH FROM (issue_resolution_date::timestamptz
                                   - issue_created::timestamptz)) / 3600 <= 24
        THEN 1
        WHEN issue_priority = 'High'
             AND EXTRACT(EPOCH FROM (issue_resolution_date::timestamptz
                                   - issue_created::timestamptz)) / 3600 <= 48
        THEN 1
        WHEN issue_priority = 'Medium'
             AND EXTRACT(EPOCH FROM (issue_resolution_date::timestamptz
                                   - issue_created::timestamptz)) / 3600 <= 120
        THEN 1
        ELSE 0
    END)                                                        AS dentro_del_sla,
    ROUND(
        SUM(CASE
            WHEN issue_priority = 'Blocker'
                 AND EXTRACT(EPOCH FROM (issue_resolution_date::timestamptz
                                       - issue_created::timestamptz)) / 3600 <= 8
            THEN 1
            WHEN issue_priority = 'Highest'
                 AND EXTRACT(EPOCH FROM (issue_resolution_date::timestamptz
                                       - issue_created::timestamptz)) / 3600 <= 24
            THEN 1
            WHEN issue_priority = 'High'
                 AND EXTRACT(EPOCH FROM (issue_resolution_date::timestamptz
                                       - issue_created::timestamptz)) / 3600 <= 48
            THEN 1
            WHEN issue_priority = 'Medium'
                 AND EXTRACT(EPOCH FROM (issue_resolution_date::timestamptz
                                       - issue_created::timestamptz)) / 3600 <= 120
            THEN 1
            ELSE 0
        END) * 100.0 / COUNT(*), 1
    )                                                           AS sla_compliance_pct
FROM issues
WHERE issue_priority IN ('Blocker', 'Highest', 'High', 'Medium')
  AND issue_resolution_date IS NOT NULL
  AND issue_created         IS NOT NULL
GROUP BY issue_priority
ORDER BY
    CASE issue_priority
        WHEN 'Blocker'  THEN 1
        WHEN 'Highest'  THEN 2
        WHEN 'High'     THEN 3
        WHEN 'Medium'   THEN 4
    END;
