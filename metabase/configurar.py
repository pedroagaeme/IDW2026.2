"""Configura o Metabase local automaticamente (roda uma vez, no serviço metabase-setup do docker-compose).

1. espera o Metabase subir;
2. cria o admin de demonstração (somente se o Metabase ainda não foi configurado);
3. conecta o banco `idw` do PostgreSQL e espera a sincronização dos campos;
4. cria a coleção, as perguntas SQL do documento "Consultas em Linguagem Natural" e o dashboard,
   com filtros ligados às colunas do banco (semestre, curso, perfil do aluno, disciplina...).

Se a coleção já existir, nada é recriado. Usa apenas a biblioteca padrão do Python.

`python configurar.py --sql` imprime as consultas em SQL puro (sem filtros), que é o consultas/consultas.sql.
"""
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
import uuid

BASE = os.environ.get("MB_URL", "http://metabase:3000")
ADMIN_EMAIL = os.environ.get("MB_ADMIN_EMAIL", "admin@example.com")
ADMIN_SENHA = os.environ.get("MB_ADMIN_SENHA", "Idw@Demo2026")  # senha de demonstração (dados fictícios)
COLECAO = "IDW – Rendimento Acadêmico"
DASHBOARD = "IDW – Rendimento Acadêmico (dados sintéticos)"

LIMITE_REPROVACAO = 15  # X% da consulta 1.5.1: linha de limite no gráfico

# Cores da paleta do Metabase
AZUL, VERDE, ROXO, VERMELHO, AMARELO, LARANJA, CINZA = (
    "#509EE3", "#88BF4D", "#A989C5", "#EF8C8C", "#F9D45C", "#F2A86F", "#949AAB")
FAIXAS_NOTA = ["#ED6E6E", "#F2A86F", "#F9D45C", "#A7D07C", "#84BB4C"]  # do vermelho (0 a 2,9) ao verde (9 a 10)

DISCIPLINAS = [f"Disc. {i}" for i in range(102, 122)]

# Valem para todos os gráficos: sem o grupo automático "Other" (que soma as últimas categorias e gera
# valores que não existem) e com todos os rótulos de valor visíveis.
CONFIG_PADRAO = {"graph.max_categories_enabled": False, "graph.max_categories": 100,
                 "graph.label_value_frequency": "all"}


def sufixo(*colunas, texto="%"):
    """Formatação de colunas: acrescenta '%' (ou outro texto) depois do valor."""
    return {json.dumps(["name", c]): {"suffix": texto} for c in colunas}


def cores(**por_serie):
    return {serie: {"color": cor} for serie, cor in por_serie.items()}


# Bases das perguntas: o {de} do SQL vira o FROM com os joins, sempre com os mesmos apelidos,
# e os filtros do dashboard entram em {filtros} conforme os apelidos que a base tem.
BASES = {
    "aluno": ("""aluno a
    join curso c on c.id_curso = a.id_curso""", {"a", "c"}),
    "fato_aluno": ("""fatorendimentoaluno f
    join aluno a on a.id_aluno = f.id_aluno
    join curso c on c.id_curso = f.id_curso
    join data dt on dt.id_data = f.id_data
    join disciplina d on d.id_disciplina = f.id_disciplina
    join turmaaluno ta on ta.id_turmaaluno = f.id_turmaaluno""", {"a", "c", "dt", "d", "ta"}),
    "aluno_coorte": ("""aluno a
    join curso c on c.id_curso = a.id_curso
    join (select distinct id_aluno, id_turmaaluno from fatorendimentoaluno) fa on fa.id_aluno = a.id_aluno
    join turmaaluno ta on ta.id_turmaaluno = fa.id_turmaaluno""", {"a", "c", "ta"}),
    "fato_disciplina": ("""fatorendimentodisciplina f
    join curso c on c.id_curso = f.id_curso
    join data dt on dt.id_data = f.id_data
    join disciplina d on d.id_disciplina = f.id_disciplina
    join turmadisciplina t on t.id_turmadisciplina = f.id_turmadisciplina""", {"c", "dt", "d", "t"}),
}

# Filtros do dashboard ligados a colunas do banco (as opções vêm do próprio banco e aceitam vários valores):
# (chave, nome no dashboard, tabela, coluna, apelido na base, tipo)
# Ficam visíveis só nas abas em que alguma pergunta usa o filtro.
FILTROS_CAMPO = [
    # recorte institucional
    ("semestre", "Semestre", "data", "anosemestre", "dt", "string/="),
    ("centro", "Centro", "curso", "centro", "c", "string/="),
    ("campus", "Campus", "curso", "campim", "c", "string/="),
    ("departamento", "Curso / departamento", "curso", "departamento", "c", "string/="),
    ("turno", "Turno do curso", "curso", "turno", "c", "string/="),
    ("modalidade", "Modalidade de ensino", "curso", "modalidadeensino", "c", "string/="),
    ("grau", "Grau", "curso", "modalidadecurso", "c", "string/="),
    # disciplina
    ("tipo_disciplina", "Tipo de disciplina", "disciplina", "tipo", "d", "string/="),
    ("disciplina", "Disciplinas (código)", "disciplina", "id_disciplina", "d", "number/="),
    # perfil do aluno
    ("coorte", "Coorte de ingresso", "turmaaluno", "anosemestreingresso", "ta", "string/="),
    ("forma_ingresso", "Forma de ingresso", "aluno", "formaingresso", "a", "string/="),
    ("cota", "Tipo de cota", "aluno", "tipocota", "a", "string/="),
    ("faixa_economica", "Faixa econômica", "aluno", "faixaeconomica", "a", "string/="),
    ("escola", "Escola do ensino médio", "aluno", "escolaensinomedio", "a", "string/="),
    ("genero", "Gênero", "aluno", "genero", "a", "string/="),
    ("raca", "Raça/etnia", "aluno", "raca_etnia", "a", "string/="),
    ("faixa_etaria", "Faixa etária", "aluno", "faixaetaria", "a", "string/="),
    ("deficiencia", "Deficiência", "aluno", "deficiencia", "a", "string/="),
]
# Opções de um filtro limitadas pelas de outro (ex.: só os departamentos do centro escolhido)
FILTROS_LIGADOS = {"departamento": ["centro", "campus"], "campus": ["centro"]}

