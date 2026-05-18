# Análisis Operativo de Helpdesk — IT Service Management

![Python](https://img.shields.io/badge/Python-3.11-3776AB?style=flat&logo=python&logoColor=white)
![SQL](https://img.shields.io/badge/SQL-SQLite-003B57?style=flat&logo=sqlite&logoColor=white)
![Power BI](https://img.shields.io/badge/Power%20BI-Dashboard-F2C811?style=flat&logo=powerbi&logoColor=black)
![pandas](https://img.shields.io/badge/pandas-2.x-150458?style=flat&logo=pandas&logoColor=white)
![scipy](https://img.shields.io/badge/scipy-Mann--Whitney-8CAAE6?style=flat)
![Licencia](https://img.shields.io/badge/datos-CC%20BY%204.0-4CAF50?style=flat)
![Tickets](https://img.shields.io/badge/tickets-32%2C726-blue?style=flat)
![Período](https://img.shields.io/badge/período-2007--2023-orange?style=flat)

---

## Contexto y problema de negocio

Las empresas de servicios tecnológicos operan bajo acuerdos de nivel de servicio (SLA) con sus clientes. Cada ticket de soporte representa una promesa de respuesta: si se incumple sistemáticamente, el cliente no renueva.

Sin métricas operativas estructuradas, el equipo no puede saber si los tickets críticos se atienden realmente más rápido, qué porcentaje de resoluciones falla, dónde se concentra el riesgo de perder clientes, ni si la capacidad del equipo está al límite.

**Pregunta central:**
> *¿Dónde está el riesgo operativo real de este helpdesk, y qué decisiones concretas pueden reducir el costo de atención y proteger la retención de clientes?*

---

## KPIs de la industria ITSM — resultados reales

Estos son los indicadores estándar de **IT Service Management (ITSM)** según el framework ITIL v4, calculados sobre 32,726 tickets reales.

| KPI | Definición en ITSM | Valor obtenido | Señal |
|---|---|---|---|
| **MTTR Blocker** | Tiempo mediano desde apertura hasta cierre | 90.6 h (3.8 días) | ⚠️ Margen de mejora |
| **MTTR Medium** | Tiempo mediano para prioridad media | 238.5 h (9.9 días) | ⚠️ Alto |
| **FCR** *(First Contact Resolution)* | % tickets resueltos sin reasignación | 57.1% | ⚠️ Bajo |
| **Escalation Rate** | % tickets con más de una reasignación | 42.9% global · Blocker: **73.8%** | 🔴 Crítico en alta prioridad |
| **Ticket Churn** *(Reopen Rate)* | % tickets cerrados que volvieron a abrirse | 2.56% global · Low: **4.82%** | ⚠️ Patrón contraintuitivo |
| **SLA Compliance Blocker** | % resueltos en < 8 horas | **22.5%** | 🔴 Crítico |
| **SLA Compliance Highest** | % resueltos en < 24 horas | 34.8% | 🔴 Crítico |
| **Resolution Rate** | % tickets con resolución Done | 93.0% | ✅ Saludable |
| **Backlog Rate** | % tickets sin fecha de resolución | 1.3% | ✅ Saludable |
| **Ticket Volume YoY** | Crecimiento interanual del volumen | +382% (2018→2022) | ⚠️ Requiere planificación |
| **Avg Processing Steps** | Pasos promedio del workflow | Blocker: 4.3 · Lowest: 2.8 | Referencia de complejidad |
| **Avg Contributors Blocker** | Personas involucradas por ticket | 1.89 | Costo de recursos alto |

> **Nota:** CAC, LTV, ROMI y Churn de clientes son métricas de marketing/SaaS. No aplican a helpdesk operativo. El término correcto aquí es **Ticket Churn** (Reopen Rate) — mide resoluciones fallidas en el dominio de soporte TI.

---

## Hallazgos principales

| # | Hallazgo | Impacto de negocio |
|---|---|---|
| 1 | **SLA Compliance 22.5% en Blockers** — solo 1 de cada 4 tickets críticos se resuelve en < 8h | En contratos ITSM formales esto genera penalidades y es la principal causa de no renovación |
| 2 | **Escalation Rate 73.8% en Blockers** — casi 3 de cada 4 escalan a un segundo asignado | El costo no es tiempo (escalados resuelven más rápido: 170h vs 217h) sino el doble de recursos humanos |
| 3 | **Ticket Churn mayor en Low (4.82%) que en Blocker (2.29%)** — patrón contraintuitivo | Los tickets de baja prioridad se cierran apresurados y vuelven — cada reapertura duplica el costo |
| 4 | **+382% de volumen en 4 años** sin evidencia de crecimiento proporcional del equipo | El deterioro en KPIs es estructural: más demanda sobre la misma capacidad |
| 5 | **Diferencia estadísticamente real** entre alta y baja prioridad (Mann-Whitney p=3.6e-147) | El sistema respeta la jerarquía — pero todos los niveles incumplen SLA |

---

## Estructura del proyecto

```
sqa-helpdesk-analysis/
│
├── Help Desk Tickets/                       ← Datos fuente (no se suben a GitHub)
│   ├── issues.csv                           # 66,691 tickets · 58 columnas
│   ├── issues_change_history.csv            # 257,508 eventos de cambio
│   └── issues_snapshot.csv                 # 90,963 registros por turno
│
├── notebooks/
│   ├── 01_extraccion_transformacion.ipynb  # ETL · SQL · KPIs base · exportación
│   └── 02_analisis_operativo.ipynb         # Análisis · estadística · visualizaciones · conclusiones
│
├── sql/
│   └── 01_extraccion_metricas.sql          # Queries documentadas con lógica de negocio
│
├── exports/                                ← Generado al ejecutar los notebooks
│   ├── issues_limpio.csv                   # Dataset consolidado para Power BI
│   ├── escalaciones.csv                    # FCR y Escalation Rate por ticket (JOIN SQL)
│   ├── tendencia_mensual.csv               # Volumen y Resolution Rate mensual
│   ├── mttr_por_prioridad.csv              # MTTR con percentiles por prioridad
│   ├── ticket_churn.csv                    # Reopen Rate por prioridad
│   ├── carga_por_turno.csv                 # Horas por turno de asignación
│   └── risk_score.csv                      # Risk Score compuesto por prioridad
│
├── dashboard/
│   └── sqa_helpdesk.pbix                  # Dashboard Power BI · 3 páginas · medidas DAX
│
└── README.md
```

---

## Paso a paso del proyecto

### Notebook 1 — ETL y extracción

| Paso | Acción | Herramienta | Output |
|---|---|---|---|
| 1 | Importaciones y configuración de rutas | Python | Entorno reproducible |
| 2 | Carga de 3 archivos CSV relacionales | pandas | 3 DataFrames |
| 3 | Exploración: duplicados · nulos · distribución · Resolution Rate · Backlog | pandas | Diagnóstico de calidad |
| 4 | Limpieza: fechas · filtro unknown · clasificación ext/int · MTTR · Ticket Churn · tiempo | pandas | Dataset limpio con KPIs base |
| 5 | SQLite + 4 queries SQL con JOINs entre tablas | SQL · sqlite3 | FCR · Escalation · Tendencia · Turnos |
| 6 | MTTR mediana · SLA Compliance · Avg Contributors · Exportación | pandas | 6 CSVs para NB2 y Power BI |

### Notebook 2 — Análisis y conclusiones

| Paso | KPI analizado | Herramienta | Hallazgo real |
|---|---|---|---|
| 7 | MTTR por prioridad | pandas · matplotlib · plotly | Media 12.7x mayor que mediana en Blocker — outliers extremos |
| 8 | Shapiro-Wilk | scipy.stats | W=0.329, p=4.29e-39 → No normal → justifica Mann-Whitney |
| 9 | Mann-Whitney U | scipy.stats | p=3.60e-147 → diferencia real y sistemática |
| 10 | Ticket Churn | pandas · matplotlib | Low 4.82% > Blocker 2.29% — calidad sacrificada en baja prioridad |
| 11 | FCR + Escalation Rate | pandas · matplotlib | Blocker 73.8% escalación — escalados resuelven más rápido |
| 12 | SLA Compliance Rate | pandas · matplotlib | Blocker 22.5% — ningún nivel supera el 80% saludable |
| 13 | Ticket Volume YoY | pandas · matplotlib | +382% en 4 años · 2019 fue el año de mayor crecimiento (+253%) |
| 14 | Avg Processing Steps | pandas | 4.0 pasos mediana — Lowest con solo 2.8 (menos revisión) |
| 15 | Externo vs Interno | pandas · plotly | Externos resuelven más rápido (Blocker int. anomalía n=49) |
| 16 | Correlación Spearman | scipy.stats | rho=0.113, p<0.001 — correlación débil steps vs MTTR |
| 17 | Risk Score compuesto | pandas · plotly | Blocker (5.56) > Highest (5.45) > High (5.25) |
| 18 | Conclusiones de negocio | — | 4 hallazgos con impacto económico y recomendaciones por horizonte |

---

## Stack tecnológico

| Herramienta | Versión | Uso en el proyecto |
|---|---|---|
| **Python** | 3.11 | Lenguaje principal |
| **pandas** | 2.x | ETL · transformaciones · KPIs · JOINs con `.merge()` |
| **numpy** | 2.x | Operaciones numéricas · percentiles |
| **sqlite3** | stdlib | Réplica local de la BD PostgreSQL original |
| **SQL** | — | 4 queries con INNER JOIN · CASE · JULIANDAY · SUBSTR · GROUP BY |
| **scipy.stats** | — | Shapiro-Wilk · Mann-Whitney U · Spearman |
| **matplotlib** | — | Visualizaciones estáticas exportables |
| **plotly** | — | Visualizaciones interactivas (boxplot · scatter · barras · líneas) |
| **Power BI Desktop** | — | Dashboard ejecutivo · 3 páginas · medidas DAX |

**ETL vs ELT — contexto de industria:**
- **ETL** (Extract → Transform → Load): patrón de este proyecto. Python transforma antes de cargar al destino analítico.
- **ELT** (Extract → Load → Transform): patrón en plataformas cloud como **Databricks** o BigQuery. Se carga el dato crudo primero y se transforma con SQL/Spark dentro de la plataforma. En Databricks, este pipeline sería un **Delta Live Table** con las mismas transformaciones aplicadas en PySpark.

---

## Dashboard Power BI

**Página 1 · KPI Overview**
Tarjetas con MTTR mediana · FCR · Escalation Rate · Ticket Churn · SLA Compliance · Resolution Rate · Backlog Rate. Filtros por año y tipo de proyecto.

**Página 2 · Risk Matrix**
Scatter interactivo de Escalation Rate vs MTTR por prioridad. Risk Score compuesto (0–10). Comparativo externo vs interno.

**Página 3 · Trends**
Ticket Volume YoY · distribución por día de semana · tendencia mensual 2018–2022.

**Medidas DAX principales:**
```dax
MTTR Mediano (h)      = MEDIANX(FILTER(issues_limpio, issues_limpio[mttr_horas] <> BLANK()), issues_limpio[mttr_horas])
FCR %                 = DIVIDE(COUNTROWS(FILTER(escalaciones, escalaciones[tipo_resolucion] = "fcr")), COUNTROWS(escalaciones))
Escalation Rate %     = DIVIDE(COUNTROWS(FILTER(escalaciones, escalaciones[tipo_resolucion] = "escalado")), COUNTROWS(escalaciones))
Ticket Churn %        = DIVIDE(COUNTROWS(FILTER(issues_limpio, issues_limpio[fue_reabierto] = TRUE())), COUNTROWS(issues_limpio))
Resolution Rate %     = DIVIDE(COUNTROWS(FILTER(issues_limpio, issues_limpio[issue_resolution] = "Done")), COUNTROWS(issues_limpio))
SLA Compliance %      = DIVIDE(COUNTROWS(FILTER(issues_limpio, issues_limpio[mttr_horas] <= [Umbral_SLA])), COUNTROWS(issues_limpio))
```

---

## Fuente de datos

**Help Desk Tickets — Mendeley Data**
Abdellatif, M. (2025). Help Desk Tickets. Mendeley Data, V2.
https://doi.org/10.17632/btm76zndnt.2
Licencia: CC BY 4.0

Datos reales de un sistema de helpdesk corporativo de software internacional, extraídos de PostgreSQL y anonimizados. Cubre tickets desde abril 2007 hasta marzo 2023 (15 años). El análisis principal usa la ventana 2018–2022 para garantizar cobertura completa por año.

**Por qué tres tablas y no una:** el FCR y Escalation Rate reales solo pueden calcularse cruzando `issues_change_history` (historial de reasignaciones) con `issues` (que solo guarda el asignado final) mediante JOIN. Sin esa relación, ambos KPIs son imposibles de calcular con precisión.

---

## Cómo reproducir el análisis

```bash
# 1. Clonar el repositorio
git clone https://github.com/camilagamez/sqa-helpdesk-analysis.git
cd sqa-helpdesk-analysis

# 2. Instalar dependencias
pip install pandas numpy scipy matplotlib seaborn plotly jupyter

# 3. Descargar los datos desde https://doi.org/10.17632/btm76zndnt.2
#    y colocar los 3 CSV en la carpeta 'Help Desk Tickets/'

# 4. Ejecutar en orden
jupyter notebook notebooks/01_extraccion_transformacion.ipynb
jupyter notebook notebooks/02_analisis_operativo.ipynb

# 5. Power BI
#    Abrir dashboard/sqa_helpdesk.pbix
#    Actualizar rutas a la carpeta exports/ si es necesario
```

---

## Decisiones analíticas documentadas

**¿Por qué excluir los tickets con prioridad 'unknown'?**
El 50.9% (33,965 tickets) tiene prioridad sin clasificar — resueltos fuera del flujo estándar. Incluirlos mezclaría dos poblaciones con comportamientos distintos, distorsionando MTTR, FCR y Escalation Rate. Se conservan en `df_issues_raw` para referencia.

**¿Por qué mediana y no promedio para MTTR?**
La media está distorsionada hasta 12.7x por outliers extremos (máx: 48,926h = 5.6 años). La mediana es robusta a outliers y representa la experiencia del cliente típico.

**¿Por qué Shapiro-Wilk antes de Mann-Whitney?**
No se puede elegir la prueba estadística sin verificar primero el tipo de distribución. Shapiro-Wilk (W=0.329, p=4.29e-39) confirmó distribución no normal → Mann-Whitney U es la prueba correcta. Aplicar t-test sin esta verificación invalida toda la inferencia.

**¿Por qué Spearman y no Pearson para la correlación?**
Pearson asume normalidad y relación lineal. Como MTTR no es normal (Paso 8), Spearman — correlación de rangos — es la elección correcta. Es robusta a outliers y distribuciones sesgadas.

**¿Por qué los escalados tienen menor MTTR que los directos?**
MTTR escalados: 170.7h vs directos: 217.6h. Al escalar, el ticket llega a un especialista más capaz que lo resuelve más rápido. El costo de la escalación no es tiempo — es el doble de recursos humanos involucrados (dos personas en lugar de una).

**Anomalía documentada: Blocker interno MTTR 6,470h**
Con solo n=49 Blockers internos, un ticket muy largo distorsiona la mediana. Se excluye del gráfico comparativo pero se documenta honestamente. No es representativo del comportamiento general.

---

## Limitaciones del dataset

- Proyectos y usuarios anonimizados — no es posible analizar por cliente o ingeniero específico
- No existe definición formal de SLA en el dataset — se usan umbrales estándar ITSM como proxy
- FCR es una aproximación basada en reasignaciones — no captura todos los casos de primer contacto real
- Los años 2007–2017 tienen menor volumen y calidad de registro — el análisis YoY usa 2018–2022

---

*Camila Gámez · Data Analyst*
*[LinkedIn](https://linkedin.com/in/camila-gamez) · [GitHub](https://github.com/camilagamez-co)*
