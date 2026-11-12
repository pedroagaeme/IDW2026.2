"""Configura o Metabase local automaticamente (roda uma vez, no serviço metabase-setup do docker-compose).

1. espera o Metabase subir;
2. cria o admin de demonstração (somente se o Metabase ainda não foi configurado);
3. conecta o banco `idw` do PostgreSQL;
4. cria a coleção, as perguntas SQL do documento "Consultas em Linguagem Natural" e o dashboard,
   com os filtros (disciplina, departamento, semestre...) ligados às perguntas.

Se a coleção já existir, nada é recriado. Usa apenas a biblioteca padrão do Python.
"""
import json
import os
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

# Expressões reutilizadas
PCT_FALTAS = "100.0 * f.qtdfaltas / (d.cargahoraria / 2.0)"  # faltas ÷ aulas previstas (carga horária ÷ 2)
DISCIPLINAS = [f"Disc. {i}" for i in range(102, 110)]
DEPARTAMENTOS = ["Administração", "Computação", "Engenharia Civil", "Física", "Letras", "Medicina",
                 "Sistemas de Informação"]
SEMESTRES = ["2023.1", "2023.2", "2024.1", "2024.2", "2025.1", "2025.2"]


def sufixo(*colunas, texto="%"):
    """Formatação de colunas: acrescenta '%' (ou outro texto) depois do valor."""
    return {json.dumps(["name", c]): {"suffix": texto} for c in colunas}


def cores(**por_serie):
    return {serie: {"color": cor} for serie, cor in por_serie.items()}


# Filtros do dashboard: (id, nome, slug, valor padrão, opções)
FILTROS = [
    ("f_disc13", "Disciplina (1.3)", "disciplina_1_3", "Disc. 105", DISCIPLINAS),
    ("f_faixa13", "Faixa etária (1.3)", "faixa_etaria_1_3", None, ["18-20", "21-25", "26-30", "31+"]),
    ("f_dep151", "Departamento (1.5.1)", "departamento_1_5_1", None, DEPARTAMENTOS),
    ("f_sem151", "Semestre (1.5.1)", "semestre_1_5_1", None, SEMESTRES),
    ("f_disc21", "Disciplina (2.1)", "disciplina_2_1", "Disc. 102", DISCIPLINAS),
    ("f_seg23", "Separar por (2.3)", "separar_por_2_3", "Turno", ["Turno", "Modalidade"]),
]