# Filtros de texto de perguntas específicas: (id, nome, slug, valor padrão, opções)
FILTROS_TEXTO = [
    ("f_foco", "Disciplina em foco", "disciplina_em_foco", "Disc. 105", DISCIPLINAS),
    ("f_separar", "Separar evolução por", "separar_evolucao_por", "Turno", ["Turno", "Modalidade"]),
]
FOCO = {"foco": ("Disciplina em foco", "Disc. 105", "f_foco")}
SEPARAR = {"separar_por": ("Separar por", "Turno", "f_separar")}

# Situação de integralização de cada aluno ativo no último semestre da dimensão Data (consultas 1.5.2 e 1.7).
# n = semestres decorridos desde o ingresso; ritmo regular = cargaHorariaTotal ÷ tempoMinimoConcluir por semestre.
SITUACAO = """with ref as (select ano, semestre from data order by ano desc, semestre desc limit 1),
alunos as (
    select c.departamento as curso, a.cargahorariaintegralizadaatual as ch, c.cargahorariatotal as total,
           c.tempominimoconcluir as tmin, c.tempomaximoconcluir as tmax,
           (r.ano - ta.anoingresso) * 2 + (r.semestre - ta.semestreingresso) + 1 as n
    from {de}
    cross join ref r
    where a.tipoevasao is null and c.cargahorariatotal is not null
{filtros}
),
situacao as (
    select curso, case
        when n > tmax then 'Acima do tempo máximo'
        when (total - ch) / (total * 1.0 / tmin) > tmax - n then 'Em risco de ultrapassar o tempo máximo'
        when ch < total * least(n, tmin) * 1.0 / tmin then 'Atrasado'
        else 'Dentro do fluxo' end as situacao
    from alunos
)"""
SITUACAO_NOTAS = """-- Alunos ativos no último semestre. Acima do tempo máximo: semestres decorridos > tempoMaximoConcluir.
-- Em risco: no ritmo regular (cargaHorariaTotal ÷ tempoMinimoConcluir por semestre), o que falta não cabe até o tempo máximo.
-- Atrasado: carga integralizada abaixo da esperada para os semestres decorridos. Dentro do fluxo: os demais.
"""
CORES_SITUACAO = {"dentro": ("Dentro do fluxo", VERDE), "atrasado": ("Atrasado", AMARELO),
                  "em_risco": ("Em risco de ultrapassar o tempo máximo", LARANJA),
                  "acima": ("Acima do tempo máximo", VERMELHO)}


def series_situacao(*chaves):
    return {k: {"title": CORES_SITUACAO[k][0], "color": CORES_SITUACAO[k][1]} for k in chaves}


def colunas_situacao(*chaves):
    return ",\n".join(f"       round(100.0 * count(*) filter (where situacao = '{CORES_SITUACAO[k][0]}') / count(*), 1)"
                       f" as {k}" for k in chaves)


