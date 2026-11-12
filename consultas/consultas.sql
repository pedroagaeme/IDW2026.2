-- Consultas do documento "Consultas em Linguagem Natural", as mesmas que metabase/configurar.py cria no Metabase.
-- Gerado a partir de metabase/configurar.py: altere lá e copie para cá.
-- Os filtros do dashboard aparecem aqui com o valor padrão; os opcionais ficam comentados.
-- Em PostgreSQL, os nomes sem aspas ficam em minúsculas (ex.: FatoRendimentoAluno -> fatorendimentoaluno).

-- 1.1 Evasão por forma de ingresso e cota (%)  [linhas horizontais (Row)]
-- Só grupos com 10 alunos ou mais: grupos menores dão 0% ou valores extremos por acaso.
select formaingresso || ' / ' || tipocota || ' (n=' || count(*) || ')' as grupo,
       round(100.0 * count(*) filter (where tipoevasao is not null) / count(*), 1) as pct_evasao
from aluno
group by formaingresso, tipocota
having count(*) >= 10
order by pct_evasao desc;

-- 1.2.1 Nota média de alunos de baixa renda com e sem assistência, por curso  [linhas horizontais (Row)]
-- Assistência estudantil só existe na faixa Baixa; a média do curso serve de referência.
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
order by curso, grupo;

-- 1.2.2 Alunos de baixa renda que trancaram, por turno (%)  [barras]
-- Percentual de alunos (não de matrículas) que trancaram ao menos um período.
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
         assistencia;

-- 1.3 Nota × frequência por gênero (um ponto por aluno)  [dispersão]
-- Escolha a disciplina, o semestre e, se quiser, a faixa etária nos filtros do dashboard.
-- O registro do PDF com faixa "20-25" entra em 21-25.
select f.medianota as nota,
       round(100 - 100.0 * f.qtdfaltas / d.cargahoraria, 1) as frequencia,
       a.genero
from fatorendimentoaluno f
join aluno a on a.id_aluno = f.id_aluno
join disciplina d on d.id_disciplina = f.id_disciplina
join data dt on dt.id_data = f.id_data
where not f.periodotrancado
  and f.medianota is not null
  and 'Disc. ' || f.id_disciplina = 'Disc. 105'
  and dt.anosemestre = '2025.2'
  -- filtro opcional: and case when a.faixaetaria = '20-25' then '21-25' else a.faixaetaria end = '<valor>'
;

