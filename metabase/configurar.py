"""Configura o Metabase local automaticamente (roda uma vez, no serviço metabase-setup do docker-compose).

1. espera o Metabase subir;
2. cria o admin de demonstração (somente se o Metabase ainda não foi configurado);
3. conecta o banco `idw` do PostgreSQL;
4. cria a coleção, as 10 perguntas SQL e o dashboard.

Se a coleção já existir, nada é recriado. Usa apenas a biblioteca padrão do Python.
"""
import json
import os
import sys
import time
import urllib.error
import urllib.request

BASE = os.environ.get("MB_URL", "http://metabase:3000")
ADMIN_EMAIL = os.environ.get("MB_ADMIN_EMAIL", "admin@example.com")
ADMIN_SENHA = os.environ.get("MB_ADMIN_SENHA", "Idw@Demo2026")  # senha de demonstração (dados fictícios)
COLECAO = "IDW – Rendimento Acadêmico"
DASHBOARD = "IDW – Rendimento Acadêmico (dados sintéticos)"

# (nome, tipo de gráfico, configurações do gráfico, SQL)
PERGUNTAS = [
    (
        "1.1 Taxa de evasão por forma de ingresso e cota (%)", "bar",
        {"graph.dimensions": ["forma_cota"], "graph.metrics": ["pct_evasao"]},
        """select formaingresso || ' / ' || tipocota as forma_cota,
       round(100.0 * count(*) filter (where tipoevasao is not null) / count(*), 1) as pct_evasao
from aluno group by 1 having count(*) >= 3 order by 2 desc""",
    ),
    (
        "1.2 Média de notas por faixa econômica e assistência estudantil", "bar",
        {"graph.dimensions": ["faixaeconomica", "assistencia"], "graph.metrics": ["media_nota"]},
        """select a.faixaeconomica,
       case when a.assistenciaestudantil then 'Com assistência' else 'Sem assistência' end as assistencia,
       round(avg(f.medianota), 2) as media_nota
from fatorendimentoaluno f join aluno a on a.id_aluno = f.id_aluno
where f.medianota is not null group by 1, 2 order by 1, 2""",
    ),
    (
        "1.3 Taxa de trancamento de alunos de baixa renda por turno (%)", "bar",
        {"graph.dimensions": ["turno", "assistencia"], "graph.metrics": ["pct_trancamento"]},
        """select c.turno,
       case when a.assistenciaestudantil then 'Com assistência' else 'Sem assistência' end as assistencia,
       round(100.0 * avg(case when f.periodotrancado then 1 else 0 end), 1) as pct_trancamento
from fatorendimentoaluno f join aluno a on a.id_aluno = f.id_aluno join curso c on c.id_curso = f.id_curso
where a.faixaeconomica = 'Baixa' group by 1, 2 order by 1, 2""",
    ),
    (
        "1.4 Bairros com maior média de faltas (top 10)", "bar",
        {"graph.dimensions": ["bairro"], "graph.metrics": ["media_faltas"]},
        """select a.bairroresidencia as bairro, round(avg(f.qtdfaltas), 2) as media_faltas
from fatorendimentoaluno f join aluno a on a.id_aluno = f.id_aluno
where not f.periodotrancado group by 1 order by 2 desc limit 10""",
    ),
    (
        "1.5 Taxa de reprovação por disciplina (%)", "bar",
        {"graph.dimensions": ["disciplina"], "graph.metrics": ["reprov_nota", "reprov_falta"],
         "stackable.stack_type": "stacked"},
        """select 'Disc. ' || id_disciplina as disciplina,
       round(100.0 * count(*) filter (where statusaluno = 'Reprovado por Nota') / count(*), 1) as reprov_nota,
       round(100.0 * count(*) filter (where statusaluno = 'Reprovado por Falta') / count(*), 1) as reprov_falta
from fatorendimentoaluno where not periodotrancado group by id_disciplina order by id_disciplina""",
    ),
    (
        "1.6 Evasão por faixa econômica, raça/etnia e deficiência (%)", "bar",
        {"graph.dimensions": ["grupo"], "graph.metrics": ["pct_evasao"]},
        """select * from (
  select 'Faixa econômica' as caracteristica, faixaeconomica as grupo,
         round(100.0 * count(*) filter (where tipoevasao is not null) / count(*), 1) as pct_evasao from aluno group by 2
  union all
  select 'Raça/etnia', raca_etnia,
         round(100.0 * count(*) filter (where tipoevasao is not null) / count(*), 1) from aluno group by 2
  union all
  select 'Deficiência', case when deficiencia = 'Nenhuma' then 'Nenhuma' else 'Com deficiência' end,
         round(100.0 * count(*) filter (where tipoevasao is not null) / count(*), 1) from aluno group by 2
) t order by 1, 2""",
    ),
    (
        "2.1 Distribuição de notas por departamento", "bar",
        {"graph.dimensions": ["departamento"],
         "graph.metrics": ["0 a 2,9", "3 a 6,9", "7 a 7,9", "8 a 8,9", "9 a 10"],
         "stackable.stack_type": "stacked"},
        """select c.departamento, sum(f.qtdnotas0_2_9) as "0 a 2,9", sum(f.qtdnotas3_6_9) as "3 a 6,9",
       sum(f.qtdnotas7_7_9) as "7 a 7,9", sum(f.qtdnotas8_8_9) as "8 a 8,9", sum(f.qtdnotas9_10) as "9 a 10"
from fatorendimentodisciplina f join curso c on c.id_curso = f.id_curso group by 1 order by 1""",
    ),
    (
        "2.2 Aprovação por nota (%) e média de faltas por semestre", "line",
        {"graph.dimensions": ["semestre"], "graph.metrics": ["pct_aprovacao", "media_faltas"]},
        """select d.anosemestre as semestre,
       round(100.0 * sum(f.qtdaprovacoesnota) / sum(f.qtdmatriculados), 1) as pct_aprovacao,
       round(avg(f.mediafaltas), 2) as media_faltas
from fatorendimentodisciplina f join data d on d.id_data = f.id_data group by 1 order by 1""",
    ),
    (
        "2.3 Matriculados por semestre e modalidade de ensino", "area",
        {"graph.dimensions": ["semestre", "modalidade"], "graph.metrics": ["matriculados"],
         "stackable.stack_type": "stacked"},
        """select d.anosemestre as semestre, c.modalidadeensino as modalidade, sum(f.qtdmatriculados) as matriculados
from fatorendimentodisciplina f join data d on d.id_data = f.id_data join curso c on c.id_curso = f.id_curso
group by 1, 2 order by 1, 2""",
    ),
    (
        "2.4 Mediana de notas e reprovações por falta por horário", "bar",
        {"graph.dimensions": ["horario"], "graph.metrics": ["mediana_notas", "pct_reprov_falta"]},
        """select t.horario, round(avg(f.medianotas), 2) as mediana_notas,
       round(100.0 * sum(f.qtdreprovacoesfalta) / sum(f.qtdmatriculados), 1) as pct_reprov_falta
from fatorendimentodisciplina f join turmadisciplina t on t.id_turmadisciplina = f.id_turmadisciplina
group by 1 order by 1""",
    ),
]


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
        print("Coleção já existe; nada a fazer.")
        return

    print("Conectando o banco idw...", flush=True)
    banco = chamar("POST", "/api/database", {
        "engine": "postgres", "name": "IDW",
        "details": {"host": "idw-postgres", "port": 5432, "dbname": "idw", "user": "idw",
                    "password": "idw_local", "ssl": False, "tunnel-enabled": False},
        "is_full_sync": True,
    }, sessao)["id"]

    colecao = chamar("POST", "/api/collection", {
        "name": COLECAO, "description": "Consultas do PDF (dados sintéticos)"}, sessao)["id"]

    print("Criando as perguntas...", flush=True)
    ids = []
    for nome, tipo, config, sql in PERGUNTAS:
        carta = chamar("POST", "/api/card", {
            "name": nome, "collection_id": colecao, "display": tipo,
            "dataset_query": {"type": "native", "database": banco, "native": {"query": sql}},
            "visualization_settings": config,
        }, sessao)
        ids.append(carta["id"])

    print("Montando o dashboard...", flush=True)
    dash = chamar("POST", "/api/dashboard", {"name": DASHBOARD, "collection_id": colecao}, sessao)["id"]
    chamar("PUT", f"/api/dashboard/{dash}", {"dashcards": [
        {"id": -(i + 1), "card_id": cid, "row": (i // 2) * 8, "col": (i % 2) * 12,
         "size_x": 12, "size_y": 8, "visualization_settings": {}, "parameter_mappings": []}
        for i, cid in enumerate(ids)
    ]}, sessao)

    print(f"Pronto! Abra {BASE.replace('metabase', 'localhost')}/dashboard/{dash}", flush=True)


if __name__ == "__main__":
    main()