# Cada pergunta: número no documento + nome, tipo de gráfico, configurações, base, SQL, variáveis de texto
# {nome: (rótulo, padrão, filtro do dashboard)} e altura no dashboard. O número fica só na descrição.
# Os comentários "--" do SQL viram a descrição do gráfico (ícone ⓘ no dashboard).
# A ordem da lista é a do dashboard, em pares lado a lado dentro de cada aba.
PERGUNTAS = [
    dict(
        nome="1.1 Evasão por forma de ingresso e cota (%)",
        tipo="row",
        config={"graph.dimensions": ["grupo"], "graph.metrics": ["pct_evasao"], "graph.show_values": True,
                "graph.y_axis.title_text": "% de alunos evadidos", "column_settings": sufixo("pct_evasao")},
        base="aluno",
        sql="""-- Só grupos com 10 alunos ou mais: grupos menores dão 0% ou valores extremos por acaso.
select a.formaingresso || ' / ' || a.tipocota || ' (n=' || count(*) || ')' as grupo,
       round(100.0 * count(*) filter (where a.tipoevasao is not null) / count(*), 1) as pct_evasao
from {de}
where true
{filtros}
group by a.formaingresso, a.tipocota
having count(*) >= 10
order by pct_evasao desc""",
        altura=8,
    ),
    dict(
        nome="1.2.1 Nota média de alunos de baixa renda com e sem assistência, por curso",
        tipo="row",
        config={"graph.dimensions": ["curso", "grupo"], "graph.metrics": ["media_nota"], "graph.show_values": True,
                "graph.y_axis.title_text": "Nota média (0 a 10)",
                "series_settings": cores(**{"Baixa renda – com assistência": AZUL,
                                            "Baixa renda – sem assistência": LARANJA,
                                            "Média do curso": CINZA})},
        base="fato_aluno",
        sql="""-- Assistência estudantil só existe na faixa Baixa; a média do curso serve de referência.
with base as (
    select c.departamento as curso, a.faixaeconomica, a.assistenciaestudantil, f.medianota
    from {de}
    where f.medianota is not null
{filtros}
)
select curso,
       case when assistenciaestudantil then 'Baixa renda – com assistência'
            else 'Baixa renda – sem assistência' end as grupo,
       round(avg(medianota), 2) as media_nota
from base where faixaeconomica = 'Baixa'
group by 1, 2
union all
select curso, 'Média do curso', round(avg(medianota), 2)
from base group by 1
order by curso, grupo""",
        altura=10,
    ),
    dict(
        nome="1.2.2 Alunos de baixa renda que trancaram, por turno (%)",
        tipo="bar",
        config={"graph.dimensions": ["turno", "assistencia"], "graph.metrics": ["pct_trancaram"],
                "graph.show_values": True, "graph.y_axis.title_text": "% de alunos que trancaram",
                "column_settings": sufixo("pct_trancaram"),
                "series_settings": cores(**{"Com assistência": AZUL, "Sem assistência": LARANJA})},
        base="fato_aluno",
        sql="""-- Percentual de alunos (não de matrículas) que trancaram ao menos um período.
with por_aluno as (
    select c.turno, a.assistenciaestudantil, a.id_aluno, bool_or(f.periodotrancado) as trancou
    from {de}
    where a.faixaeconomica = 'Baixa'
{filtros}
    group by 1, 2, 3
)
select turno,
       case when assistenciaestudantil then 'Com assistência' else 'Sem assistência' end as assistencia,
       round(100.0 * count(*) filter (where trancou) / count(*), 1) as pct_trancaram
from por_aluno
group by turno, assistenciaestudantil
order by case turno when 'Matutino' then 1 when 'Vespertino' then 2 when 'Noturno' then 3 else 4 end,
         assistencia""",
        altura=8,
    ),
    dict(
        nome="1.3 Nota × frequência por gênero na disciplina em foco",
        tipo="scatter",
        config={"graph.dimensions": ["nota", "genero"], "graph.metrics": ["frequencia"],
                "graph.x_axis.title_text": "Nota", "graph.y_axis.title_text": "Frequência (%)",
                "series_settings": cores(Feminino=ROXO, Masculino=AZUL)},
        base="fato_aluno",
        sql="""-- Um ponto por matrícula na "Disciplina em foco"; recorte por Faixa etária, Semestre etc. nos filtros.
-- Acima de 1.500 matrículas, mostra uma amostra fixa de 1.500 (pontos demais viram uma mancha).
select f.medianota as nota,
       round(100 - 100.0 * f.qtdfaltas / d.cargahoraria, 1) as frequencia,
       a.genero
from {de}
where not f.periodotrancado
  and f.medianota is not null
  and 'Disc. ' || f.id_disciplina = {{foco}}
{filtros}
order by md5(f.id_fatoaluno::text)
limit 1500""",
        variaveis=FOCO,
        altura=9,
    ),
    dict(
        nome="1.4 Percentual de faltas por bairro (%)",
        tipo="row",
        config={"graph.dimensions": ["bairro"], "graph.metrics": ["pct_faltas"], "graph.show_values": True,
                "graph.y_axis.title_text": "% da carga horária", "column_settings": sufixo("pct_faltas")},
        base="fato_aluno",
        sql="""-- Faltas ÷ carga horária da disciplina, sem períodos trancados.
-- A barra "MÉDIA GERAL" é a referência: bairros acima dela faltam mais que a média.
with base as (
    select a.bairroresidencia, a.id_aluno, 100.0 * f.qtdfaltas / d.cargahoraria as pct
    from {de}
    where not f.periodotrancado
{filtros}
)
select bairro, pct_faltas from (
    select bairroresidencia || ' (n=' || count(distinct id_aluno) || ')' as bairro, round(avg(pct), 1) as pct_faltas
    from base group by bairroresidencia
    union all
    select 'MÉDIA GERAL', round(avg(pct), 1) from base
) t
order by pct_faltas desc""",
        altura=12,
    ),
    dict(
        nome="1.5.1 Reprovação por disciplina, por nota e por falta (%)",
        tipo="bar",
        config={"graph.dimensions": ["disciplina"], "graph.metrics": ["reprov_nota", "reprov_falta"],
                "stackable.stack_type": "stacked", "graph.show_values": False,
                "graph.show_goal": True, "graph.goal_value": LIMITE_REPROVACAO,
                "graph.goal_label": f"Limite {LIMITE_REPROVACAO}%",
                "graph.y_axis.title_text": "% das matrículas", "column_settings": sufixo("reprov_nota", "reprov_falta"),
                "series_settings": {"reprov_nota": {"color": AMARELO, "title": "Reprovado por nota"},
                                    "reprov_falta": {"color": VERMELHO, "title": "Reprovado por falta"}}},
        base="fato_aluno",
        sql="""-- Reprovações ÷ matrículas (sem trancados). Use os filtros Curso / departamento (o Y da pergunta) e Semestre.
-- A disciplina 101 (registro de exemplo do PDF) tem 1 matrícula e fica de fora.
select 'Disc. ' || f.id_disciplina as disciplina,
       round(100.0 * count(*) filter (where f.statusaluno = 'Reprovado por Nota') / count(*), 1) as reprov_nota,
       round(100.0 * count(*) filter (where f.statusaluno = 'Reprovado por Falta') / count(*), 1) as reprov_falta
from {de}
where not f.periodotrancado
  and f.id_disciplina <> 101
{filtros}
group by f.id_disciplina
order by count(*) filter (where f.statusaluno like 'Reprovado%') * 1.0 / count(*) desc""",
        altura=12,
    ),
    dict(
        nome="1.5.2 Alunos ativos retidos por curso (%)",
        tipo="row",
        config={"graph.dimensions": ["curso"], "graph.metrics": ["atrasado", "em_risco", "acima"],
                "stackable.stack_type": "stacked", "graph.show_values": True,
                "graph.y_axis.title_text": "% dos alunos ativos",
                "column_settings": sufixo("atrasado", "em_risco", "acima"),
                "series_settings": series_situacao("atrasado", "em_risco", "acima")},
        base="aluno_coorte",
        sql=SITUACAO_NOTAS + "-- Retido = Atrasado + Em risco + Acima do tempo máximo; cursos ordenados pelo total retido.\n"
            + SITUACAO + """
select curso || ' (n=' || count(*) || ')' as curso,
""" + colunas_situacao("atrasado", "em_risco", "acima") + """
from situacao
group by curso
order by count(*) filter (where situacao <> 'Dentro do fluxo') * 1.0 / count(*) desc""",
        altura=9,
    ),
    dict(
        nome="1.6 Evasão por faixa econômica, raça/etnia e deficiência (%)",
        tipo="row",
        config={"graph.dimensions": ["grupo"], "graph.metrics": ["pct_evasao"], "graph.show_values": True,
                "graph.y_axis.title_text": "% de alunos evadidos", "column_settings": sufixo("pct_evasao")},
        base="aluno",
        sql="""-- Cada característica analisada separadamente; "TAXA GERAL" é a referência.
-- Evadidos e não evadidos têm faltas e notas quase iguais nestes dados, por isso barras em vez de Sankey.
with base as (
    select a.tipoevasao is not null as evadiu, a.faixaeconomica, a.raca_etnia, a.deficiencia
    from {de}
    where true
{filtros}
), grupos as (
    select 0 as ordem, 0 as sub, 'TAXA GERAL' as nome, count(*) as n, count(*) filter (where evadiu) as ev
    from base
    union all
    select 1, case faixaeconomica when 'Baixa' then 1 when 'Média' then 2 else 3 end,
           'Faixa econômica: ' || faixaeconomica, count(*), count(*) filter (where evadiu)
    from base group by faixaeconomica
    union all
    select 2, 0, 'Raça/etnia: ' || raca_etnia, count(*), count(*) filter (where evadiu)
    from base group by raca_etnia
    union all
    select 3, 0, case when deficiencia = 'Nenhuma' then 'Sem deficiência' else 'Com deficiência' end,
           count(*), count(*) filter (where evadiu)
    from base group by 3
)
select nome || ' (n=' || n || ')' as grupo, round(100.0 * ev / n, 1) as pct_evasao
from grupos
order by ordem, sub, 100.0 * ev / n desc""",
        altura=9,
    ),
    dict(
        nome="1.7 Situação de integralização dos alunos ativos por curso (%)",
        tipo="row",
        config={"graph.dimensions": ["curso"], "graph.metrics": ["dentro", "atrasado", "em_risco", "acima"],
                "stackable.stack_type": "normalized", "graph.show_values": True,
                "series_settings": series_situacao("dentro", "atrasado", "em_risco", "acima")},
        base="aluno_coorte",
        sql=SITUACAO_NOTAS + SITUACAO + """
select curso || ' (n=' || count(*) || ')' as curso,
""" + colunas_situacao("dentro", "atrasado", "em_risco", "acima") + """
from situacao
group by curso
order by curso""",
        altura=9,
    ),
    dict(
        nome="2.1 Resultados de cada professor na disciplina em foco (%)",
        tipo="row",
        config={"graph.dimensions": ["professor"],
                "graph.metrics": ["aprovados", "reprovados_nota", "reprovados_falta"],
                "stackable.stack_type": "normalized", "graph.show_values": True,
                "series_settings": {"aprovados": {"color": VERDE, "title": "Aprovados"},
                                    "reprovados_nota": {"color": AMARELO, "title": "Reprovados por nota"},
                                    "reprovados_falta": {"color": VERMELHO, "title": "Reprovados por falta"}}},
        base="fato_disciplina",
        sql="""-- Escolha a disciplina no filtro "Disciplina em foco". "DISCIPLINA TODA" é a referência.
-- Professor responsável pela turma (id_professor1); ordenado pela taxa de reprovação total.
with base as (
    select p.nome as professor, f.qtdaprovacoesnota as ap, f.qtdreprovacoesnota as rn, f.qtdreprovacoesfalta as rf
    from {de}
    join professor p on p.id_professor = t.id_professor1
    where 'Disc. ' || f.id_disciplina = {{foco}}
{filtros}
)
select professor, aprovados, reprovados_nota, reprovados_falta from (
    select professor, sum(ap) as aprovados, sum(rn) as reprovados_nota, sum(rf) as reprovados_falta, 1 as ordem
    from base group by professor
    union all
    select 'DISCIPLINA TODA', sum(ap), sum(rn), sum(rf), 0 from base
) t
order by ordem, (reprovados_nota + reprovados_falta) * 1.0
                / nullif(aprovados + reprovados_nota + reprovados_falta, 0) desc""",
        variaveis=FOCO,
        altura=9,
    ),
    dict(
        nome="2.2 Distribuição das notas por departamento (%)",
        tipo="row",
        config={"graph.dimensions": ["departamento"],
                "graph.metrics": ["0 a 2,9", "3 a 6,9", "7 a 7,9", "8 a 8,9", "9 a 10"],
                "stackable.stack_type": "normalized", "graph.show_values": True,
                "series_settings": cores(**dict(zip(["0 a 2,9", "3 a 6,9", "7 a 7,9", "8 a 8,9", "9 a 10"],
                                                    FAIXAS_NOTA)))},
        base="fato_disciplina",
        sql="""-- Em 100% dá para comparar departamentos de tamanhos diferentes.
-- Ordenado pela parcela de notas 8 ou mais.
select c.departamento,
       sum(f.qtdnotas0_2_9) as "0 a 2,9",
       sum(f.qtdnotas3_6_9) as "3 a 6,9",
       sum(f.qtdnotas7_7_9) as "7 a 7,9",
       sum(f.qtdnotas8_8_9) as "8 a 8,9",
       sum(f.qtdnotas9_10)  as "9 a 10"
from {de}
where true
{filtros}
group by 1
order by (sum(f.qtdnotas8_8_9) + sum(f.qtdnotas9_10)) * 1.0
         / nullif(sum(f.qtdnotas0_2_9 + f.qtdnotas3_6_9 + f.qtdnotas7_7_9 + f.qtdnotas8_8_9 + f.qtdnotas9_10), 0) desc""",
        altura=9,
    ),
    dict(
        nome="2.3a Aprovação por nota ao longo dos semestres (%)",
        tipo="line",
        config={"graph.dimensions": ["semestre", "grupo"], "graph.metrics": ["pct_aprovacao"],
                "graph.y_axis.title_text": "% aprovados por nota", "column_settings": sufixo("pct_aprovacao")},
        base="fato_disciplina",
        sql="""-- Aprovados por nota ÷ matriculados. Use o filtro "Separar evolução por" (Turno ou Modalidade).
select dt.anosemestre as semestre,
       case when lower({{separar_por}}) = 'modalidade' then c.modalidadeensino else c.turno end as grupo,
       round(100.0 * sum(f.qtdaprovacoesnota) / sum(f.qtdmatriculados), 1) as pct_aprovacao
from {de}
where true
{filtros}
group by 1, 2
order by 1, 2""",
        variaveis=SEPARAR,
        altura=8,
    ),
    dict(
        nome="2.3b Faltas ao longo dos semestres (% da carga horária)",
        tipo="line",
        config={"graph.dimensions": ["semestre", "grupo"], "graph.metrics": ["pct_faltas"],
                "graph.y_axis.title_text": "% da carga horária", "column_settings": sufixo("pct_faltas")},
        base="fato_disciplina",
        sql="""-- Média de faltas ponderada pelos matriculados, convertida em % da carga horária da disciplina.
select dt.anosemestre as semestre,
       case when lower({{separar_por}}) = 'modalidade' then c.modalidadeensino else c.turno end as grupo,
       round(sum(f.mediafaltas * f.qtdmatriculados / d.cargahoraria * 100) / sum(f.qtdmatriculados), 1)
         as pct_faltas
from {de}
where true
{filtros}
group by 1, 2
order by 1, 2""",
        variaveis=SEPARAR,
        altura=8,
    ),
    dict(
        nome="2.7a Mediana das notas por disciplina e horário",
        tipo="bar",
        config={"graph.dimensions": ["disciplina", "horario"], "graph.metrics": ["mediana_notas"],
                "graph.show_values": False, "graph.y_axis.title_text": "Mediana das notas",
                "series_settings": cores(**{"Seg/Qua – manhã": AZUL, "Ter/Qui – noite": ROXO})},
        base="fato_disciplina",
        sql="""-- Horário traduzido: 2 = segunda, 3 = terça, 4 = quarta, 5 = quinta; M = manhã, N = noite.
select 'Disc. ' || f.id_disciplina as disciplina,
       case t.horario when '24M12' then 'Seg/Qua – manhã' when '35N12' then 'Ter/Qui – noite' else t.horario end
         as horario,
       round(avg(f.medianotas), 2) as mediana_notas
from {de}
where f.id_disciplina <> 101
{filtros}
group by f.id_disciplina, t.horario
order by f.id_disciplina, t.horario""",
        altura=8,
    ),
    dict(
        nome="2.7b Reprovação por falta por disciplina e horário (%)",
        tipo="bar",
        config={"graph.dimensions": ["disciplina", "horario"], "graph.metrics": ["pct_reprov_falta"],
                "graph.show_values": False, "graph.y_axis.title_text": "% reprovados por falta",
                "column_settings": sufixo("pct_reprov_falta"),
                "series_settings": cores(**{"Seg/Qua – manhã": AZUL, "Ter/Qui – noite": ROXO})},
        base="fato_disciplina",
        sql="""-- Reprovados por falta ÷ matriculados, mesma disciplina em horários diferentes.
select 'Disc. ' || f.id_disciplina as disciplina,
       case t.horario when '24M12' then 'Seg/Qua – manhã' when '35N12' then 'Ter/Qui – noite' else t.horario end
         as horario,
       round(100.0 * sum(f.qtdreprovacoesfalta) / sum(f.qtdmatriculados), 1) as pct_reprov_falta
from {de}
where f.id_disciplina <> 101
{filtros}
group by f.id_disciplina, t.horario
order by f.id_disciplina, t.horario""",
        altura=8,
    ),
    dict(
        nome="2.4 Disciplinas obrigatórias mais críticas por centro (% de notas de 0 a 2,9)",
        tipo="row",
        config={"graph.dimensions": ["disciplina"], "graph.metrics": ["pct_notas_criticas"],
                "graph.show_values": True, "graph.y_axis.title_text": "% das notas entre 0 e 2,9",
                "column_settings": sufixo("pct_notas_criticas")},
        base="fato_disciplina",
        sql="""-- As 10 combinações centro × disciplina obrigatória com maior parcela de notas críticas.
select c.centro || ' · Disc. ' || f.id_disciplina as disciplina,
       round(100.0 * sum(f.qtdnotas0_2_9)
             / sum(f.qtdnotas0_2_9 + f.qtdnotas3_6_9 + f.qtdnotas7_7_9 + f.qtdnotas8_8_9 + f.qtdnotas9_10), 1)
         as pct_notas_criticas
from {de}
where d.tipo = 'Obrigatória' and f.id_disciplina <> 101
{filtros}
group by c.centro, f.id_disciplina
order by pct_notas_criticas desc
limit 10""",
        altura=8,
    ),
    dict(
        nome="2.5 Co-docência: aprovação e amplitude das notas por nº de professores",
        tipo="combo",
        config={"graph.dimensions": ["grupo"], "graph.metrics": ["pct_aprovacao", "amplitude_media"],
                "graph.show_values": True, "column_settings": sufixo("pct_aprovacao"),
                "series_settings": {"pct_aprovacao": {"display": "bar", "color": VERDE, "axis": "left",
                                                      "title": "% aprovados por nota"},
                                    "amplitude_media": {"display": "line", "color": ROXO, "axis": "right",
                                                        "title": "Amplitude média (maior − menor nota)"}}},
        base="fato_disciplina",
        sql="""-- Taxa de aprovação por nota (barras) e amplitude média das notas, maior − menor (linha, eixo direito),
-- por número de professores da turma.
with turmas as (
    select f.*, 1 + (t.id_professor2 is not null)::int + (t.id_professor3 is not null)::int as n_prof
    from {de}
    where f.id_disciplina <> 101
{filtros}
)
select case n_prof when 1 then 'Docente único' else n_prof || ' professores' end
         || ' (' || count(distinct id_turmadisciplina) || ' turmas)' as grupo,
       round(100.0 * sum(qtdaprovacoesnota) / sum(qtdmatriculados), 1) as pct_aprovacao,
       round(avg(maiornota - menornota), 2) as amplitude_media
from turmas
group by n_prof
order by n_prof""",
        altura=8,
    ),
    dict(
        nome="2.6 Matriculados por semestre e modalidade de ensino",
        tipo="area",
        config={"graph.dimensions": ["semestre", "modalidade"], "graph.metrics": ["matriculados"],
                "stackable.stack_type": "stacked", "graph.show_values": True,
                "series_settings": cores(Presencial=AZUL, EAD=VERDE)},
        base="fato_disciplina",
        sql="""-- Área empilhada: a altura total é a demanda do semestre; cada cor, a parcela da modalidade.
select dt.anosemestre as semestre, c.modalidadeensino as modalidade, sum(f.qtdmatriculados) as matriculados
from {de}
where true
{filtros}
group by 1, 2
order by 1, 2""",
        altura=8,
    ),
]