# Cada pergunta: nome, tipo de gráfico, configurações, SQL, variáveis {nome: (rótulo, padrão, filtro do dashboard)},
# altura no dashboard. Variáveis com padrão são obrigatórias; sem padrão, o trecho [[...]] some quando vazio.
# A ordem da lista é a do dashboard, em pares lado a lado (a 2.4 vem antes da 2.3 para os pares 2.3a/b e 2.7a/b).
PERGUNTAS = [
    dict(
        nome="1.1 Evasão por forma de ingresso e cota (%)",
        tipo="row",
        config={"graph.dimensions": ["grupo"], "graph.metrics": ["pct_evasao"], "graph.show_values": True,
                "graph.y_axis.title_text": "% de alunos evadidos", "column_settings": sufixo("pct_evasao")},
        sql="""-- Só grupos com 10 alunos ou mais: grupos menores dão 0% ou valores extremos por acaso.
select formaingresso || ' / ' || tipocota || ' (n=' || count(*) || ')' as grupo,
       round(100.0 * count(*) filter (where tipoevasao is not null) / count(*), 1) as pct_evasao
from aluno
group by formaingresso, tipocota
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
        sql="""-- Assistência estudantil só existe na faixa Baixa; a média do curso serve de referência.
-- O curso 1 (registro de exemplo do PDF) tem um único aluno e fica de fora.
with base as (
    select c.departamento as curso, a.faixaeconomica, a.assistenciaestudantil, f.medianota
    from fatorendimentoaluno f
    join aluno a on a.id_aluno = f.id_aluno
    join curso c on c.id_curso = f.id_curso
    where f.medianota is not null and f.id_curso <> 1
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
        sql="""-- Percentual de alunos (não de matrículas) que trancaram ao menos um período.
-- Atenção ao ler: no Matutino e no Vespertino há só 2 alunos sem assistência.
with por_aluno as (
    select c.turno, a.assistenciaestudantil, a.id_aluno, bool_or(f.periodotrancado) as trancou
    from fatorendimentoaluno f
    join aluno a on a.id_aluno = f.id_aluno
    join curso c on c.id_curso = f.id_curso
    where a.faixaeconomica = 'Baixa'
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
        nome="1.3 Nota × frequência por gênero (um ponto por aluno)",
        tipo="scatter",
        config={"graph.dimensions": ["nota", "genero"], "graph.metrics": ["frequencia"],
                "graph.x_axis.title_text": "Nota", "graph.y_axis.title_text": "Frequência (%)",
                "series_settings": cores(Feminino=ROXO, Masculino=AZUL)},
        sql=f"""-- Escolha a disciplina e, se quiser, a faixa etária nos filtros do dashboard.
-- O registro do PDF com faixa "20-25" entra em 21-25.
select f.medianota as nota,
       round(100 - {PCT_FALTAS}, 1) as frequencia,
       a.genero
from fatorendimentoaluno f
join aluno a on a.id_aluno = f.id_aluno
join disciplina d on d.id_disciplina = f.id_disciplina
where not f.periodotrancado
  and f.medianota is not null
  and 'Disc. ' || f.id_disciplina = {{{{disciplina}}}}
  [[and case when a.faixaetaria = '20-25' then '21-25' else a.faixaetaria end = {{{{faixa_etaria}}}}]]""",
        variaveis={"disciplina": ("Disciplina", "Disc. 105", "f_disc13"),
                   "faixa_etaria": ("Faixa etária", None, "f_faixa13")},
        altura=9,
    ),
    dict(
        nome="1.4 Percentual de faltas por bairro (%)",
        tipo="row",
        config={"graph.dimensions": ["bairro"], "graph.metrics": ["pct_faltas"], "graph.show_values": True,
                "graph.y_axis.title_text": "% das aulas previstas", "column_settings": sufixo("pct_faltas")},
        sql=f"""-- Faltas ÷ aulas previstas (carga horária ÷ 2), sem períodos trancados.
-- A barra "MÉDIA GERAL" é a referência: bairros acima dela faltam mais que a média.
with base as (
    select a.bairroresidencia, a.id_aluno, {PCT_FALTAS} as pct
    from fatorendimentoaluno f
    join aluno a on a.id_aluno = f.id_aluno
    join disciplina d on d.id_disciplina = f.id_disciplina
    where not f.periodotrancado
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
                "stackable.stack_type": "stacked", "graph.show_values": True,
                "graph.show_goal": True, "graph.goal_value": LIMITE_REPROVACAO,
                "graph.goal_label": f"Limite {LIMITE_REPROVACAO}%",
                "graph.y_axis.title_text": "% das matrículas", "column_settings": sufixo("reprov_nota", "reprov_falta"),
                "series_settings": {"reprov_nota": {"color": AMARELO, "title": "Reprovado por nota"},
                                    "reprov_falta": {"color": VERMELHO, "title": "Reprovado por falta"}}},
        sql="""-- Reprovações ÷ matrículas (sem trancados), filtrável por departamento (Y) e semestre.
-- A disciplina 101 (registro de exemplo do PDF) tem 1 matrícula e fica de fora.
select 'Disc. ' || f.id_disciplina as disciplina,
       round(100.0 * count(*) filter (where f.statusaluno = 'Reprovado por Nota') / count(*), 1) as reprov_nota,
       round(100.0 * count(*) filter (where f.statusaluno = 'Reprovado por Falta') / count(*), 1) as reprov_falta
from fatorendimentoaluno f
join curso c on c.id_curso = f.id_curso
join data dt on dt.id_data = f.id_data
where not f.periodotrancado
  and f.id_disciplina <> 101
  [[and c.departamento = {{departamento}}]]
  [[and dt.anosemestre = {{semestre}}]]
group by f.id_disciplina
order by count(*) filter (where f.statusaluno like 'Reprovado%') * 1.0 / count(*) desc""",
        variaveis={"departamento": ("Departamento", None, "f_dep151"),
                   "semestre": ("Semestre", None, "f_sem151")},
        altura=9,
    ),
    dict(
        nome="1.6 Evasão por faixa econômica, raça/etnia e deficiência (%)",
        tipo="row",
        config={"graph.dimensions": ["grupo"], "graph.metrics": ["pct_evasao"], "graph.show_values": True,
                "graph.y_axis.title_text": "% de alunos evadidos", "column_settings": sufixo("pct_evasao")},
        sql="""-- Cada característica analisada separadamente; "TAXA GERAL" é a referência.
-- Evadidos e não evadidos têm faltas e notas quase iguais nestes dados, por isso barras em vez de Sankey.
with base as (
    select tipoevasao is not null as evadiu, faixaeconomica, raca_etnia, deficiencia from aluno
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
        nome="2.1 Resultados de cada professor na disciplina (%)",
        tipo="row",
        config={"graph.dimensions": ["professor"],
                "graph.metrics": ["aprovados", "reprovados_nota", "reprovados_falta"],
                "stackable.stack_type": "normalized", "graph.show_values": True,
                "series_settings": {"aprovados": {"color": VERDE, "title": "Aprovados"},
                                    "reprovados_nota": {"color": AMARELO, "title": "Reprovados por nota"},
                                    "reprovados_falta": {"color": VERMELHO, "title": "Reprovados por falta"}}},
        sql="""-- Escolha a disciplina no filtro do dashboard. "DISCIPLINA TODA" é a referência.
-- Professores ordenados pela taxa de reprovação total.
with base as (
    select p.nome as professor, f.qtdaprovacoesnota as ap, f.qtdreprovacoesnota as rn, f.qtdreprovacoesfalta as rf
    from fatorendimentodisciplina f
    join turmadisciplina t on t.id_turmadisciplina = f.id_turmadisciplina
    join professor p on p.id_professor = t.id_professor1
    where 'Disc. ' || f.id_disciplina = {{disciplina}}
)
select professor, aprovados, reprovados_nota, reprovados_falta from (
    select professor, sum(ap) as aprovados, sum(rn) as reprovados_nota, sum(rf) as reprovados_falta, 1 as ordem
    from base group by professor
    union all
    select 'DISCIPLINA TODA', sum(ap), sum(rn), sum(rf), 0 from base
) t
order by ordem, (reprovados_nota + reprovados_falta) * 1.0
                / nullif(aprovados + reprovados_nota + reprovados_falta, 0) desc""",
        variaveis={"disciplina": ("Disciplina", "Disc. 102", "f_disc21")},
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
        sql="""-- Em 100% dá para comparar departamentos de tamanhos diferentes.
-- Ordenado pela parcela de notas 8 ou mais.
select c.departamento,
       sum(f.qtdnotas0_2_9) as "0 a 2,9",
       sum(f.qtdnotas3_6_9) as "3 a 6,9",
       sum(f.qtdnotas7_7_9) as "7 a 7,9",
       sum(f.qtdnotas8_8_9) as "8 a 8,9",
       sum(f.qtdnotas9_10)  as "9 a 10"
from fatorendimentodisciplina f
join curso c on c.id_curso = f.id_curso
group by 1
order by (sum(f.qtdnotas8_8_9) + sum(f.qtdnotas9_10)) * 1.0
         / nullif(sum(f.qtdnotas0_2_9 + f.qtdnotas3_6_9 + f.qtdnotas7_7_9 + f.qtdnotas8_8_9 + f.qtdnotas9_10), 0) desc""",
        altura=9,
    ),
    dict(
        nome="2.4 Disciplinas obrigatórias mais críticas por centro (% de notas de 0 a 2,9)",
        tipo="row",
        config={"graph.dimensions": ["disciplina"], "graph.metrics": ["pct_notas_criticas"],
                "graph.show_values": True, "graph.y_axis.title_text": "% das notas entre 0 e 2,9",
                "column_settings": sufixo("pct_notas_criticas")},
        sql="""-- As 10 combinações centro × disciplina obrigatória com maior parcela de notas críticas.
select c.centro || ' · Disc. ' || f.id_disciplina as disciplina,
       round(100.0 * sum(f.qtdnotas0_2_9)
             / sum(f.qtdnotas0_2_9 + f.qtdnotas3_6_9 + f.qtdnotas7_7_9 + f.qtdnotas8_8_9 + f.qtdnotas9_10), 1)
         as pct_notas_criticas
from fatorendimentodisciplina f
join curso c on c.id_curso = f.id_curso
join disciplina d on d.id_disciplina = f.id_disciplina
where d.tipo = 'Obrigatória' and f.id_disciplina <> 101
group by c.centro, f.id_disciplina
order by pct_notas_criticas desc
limit 10""",
        altura=8,
    ),
    dict(
        nome="2.3a Aprovação por nota ao longo dos semestres (%)",
        tipo="line",
        config={"graph.dimensions": ["semestre", "grupo"], "graph.metrics": ["pct_aprovacao"],
                "graph.y_axis.title_text": "% aprovados por nota", "column_settings": sufixo("pct_aprovacao")},
        sql="""-- Aprovados por nota ÷ matriculados. Use o filtro "Separar por" (Turno ou Modalidade).
select dt.anosemestre as semestre,
       case when lower({{separar_por}}) = 'modalidade' then c.modalidadeensino else c.turno end as grupo,
       round(100.0 * sum(f.qtdaprovacoesnota) / sum(f.qtdmatriculados), 1) as pct_aprovacao
from fatorendimentodisciplina f
join data dt on dt.id_data = f.id_data
join curso c on c.id_curso = f.id_curso
group by 1, 2
order by 1, 2""",
        variaveis={"separar_por": ("Separar por", "Turno", "f_seg23")},
        altura=8,
    ),
    dict(
        nome="2.3b Faltas ao longo dos semestres (% das aulas)",
        tipo="line",
        config={"graph.dimensions": ["semestre", "grupo"], "graph.metrics": ["pct_faltas"],
                "graph.y_axis.title_text": "% das aulas previstas", "column_settings": sufixo("pct_faltas")},
        sql="""-- Média de faltas ponderada pelos matriculados, convertida em % das aulas previstas (carga horária ÷ 2).
select dt.anosemestre as semestre,
       case when lower({{separar_por}}) = 'modalidade' then c.modalidadeensino else c.turno end as grupo,
       round(sum(f.mediafaltas * f.qtdmatriculados / (d.cargahoraria / 2.0) * 100) / sum(f.qtdmatriculados), 1)
         as pct_faltas
from fatorendimentodisciplina f
join data dt on dt.id_data = f.id_data
join curso c on c.id_curso = f.id_curso
join disciplina d on d.id_disciplina = f.id_disciplina
group by 1, 2
order by 1, 2""",
        variaveis={"separar_por": ("Separar por", "Turno", "f_seg23")},
        altura=8,
    ),
    dict(
        nome="2.7a Mediana das notas por disciplina e horário",
        tipo="bar",
        config={"graph.dimensions": ["disciplina", "horario"], "graph.metrics": ["mediana_notas"],
                "graph.show_values": True, "graph.y_axis.title_text": "Mediana das notas",
                "series_settings": cores(**{"Seg/Qua – manhã": AZUL, "Ter/Qui – noite": ROXO})},
        sql="""-- Horário traduzido: 2 = segunda, 3 = terça, 4 = quarta, 5 = quinta; M = manhã, N = noite.
select 'Disc. ' || f.id_disciplina as disciplina,
       case t.horario when '24M12' then 'Seg/Qua – manhã' when '35N12' then 'Ter/Qui – noite' else t.horario end
         as horario,
       round(avg(f.medianotas), 2) as mediana_notas
from fatorendimentodisciplina f
join turmadisciplina t on t.id_turmadisciplina = f.id_turmadisciplina
where f.id_disciplina <> 101
group by f.id_disciplina, t.horario
order by f.id_disciplina, t.horario""",
        altura=8,
    ),
    dict(
        nome="2.7b Reprovação por falta por disciplina e horário (%)",
        tipo="bar",
        config={"graph.dimensions": ["disciplina", "horario"], "graph.metrics": ["pct_reprov_falta"],
                "graph.show_values": True, "graph.y_axis.title_text": "% reprovados por falta",
                "column_settings": sufixo("pct_reprov_falta"),
                "series_settings": cores(**{"Seg/Qua – manhã": AZUL, "Ter/Qui – noite": ROXO})},
        sql="""select 'Disc. ' || f.id_disciplina as disciplina,
       case t.horario when '24M12' then 'Seg/Qua – manhã' when '35N12' then 'Ter/Qui – noite' else t.horario end
         as horario,
       round(100.0 * sum(f.qtdreprovacoesfalta) / sum(f.qtdmatriculados), 1) as pct_reprov_falta
from fatorendimentodisciplina f
join turmadisciplina t on t.id_turmadisciplina = f.id_turmadisciplina
where f.id_disciplina <> 101
group by f.id_disciplina, t.horario
order by f.id_disciplina, t.horario""",
        altura=8,
    ),
    dict(
        nome="2.6 Matriculados por semestre e modalidade de ensino",
        tipo="area",
        config={"graph.dimensions": ["semestre", "modalidade"], "graph.metrics": ["matriculados"],
                "stackable.stack_type": "stacked", "graph.show_values": True,
                "series_settings": cores(Presencial=AZUL, EAD=VERDE)},
        sql="""select d.anosemestre as semestre, c.modalidadeensino as modalidade, sum(f.qtdmatriculados) as matriculados
from fatorendimentodisciplina f
join data d on d.id_data = f.id_data
join curso c on c.id_curso = f.id_curso
group by 1, 2
order by 1, 2""",
        altura=8,
    ),
]

AVISO_FALTANTES = (
    "**Consultas que o esquema atual não permite calcular**\n\n"
    "- **1.5.2 Alunos retidos** e **1.7 Situação de integralização**: precisam de `Curso.cargaHorariaTotal`.\n"
    "- **2.5 Co-docência**: `TurmaDisciplina.id_professor2` existe, mas os dados de exemplo ainda não têm "
    "turmas com mais de um professor."
)


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


def variaveis_da_pergunta(pergunta):
    """Monta as template-tags (variáveis {{...}}) da pergunta SQL."""
    tags = {}
    for nome, (rotulo, padrao, _filtro) in pergunta.get("variaveis", {}).items():
        tag = {"id": str(uuid.uuid4()), "name": nome, "display-name": rotulo, "type": "text"}
        if padrao is not None:
            tag.update({"default": padrao, "required": True})
        tags[nome] = tag
    return tags


def layout(perguntas_ids):
    """Duas colunas de 12; cada linha usa a altura do maior cartão do par."""
    cartoes, linha = [], 0
    for i in range(0, len(perguntas_ids), 2):
        par = perguntas_ids[i:i + 2]
        altura = max(p["altura"] for p, _ in par)
        for j, (pergunta, card_id) in enumerate(par):
            cartoes.append({"pergunta": pergunta, "card_id": card_id, "row": linha, "col": j * 12,
                            "size_x": 12 if len(par) == 2 else 24, "size_y": altura})
        linha += altura
    return cartoes, linha


def montar_dashboard(dash, perguntas_ids, sessao):
    cartoes, fim = layout(perguntas_ids)

    def dashcards(com_filtros, com_texto):
        lista = []
        for n, c in enumerate(cartoes, start=1):
            mapeamentos = []
            if com_filtros:
                for nome, (_rotulo, _padrao, filtro) in c["pergunta"].get("variaveis", {}).items():
                    mapeamentos.append({"parameter_id": filtro, "card_id": c["card_id"],
                                        "target": ["variable", ["template-tag", nome]]})
            lista.append({"id": -n, "card_id": c["card_id"], "row": c["row"], "col": c["col"],
                          "size_x": c["size_x"], "size_y": c["size_y"], "visualization_settings": {},
                          "parameter_mappings": mapeamentos})
        if com_texto:
            lista.append({"id": -(len(lista) + 1), "card_id": None, "row": fim, "col": 0, "size_x": 24, "size_y": 3,
                          "parameter_mappings": [],
                          "visualization_settings": {
                              "virtual_card": {"name": None, "display": "text", "visualization_settings": {},
                                               "dataset_query": {}, "archived": False},
                              "text": AVISO_FALTANTES}})
        return lista

    def filtros(com_opcoes):
        lista = []
        for fid, nome, slug, padrao, opcoes in FILTROS:
            f = {"id": fid, "name": nome, "slug": slug, "type": "string/="}
            if padrao is not None:
                f["default"] = [padrao]
            if com_opcoes:
                f.update({"values_source_type": "static-list", "values_source_config": {"values": opcoes}})
            lista.append(f)
        return lista

    # Do mais completo ao mais simples: se uma versão do Metabase recusar algo, o dashboard sai mesmo assim.
    tentativas = [
        ("com filtros, opções e aviso", dashcards(True, True), filtros(True)),
        ("com filtros e opções", dashcards(True, False), filtros(True)),
        ("com filtros", dashcards(True, False), filtros(False)),
        ("sem filtros (use os filtros de cada pergunta)", dashcards(False, False), []),
    ]
    for descricao, cards, params in tentativas:
        try:
            chamar("PUT", f"/api/dashboard/{dash}", {"parameters": params, "dashcards": cards}, sessao)
            print(f"Dashboard montado {descricao}.", flush=True)
            return
        except RuntimeError as erro:
            print(f"Não deu para montar o dashboard {descricao}: {erro}", flush=True)
    sys.exit("Não foi possível montar o dashboard.")


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

    print("Conectando o banco idw...", flush=True)
    banco = chamar("POST", "/api/database", {
        "engine": "postgres", "name": "IDW",
        "details": {"host": "idw-postgres", "port": 5432, "dbname": "idw", "user": "idw",
                    "password": "idw_local", "ssl": False, "tunnel-enabled": False},
        "is_full_sync": True,
    }, sessao)["id"]

    colecao = chamar("POST", "/api/collection", {
        "name": COLECAO, "description": "Consultas do documento (dados sintéticos)"}, sessao)["id"]

    print(f"Criando as {len(PERGUNTAS)} perguntas...", flush=True)
    perguntas_ids = []
    for p in PERGUNTAS:
        carta = chamar("POST", "/api/card", {
            "name": p["nome"], "collection_id": colecao, "display": p["tipo"],
            "dataset_query": {"type": "native", "database": banco,
                              "native": {"query": p["sql"], "template-tags": variaveis_da_pergunta(p)}},
            "visualization_settings": p["config"],
        }, sessao)
        perguntas_ids.append((p, carta["id"]))

    print("Montando o dashboard...", flush=True)
    dash = chamar("POST", "/api/dashboard", {"name": DASHBOARD, "collection_id": colecao}, sessao)["id"]
    montar_dashboard(dash, perguntas_ids, sessao)

    print(f"Pronto! Abra {BASE.replace('metabase', 'localhost')}/dashboard/{dash}", flush=True)


if __name__ == "__main__":
    main()