-- 1.4 Percentual de faltas por bairro (%)  [linhas horizontais (Row)]
-- Faltas ÷ carga horária da disciplina, sem períodos trancados.
-- A barra "MÉDIA GERAL" é a referência: bairros acima dela faltam mais que a média.
with base as (
    select a.bairroresidencia, a.id_aluno, 100.0 * f.qtdfaltas / d.cargahoraria as pct
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
order by pct_faltas desc;

-- 1.5.1 Reprovação por disciplina, por nota e por falta (%)  [barras empilhadas, linha de limite em 15%]
-- Reprovações ÷ matrículas (sem trancados), filtrável por departamento (Y) e semestre.
-- A disciplina 101 (registro de exemplo do PDF) tem 1 matrícula e fica de fora.
select 'Disc. ' || f.id_disciplina as disciplina,
       round(100.0 * count(*) filter (where f.statusaluno = 'Reprovado por Nota') / count(*), 1) as reprov_nota,
       round(100.0 * count(*) filter (where f.statusaluno = 'Reprovado por Falta') / count(*), 1) as reprov_falta
from fatorendimentoaluno f
join curso c on c.id_curso = f.id_curso
join data dt on dt.id_data = f.id_data
where not f.periodotrancado
  and f.id_disciplina <> 101
  -- filtro opcional: and c.departamento = '<valor>'
  -- filtro opcional: and dt.anosemestre = '<valor>'
group by f.id_disciplina
order by count(*) filter (where f.statusaluno like 'Reprovado%') * 1.0 / count(*) desc;

-- 1.6 Evasão por faixa econômica, raça/etnia e deficiência (%)  [linhas horizontais (Row)]
-- Cada característica analisada separadamente; "TAXA GERAL" é a referência.
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
order by ordem, sub, 100.0 * ev / n desc;

-- 2.1 Resultados de cada professor na disciplina (%)  [linhas horizontais (Row) empilhadas em 100%]
-- Escolha a disciplina no filtro do dashboard. "DISCIPLINA TODA" é a referência.
-- Professores ordenados pela taxa de reprovação total.
with base as (
    select p.nome as professor, f.qtdaprovacoesnota as ap, f.qtdreprovacoesnota as rn, f.qtdreprovacoesfalta as rf
    from fatorendimentodisciplina f
    join turmadisciplina t on t.id_turmadisciplina = f.id_turmadisciplina
    join professor p on p.id_professor = t.id_professor1
    where 'Disc. ' || f.id_disciplina = 'Disc. 102'
)
select professor, aprovados, reprovados_nota, reprovados_falta from (
    select professor, sum(ap) as aprovados, sum(rn) as reprovados_nota, sum(rf) as reprovados_falta, 1 as ordem
    from base group by professor
    union all
    select 'DISCIPLINA TODA', sum(ap), sum(rn), sum(rf), 0 from base
) t
order by ordem, (reprovados_nota + reprovados_falta) * 1.0
                / nullif(aprovados + reprovados_nota + reprovados_falta, 0) desc;

-- 2.2 Distribuição das notas por departamento (%)  [linhas horizontais (Row) empilhadas em 100%]
-- Em 100% dá para comparar departamentos de tamanhos diferentes.
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
         / nullif(sum(f.qtdnotas0_2_9 + f.qtdnotas3_6_9 + f.qtdnotas7_7_9 + f.qtdnotas8_8_9 + f.qtdnotas9_10), 0) desc;

-- 2.4 Disciplinas obrigatórias mais críticas por centro (% de notas de 0 a 2,9)  [linhas horizontais (Row)]
-- As 10 combinações centro × disciplina obrigatória com maior parcela de notas críticas.
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
limit 10;

-- 2.3a Aprovação por nota ao longo dos semestres (%)  [linhas]
-- Aprovados por nota ÷ matriculados. Use o filtro "Separar por" (Turno ou Modalidade).
select dt.anosemestre as semestre,
       case when lower('Turno') = 'modalidade' then c.modalidadeensino else c.turno end as grupo,
       round(100.0 * sum(f.qtdaprovacoesnota) / sum(f.qtdmatriculados), 1) as pct_aprovacao
from fatorendimentodisciplina f
join data dt on dt.id_data = f.id_data
join curso c on c.id_curso = f.id_curso
group by 1, 2
order by 1, 2;

-- 2.3b Faltas ao longo dos semestres (% da carga horária)  [linhas]
-- Média de faltas ponderada pelos matriculados, convertida em % da carga horária da disciplina.
select dt.anosemestre as semestre,
       case when lower('Turno') = 'modalidade' then c.modalidadeensino else c.turno end as grupo,
       round(sum(f.mediafaltas * f.qtdmatriculados / d.cargahoraria * 100) / sum(f.qtdmatriculados), 1)
         as pct_faltas
from fatorendimentodisciplina f
join data dt on dt.id_data = f.id_data
join curso c on c.id_curso = f.id_curso
join disciplina d on d.id_disciplina = f.id_disciplina
group by 1, 2
order by 1, 2;

-- 2.7a Mediana das notas por disciplina e horário  [barras]
-- Horário traduzido: 2 = segunda, 3 = terça, 4 = quarta, 5 = quinta; M = manhã, N = noite.
select 'Disc. ' || f.id_disciplina as disciplina,
       case t.horario when '24M12' then 'Seg/Qua – manhã' when '35N12' then 'Ter/Qui – noite' else t.horario end
         as horario,
       round(avg(f.medianotas), 2) as mediana_notas
from fatorendimentodisciplina f
join turmadisciplina t on t.id_turmadisciplina = f.id_turmadisciplina
where f.id_disciplina <> 101
group by f.id_disciplina, t.horario
order by f.id_disciplina, t.horario;

-- 2.7b Reprovação por falta por disciplina e horário (%)  [barras]
select 'Disc. ' || f.id_disciplina as disciplina,
       case t.horario when '24M12' then 'Seg/Qua – manhã' when '35N12' then 'Ter/Qui – noite' else t.horario end
         as horario,
       round(100.0 * sum(f.qtdreprovacoesfalta) / sum(f.qtdmatriculados), 1) as pct_reprov_falta
from fatorendimentodisciplina f
join turmadisciplina t on t.id_turmadisciplina = f.id_turmadisciplina
where f.id_disciplina <> 101
group by f.id_disciplina, t.horario
order by f.id_disciplina, t.horario;

-- 2.5 Co-docência: aprovação e amplitude das notas por nº de professores  [combinado: barras + linha]
-- Taxa de aprovação por nota (barras) e amplitude média das notas, maior − menor (linha, eixo direito),
-- por número de professores da turma.
with turmas as (
    select f.*, 1 + (t.id_professor2 is not null)::int + (t.id_professor3 is not null)::int as n_prof
    from fatorendimentodisciplina f
    join turmadisciplina t on t.id_turmadisciplina = f.id_turmadisciplina
    where f.id_disciplina <> 101
)
select case n_prof when 1 then 'Docente único' else n_prof || ' professores' end
         || ' (' || count(distinct id_turmadisciplina) || ' turmas)' as grupo,
       round(100.0 * sum(qtdaprovacoesnota) / sum(qtdmatriculados), 1) as pct_aprovacao,
       round(avg(maiornota - menornota), 2) as amplitude_media
from turmas
group by n_prof
order by n_prof;

-- 2.6 Matriculados por semestre e modalidade de ensino  [área empilhadas]
select d.anosemestre as semestre, c.modalidadeensino as modalidade, sum(f.qtdmatriculados) as matriculados
from fatorendimentodisciplina f
join data d on d.id_data = f.id_data
join curso c on c.id_curso = f.id_curso
group by 1, 2
order by 1, 2;