# Abas do dashboard, uma por esquema do documento: (prefixo do número da pergunta, título)
ABAS = [("1.", "Esquema 1 – Rendimento do aluno"), ("2.", "Esquema 2 – Rendimento da disciplina")]

TIPOS = {"row": "barras horizontais", "bar": "barras", "line": "linhas", "scatter": "dispersão",
         "area": "área empilhada", "combo": "barras + linha"}


def numero(p):
    return p["nome"].split(" ", 1)[0]


def titulo(p):
    return p["nome"].split(" ", 1)[1]


def filtros_da(p):
    """Filtros de campo que se aplicam à pergunta: os que usam tabelas presentes na base dela.
    Perguntas da "Disciplina em foco" ignoram o filtro "Disciplinas" (os dois juntos podem não se cruzar)."""
    apelidos = BASES[p["base"]][1]
    return [f for f in FILTROS_CAMPO
            if f[4] in apelidos and not (f[0] == "disciplina" and "foco" in p.get("variaveis", {}))]


def sql_final(p):
    linhas = "\n".join(f"  [[and {{{{{f[0]}}}}}]]" for f in filtros_da(p))
    return p["sql"].replace("{de}", BASES[p["base"]][0]).replace("{filtros}", linhas)


def sql_puro(p):
    """SQL sem filtros opcionais e com as variáveis obrigatórias no valor padrão (para rodar fora do Metabase)."""
    sql = re.sub(r"\n\s*\[\[.*?\]\]", "", sql_final(p))
    for nome, (_rotulo, padrao, _filtro) in p.get("variaveis", {}).items():
        sql = sql.replace(f"{{{{{nome}}}}}", f"'{padrao}'")
    return sql


def descricao(p):
    """Número da consulta no documento + os comentários '--' do SQL (texto do ícone ⓘ do gráfico)."""
    notas = " ".join(l[2:].strip() for l in p["sql"].splitlines() if l.startswith("--"))
    return f"Consulta {numero(p)} do documento. {notas}".strip()


def chamar(metodo, caminho, corpo=None, sessao=None):
    cabecalhos = {"Content-Type": "application/json"}
    if sessao:
        cabecalhos["X-Metabase-Session"] = sessao
    dados = json.dumps(corpo).encode("utf-8") if corpo is not None else None
    req = urllib.request.Request(BASE + caminho, data=dados, headers=cabecalhos, method=metodo)
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            texto = resp.read().decode("utf-8")
            return json.loads(texto) if texto else None
    except urllib.error.HTTPError as erro:
        detalhe = erro.read().decode("utf-8", "replace")[:300]
        raise RuntimeError(f"{metodo} {caminho} -> HTTP {erro.code}: {detalhe}") from None


def esperar_metabase(limite_s=900):
    print("Aguardando o Metabase iniciar (a primeira vez leva alguns minutos)...", flush=True)
    inicio = time.time()
    while time.time() - inicio < limite_s:
        try:
            if chamar("GET", "/api/health").get("status") == "ok":
                return
        except Exception:
            pass
        time.sleep(5)
    sys.exit("O Metabase não respondeu a tempo.")


def esperar_campos(banco, sessao, limite_s=300):
    """Espera o Metabase sincronizar o banco e devolve {(tabela, coluna): id do campo}."""
    print("Aguardando a sincronização das tabelas...", flush=True)
    precisa = {(f[2], f[3]) for f in FILTROS_CAMPO}
    inicio = time.time()
    while time.time() - inicio < limite_s:
        meta = chamar("GET", f"/api/database/{banco}/metadata", sessao=sessao)
        campos = {(t["name"], c["name"]): c["id"] for t in meta["tables"] for c in t["fields"]}
        if precisa <= campos.keys():
            return campos
        time.sleep(5)
    sys.exit(f"O Metabase não sincronizou as colunas: {sorted(precisa - campos.keys())}")


def variaveis_da_pergunta(pergunta, campos):
    """Monta as template-tags: variáveis de texto da pergunta + filtros de campo ligados às colunas."""
    tags = {}
    for nome, (rotulo, padrao, _filtro) in pergunta.get("variaveis", {}).items():
        tags[nome] = {"id": str(uuid.uuid4()), "name": nome, "display-name": rotulo, "type": "text",
                      "default": padrao, "required": True}
    for chave, rotulo, tabela, coluna, apelido, tipo in filtros_da(pergunta):
        tags[chave] = {"id": str(uuid.uuid4()), "name": chave, "display-name": rotulo, "type": "dimension",
                       "dimension": ["field", campos[(tabela, coluna)], None], "widget-type": tipo,
                       "alias": f"{apelido}.{coluna}"}
    return tags


def layout(perguntas_ids):
    """Uma aba por esquema; em cada aba, duas colunas de 12 (a linha usa a altura do maior cartão do par)."""
    cartoes = []
    for n_aba, (prefixo, _titulo) in enumerate(ABAS, start=1):
        da_aba = [x for x in perguntas_ids if x[0]["nome"].startswith(prefixo)]
        linha = 0
        for i in range(0, len(da_aba), 2):
            par = da_aba[i:i + 2]
            altura = max(p["altura"] for p, _ in par)
            for j, (pergunta, card_id) in enumerate(par):
                cartoes.append({"pergunta": pergunta, "card_id": card_id, "aba": -n_aba, "row": linha,
                                "col": j * 12, "size_x": 12 if len(par) == 2 else 24, "size_y": altura})
            linha += altura
    return cartoes


def montar_dashboard(dash, perguntas_ids, sessao):
    cartoes = layout(perguntas_ids)
    abas = [{"id": -n, "name": nome} for n, (_prefixo, nome) in enumerate(ABAS, start=1)]

    def dashcards(com_filtros):
        lista = []
        for c in cartoes:
            base = {"id": -(len(lista) + 1), "dashboard_tab_id": c["aba"], "row": c["row"], "col": c["col"],
                    "size_x": c["size_x"], "size_y": c["size_y"]}
            mapeamentos = []
            if com_filtros:
                for nome, (_rotulo, _padrao, filtro) in c["pergunta"].get("variaveis", {}).items():
                    mapeamentos.append({"parameter_id": filtro, "card_id": c["card_id"],
                                        "target": ["variable", ["template-tag", nome]]})
                for f in filtros_da(c["pergunta"]):
                    mapeamentos.append({"parameter_id": f"p_{f[0]}", "card_id": c["card_id"],
                                        "target": ["dimension", ["template-tag", f[0]]]})
            lista.append({**base, "card_id": c["card_id"], "visualization_settings": {},
                          "parameter_mappings": mapeamentos})
        return lista

    def filtros(com_opcoes):
        lista = []
        for chave, nome, _tabela, _coluna, _apelido, tipo in FILTROS_CAMPO:
            lista.append({"id": f"p_{chave}", "name": nome, "slug": chave, "type": tipo,
                          "sectionId": tipo.split("/")[0],
                          "filteringParameters": [f"p_{x}" for x in FILTROS_LIGADOS.get(chave, [])]})
        for fid, nome, slug, padrao, opcoes in FILTROS_TEXTO:
            f = {"id": fid, "name": nome, "slug": slug, "type": "string/=", "default": [padrao]}
            if com_opcoes:
                f.update({"values_source_type": "static-list", "values_source_config": {"values": opcoes}})
            lista.append(f)
        return lista

    # Do mais completo ao mais simples: se uma versão do Metabase recusar algo, o dashboard sai mesmo assim.
    tentativas = [
        ("com filtros e opções", dashcards(True), filtros(True)),
        ("com filtros", dashcards(True), filtros(False)),
        ("sem filtros (use os filtros de cada pergunta)", dashcards(False), []),
    ]
    for versao, cards, params in tentativas:
        try:
            chamar("PUT", f"/api/dashboard/{dash}",
                   {"parameters": params, "dashcards": cards, "tabs": abas, "width": "full"}, sessao)
            print(f"Dashboard montado {versao}.", flush=True)
            return
        except RuntimeError as erro:
            print(f"Não deu para montar o dashboard {versao}: {erro}", flush=True)
    sys.exit("Não foi possível montar o dashboard.")


def imprimir_sql():
    sys.stdout.reconfigure(encoding="utf-8", newline="\n")
    print('-- Consultas do documento "Consultas em Linguagem Natural", as mesmas que metabase/configurar.py cria '
          "no Metabase.\n"
          "-- Gerado por: python metabase/configurar.py --sql > consultas/consultas.sql (não edite à mão).\n"
          "-- Sem os filtros do dashboard; variáveis obrigatórias no valor padrão.\n"
          "-- Em PostgreSQL, os nomes sem aspas ficam em minúsculas (ex.: FatoRendimentoAluno -> fatorendimentoaluno).")
    for p in PERGUNTAS:
        print(f"\n-- {p['nome']}  [{TIPOS[p['tipo']]}]\n{sql_puro(p)};")


def main():
    esperar_metabase()

    props = chamar("GET", "/api/session/properties")
    token = props.get("setup-token")
    if token:
        print("Criando o admin de demonstração...", flush=True)
        chamar("POST", "/api/setup", {
            "token": token,
            "user": {"first_name": "Admin", "last_name": "IDW", "email": ADMIN_EMAIL,
                     "password": ADMIN_SENHA, "site_name": "IDW 2026.2"},
            "prefs": {"site_name": "IDW 2026.2", "allow_tracking": False},
        })

    try:
        sessao = chamar("POST", "/api/session", {"username": ADMIN_EMAIL, "password": ADMIN_SENHA})["id"]
    except RuntimeError:
        print("O Metabase já foi configurado com outro admin; configure o banco e as perguntas manualmente "
              "(consultas em consultas/consultas.sql).")
        return

    colecoes = chamar("GET", "/api/collection", sessao=sessao)
    if any(c.get("name") == COLECAO for c in colecoes):
        print("Coleção já existe; nada a fazer. Para recriar: docker compose down -v && docker compose up -d")
        return

    # Interface em português e números no formato brasileiro (12,5% em vez de 12.5%).
    for chave, valor in [("site-locale", "pt_BR"),
                         ("custom-formatting", {"type/Number": {"number_separators": ",."}})]:
        try:
            chamar("PUT", f"/api/setting/{chave}", {"value": valor}, sessao)
        except RuntimeError as erro:
            print(f"Não deu para ajustar {chave}: {erro}", flush=True)

    print("Conectando o banco idw...", flush=True)
    banco = chamar("POST", "/api/database", {
        "engine": "postgres", "name": "IDW",
        "details": {"host": "idw-postgres", "port": 5432, "dbname": "idw", "user": "idw",
                    "password": "idw_local", "ssl": False, "tunnel-enabled": False},
        "is_full_sync": True,
    }, sessao)["id"]
    campos = esperar_campos(banco, sessao)

    colecao = chamar("POST", "/api/collection", {
        "name": COLECAO, "description": "Consultas do documento (dados sintéticos)"}, sessao)["id"]

    print(f"Criando as {len(PERGUNTAS)} perguntas...", flush=True)
    perguntas_ids = []
    for p in PERGUNTAS:
        carta = chamar("POST", "/api/card", {
            "name": titulo(p), "description": descricao(p), "collection_id": colecao, "display": p["tipo"],
            "dataset_query": {"type": "native", "database": banco,
                              "native": {"query": sql_final(p), "template-tags": variaveis_da_pergunta(p, campos)}},
            "visualization_settings": {**CONFIG_PADRAO, **p["config"]},
        }, sessao)
        perguntas_ids.append((p, carta["id"]))

    print("Montando o dashboard...", flush=True)
    dash = chamar("POST", "/api/dashboard", {"name": DASHBOARD, "collection_id": colecao}, sessao)["id"]
    montar_dashboard(dash, perguntas_ids, sessao)

    print(f"Pronto! Abra {BASE.replace('metabase', 'localhost')}/dashboard/{dash}", flush=True)


if __name__ == "__main__":
    imprimir_sql() if sys.argv[1:] == ["--sql"] else main()
