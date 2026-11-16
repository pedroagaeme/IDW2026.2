-- Consultas do documento "Consultas em Linguagem Natural", as mesmas que metabase/configurar.py cria no Metabase.
-- Gerado por: python metabase/configurar.py --sql > consultas/consultas.sql (não edite à mão).
-- Sem os filtros do dashboard; variáveis obrigatórias no valor padrão.
-- Em PostgreSQL, os nomes sem aspas ficam em minúsculas (ex.: FatoRendimentoAluno -> fatorendimentoaluno).

-- E1 Alunos ativos  [número]
-- Alunos com vínculo ativo (sem registro de evasão).
select count(*) as ativos
from aluno a
    join curso c on c.id_curso = a.id_curso
where a.tipoevasao is null;

-- E2 Taxa de evasão no último semestre (TEA)  [número com tendência]
-- Evadidos ÷ matrículas do semestre (método da proposta, eq. 4.10), comparado ao semestre anterior.
with base as (
    select distinct a.id_aluno, c.departamento as curso, dt.ano * 2 + dt.semestre as k,
           a.anoevasao * 2 + a.semestreevasao as k_ev
    from fatorendimentoaluno f
    join aluno a on a.id_aluno = f.id_aluno
    join curso c on c.id_curso = f.id_curso
    join data dt on dt.id_data = f.id_data
    join disciplina d on d.id_disciplina = f.id_disciplina
    join turmaaluno ta on ta.id_turmaaluno = f.id_turmaaluno
    where true
),
mat as (select curso, k, count(distinct id_aluno) as m from base group by 1, 2),
ev as (select curso, k_ev as k, count(distinct id_aluno) as e from base where k_ev is not null group by 1, 2),
tea as (
    select mat.curso, mat.k, (mat.k - 1) / 2 as ano, (mat.k - 1) % 2 + 1 as semestre,
           coalesce(ev.e, 0) as evadidos, mat.m + coalesce(ev.e, 0) as matriculas
    from mat left join ev on ev.curso = mat.curso and ev.k = mat.k
)
select make_date(ano, semestre * 6 - 5, 1) as semestre, round(100.0 * sum(evadidos) / sum(matriculas), 1) as tea
from tea
where k > (select min(k) from tea)  -- o 1º semestre da fato ainda não tem evasão registrada
group by 1
order by 1;

-- E3 Aprovação no último semestre  [número com tendência]
-- Matrículas aprovadas ÷ matrículas (sem trancados), comparado ao semestre anterior.
select make_date(dt.ano, dt.semestre * 6 - 5, 1) as semestre,
       round(100.0 * count(*) filter (where f.statusaluno = 'Aprovado') / count(*), 1) as aprovacao
from fatorendimentoaluno f
    join aluno a on a.id_aluno = f.id_aluno
    join curso c on c.id_curso = f.id_curso
    join data dt on dt.id_data = f.id_data
    join disciplina d on d.id_disciplina = f.id_disciplina
    join turmaaluno ta on ta.id_turmaaluno = f.id_turmaaluno
where not f.periodotrancado
group by 1
order by 1;

-- E4 Alunos ativos retidos  [número]
-- Atrasados + em risco + acima do tempo máximo ÷ alunos ativos (mesma regra das consultas 1.5.2 e 1.7).
with ref as (select ano, semestre from data order by ano desc, semestre desc limit 1),
alunos as (
    select c.departamento as curso, ta.anosemestreingresso as coorte, a.tipoevasao is not null as evadiu,
           a.cargahorariaintegralizadaatual as ch, c.cargahorariatotal as total,
           c.tempominimoconcluir as tmin, c.tempomaximoconcluir as tmax,
           (r.ano - ta.anoingresso) * 2 + (r.semestre - ta.semestreingresso) + 1 as n
    from aluno a
    join curso c on c.id_curso = a.id_curso
    join (select distinct id_aluno, id_turmaaluno from fatorendimentoaluno) fa on fa.id_aluno = a.id_aluno
    join turmaaluno ta on ta.id_turmaaluno = fa.id_turmaaluno
    cross join ref r
    where c.cargahorariatotal is not null
),
situacao as (
    select curso, coorte, case
        when evadiu then 'Evadido'
        when n > tmax then 'Acima do tempo máximo'
        when (total - ch) / (total * 1.0 / tmin) > tmax - n then 'Em risco de ultrapassar o tempo máximo'
        when ch < total * least(n, tmin) * 1.0 / tmin then 'Atrasado'
        else 'Dentro do fluxo' end as situacao
    from alunos
)
select round(100.0 * count(*) filter (where situacao not in ('Dentro do fluxo', 'Evadido'))
             / nullif(count(*) filter (where situacao <> 'Evadido'), 0), 1) as retidos
from situacao;

-- E5 Evolução da taxa de evasão (TEA) por semestre  [barras + linha]
-- Série histórica da TEA (proposta, eq. 4.10): queda indica efeito das ações de permanência.
-- Linha = taxa; barras = número de evadidos. Recorte por curso, centro ou perfil nos filtros.
with base as (
    select distinct a.id_aluno, c.departamento as curso, dt.ano * 2 + dt.semestre as k,
           a.anoevasao * 2 + a.semestreevasao as k_ev
    from fatorendimentoaluno f
    join aluno a on a.id_aluno = f.id_aluno
    join curso c on c.id_curso = f.id_curso
    join data dt on dt.id_data = f.id_data
    join disciplina d on d.id_disciplina = f.id_disciplina
    join turmaaluno ta on ta.id_turmaaluno = f.id_turmaaluno
    where true
),
mat as (select curso, k, count(distinct id_aluno) as m from base group by 1, 2),
ev as (select curso, k_ev as k, count(distinct id_aluno) as e from base where k_ev is not null group by 1, 2),
tea as (
    select mat.curso, mat.k, (mat.k - 1) / 2 as ano, (mat.k - 1) % 2 + 1 as semestre,
           coalesce(ev.e, 0) as evadidos, mat.m + coalesce(ev.e, 0) as matriculas
    from mat left join ev on ev.curso = mat.curso and ev.k = mat.k
)
select ano || '.' || semestre as semestre, sum(evadidos) as evadidos,
       round(100.0 * sum(evadidos) / sum(matriculas), 1) as tea
from tea
where k > (select min(k) from tea)
group by k, ano, semestre
order by k;

-- E6 Mapa de calor da evasão por curso e semestre (%)  [tabela]
-- TEA de cada curso em cada semestre; quanto mais vermelho, maior a evasão. "Período" = todos os semestres.
with base as (
    select distinct a.id_aluno, c.departamento as curso, dt.ano * 2 + dt.semestre as k,
           a.anoevasao * 2 + a.semestreevasao as k_ev
    from fatorendimentoaluno f
    join aluno a on a.id_aluno = f.id_aluno
    join curso c on c.id_curso = f.id_curso
    join data dt on dt.id_data = f.id_data
    join disciplina d on d.id_disciplina = f.id_disciplina
    join turmaaluno ta on ta.id_turmaaluno = f.id_turmaaluno
    where true
),
mat as (select curso, k, count(distinct id_aluno) as m from base group by 1, 2),
ev as (select curso, k_ev as k, count(distinct id_aluno) as e from base where k_ev is not null group by 1, 2),
tea as (
    select mat.curso, mat.k, (mat.k - 1) / 2 as ano, (mat.k - 1) % 2 + 1 as semestre,
           coalesce(ev.e, 0) as evadidos, mat.m + coalesce(ev.e, 0) as matriculas
    from mat left join ev on ev.curso = mat.curso and ev.k = mat.k
)
select curso,
       round(100.0 * sum(evadidos) filter (where k = 4048) / nullif(sum(matriculas) filter (where k = 4048), 0), 1) as "2023.2",
       round(100.0 * sum(evadidos) filter (where k = 4049) / nullif(sum(matriculas) filter (where k = 4049), 0), 1) as "2024.1",
       round(100.0 * sum(evadidos) filter (where k = 4050) / nullif(sum(matriculas) filter (where k = 4050), 0), 1) as "2024.2",
       round(100.0 * sum(evadidos) filter (where k = 4051) / nullif(sum(matriculas) filter (where k = 4051), 0), 1) as "2025.1",
       round(100.0 * sum(evadidos) filter (where k = 4052) / nullif(sum(matriculas) filter (where k = 4052), 0), 1) as "2025.2",
       round(100.0 * sum(evadidos) / sum(matriculas), 1) as "Período"
from tea
group by curso
order by "Período" desc;

-- E7 Situação de cada coorte de ingresso (%)  [barras]
-- Onde está hoje cada turma de ingresso: no fluxo, retida (atrasada, em risco, acima do tempo máximo) ou evadida.
-- Análise por coorte, o "grupo 2" de métodos da proposta.
with ref as (select ano, semestre from data order by ano desc, semestre desc limit 1),
alunos as (
    select c.departamento as curso, ta.anosemestreingresso as coorte, a.tipoevasao is not null as evadiu,
           a.cargahorariaintegralizadaatual as ch, c.cargahorariatotal as total,
           c.tempominimoconcluir as tmin, c.tempomaximoconcluir as tmax,
           (r.ano - ta.anoingresso) * 2 + (r.semestre - ta.semestreingresso) + 1 as n
    from aluno a
    join curso c on c.id_curso = a.id_curso
    join (select distinct id_aluno, id_turmaaluno from fatorendimentoaluno) fa on fa.id_aluno = a.id_aluno
    join turmaaluno ta on ta.id_turmaaluno = fa.id_turmaaluno
    cross join ref r
    where c.cargahorariatotal is not null
),
situacao as (
    select curso, coorte, case
        when evadiu then 'Evadido'
        when n > tmax then 'Acima do tempo máximo'
        when (total - ch) / (total * 1.0 / tmin) > tmax - n then 'Em risco de ultrapassar o tempo máximo'
        when ch < total * least(n, tmin) * 1.0 / tmin then 'Atrasado'
        else 'Dentro do fluxo' end as situacao
    from alunos
)
select coorte,
       round(100.0 * count(*) filter (where situacao = 'Dentro do fluxo') / count(*), 1) as dentro,
       round(100.0 * count(*) filter (where situacao = 'Atrasado') / count(*), 1) as atrasado,
       round(100.0 * count(*) filter (where situacao = 'Em risco de ultrapassar o tempo máximo') / count(*), 1) as em_risco,
       round(100.0 * count(*) filter (where situacao = 'Acima do tempo máximo') / count(*), 1) as acima,
       round(100.0 * count(*) filter (where situacao = 'Evadido') / count(*), 1) as evadido
from situacao
group by coorte
order by coorte;

-- E8 Em que semestre do curso os alunos evadem  [barras]
-- "Período letivo da evasão" (Tabela 6 da proposta), por tipo de saída.
-- Só coortes acompanhadas desde o ingresso (2023.1 em diante): as anteriores não têm os primeiros semestres nos dados.
select (a.anoevasao - ta.anoingresso) * 2 + (a.semestreevasao - ta.semestreingresso) + 1 as semestre_do_curso,
       a.tipoevasao as tipo,
       count(*) as evadidos
from aluno a
    join curso c on c.id_curso = a.id_curso
    join (select distinct id_aluno, id_turmaaluno from fatorendimentoaluno) fa on fa.id_aluno = a.id_aluno
    join turmaaluno ta on ta.id_turmaaluno = fa.id_turmaaluno
where a.tipoevasao is not null
  and ta.anoingresso >= 2023
group by 1, 2
order by 1, 2;

-- E9 Evasão conforme a taxa de reprovação do aluno (%)  [barras]
-- Rendimento como sinal de alerta: quanto mais reprovações, maior a evasão? (reprovações desde 2023.1)
-- Taxa de reprovação do aluno (reprovações ÷ disciplinas cursadas, sem trancados): usar a contagem bruta
-- favoreceria quem evadiu cedo, que cursou menos disciplinas e teve menos chance de reprovar.
with por_aluno as (
    select a.id_aluno, a.tipoevasao is not null as evadiu,
           100.0 * count(*) filter (where f.statusaluno like 'Reprovado%') / count(*) as pct_rep
    from fatorendimentoaluno f
    join aluno a on a.id_aluno = f.id_aluno
    join curso c on c.id_curso = f.id_curso
    join data dt on dt.id_data = f.id_data
    join disciplina d on d.id_disciplina = f.id_disciplina
    join turmaaluno ta on ta.id_turmaaluno = f.id_turmaaluno
    where not f.periodotrancado
    group by 1, 2
),
faixas as (
    select evadiu, pct_rep,
           case when pct_rep = 0 then 'Nenhuma' when pct_rep <= 20 then 'Até 20%'
                when pct_rep <= 40 then '20% a 40%' else 'Acima de 40%' end as faixa
    from por_aluno
)
select faixa || ' (n=' || count(*) || ')' as reprovacoes,
       round(100.0 * count(*) filter (where evadiu) / count(*), 1) as pct_evasao
from faixas
group by faixa
order by min(pct_rep);

-- E10 Evasão por naturalidade (%)  [barras horizontais]
-- A proposta usa a naturalidade no lugar do endereço atual (que muda e pode ser uma república).
-- "TAXA GERAL" é a referência.
with base as (
    select a.naturalidade, a.tipoevasao is not null as evadiu
    from aluno a
    join curso c on c.id_curso = a.id_curso
    where true
)
select nome || ' (n=' || n || ')' as grupo, pct_evasao from (
    select 0 as ordem, 'TAXA GERAL' as nome, count(*) as n,
           round(100.0 * count(*) filter (where evadiu) / count(*), 1) as pct_evasao
    from base
    union all
    select 1, naturalidade, count(*), round(100.0 * count(*) filter (where evadiu) / count(*), 1)
    from base group by naturalidade
) t
order by ordem, pct_evasao desc;

-- E11 Alunos ativos com sinais de risco de evasão  [tabela]
-- Lista para a coordenação agir: alunos ativos que trancaram o último semestre, tiveram nota média
-- abaixo de 5 ou mais de 25% de faltas nele, ou acumulam 4 ou mais reprovações. Os 300 mais críticos.
with ref as (select id_data from data order by ano desc, semestre desc limit 1),
ult as (
    select f.id_aluno, avg(f.medianota) as nota, avg(100.0 * f.qtdfaltas / d.cargahoraria) as faltas
    from fatorendimentoaluno f
    join disciplina d on d.id_disciplina = f.id_disciplina
    join ref on ref.id_data = f.id_data
    where not f.periodotrancado
    group by 1
),
rep as (
    select id_aluno, count(*) filter (where statusaluno like 'Reprovado%') as reprovacoes
    from fatorendimentoaluno group by 1
)
select a.nome as "Aluno", a.numeromatricula as "Matrícula", c.departamento as "Curso",
       ta.anosemestreingresso as "Coorte",
       round(100.0 * a.cargahorariaintegralizadaatual / c.cargahorariatotal) as "% integralizado",
       round(u.nota, 1) as "Nota média no último semestre",
       round(u.faltas, 1) as "% de faltas no último semestre",
       coalesce(rep.reprovacoes, 0) as "Reprovações",
       concat_ws(', ', case when u.id_aluno is null then 'trancou o último semestre' end,
                       case when u.nota < 5 then 'nota baixa' end,
                       case when u.faltas > 25 then 'muitas faltas' end,
                       case when coalesce(rep.reprovacoes, 0) >= 4 then 'muitas reprovações' end) as "Sinais"
from aluno a
    join curso c on c.id_curso = a.id_curso
    join (select distinct id_aluno, id_turmaaluno from fatorendimentoaluno) fa on fa.id_aluno = a.id_aluno
    join turmaaluno ta on ta.id_turmaaluno = fa.id_turmaaluno
left join ult u on u.id_aluno = a.id_aluno
left join rep on rep.id_aluno = a.id_aluno
where a.tipoevasao is null
  and (u.id_aluno is null or u.nota < 5 or u.faltas > 25 or coalesce(rep.reprovacoes, 0) >= 4)
order by u.nota nulls first, rep.reprovacoes desc
limit 300;

-- 1.1 Evasão por forma de ingresso e cota (%)  [barras horizontais]
-- Só grupos com 10 alunos ou mais: grupos menores dão 0% ou valores extremos por acaso.
select a.formaingresso || ' / ' || a.tipocota || ' (n=' || count(*) || ')' as grupo,
       round(100.0 * count(*) filter (where a.tipoevasao is not null) / count(*), 1) as pct_evasao
from aluno a
    join curso c on c.id_curso = a.id_curso
where true
group by a.formaingresso, a.tipocota
having count(*) >= 10
order by pct_evasao desc;

-- 1.2.1 Nota média de alunos de baixa renda com e sem assistência, por curso  [barras horizontais]
-- Assistência estudantil só existe na faixa Baixa; a média do curso serve de referência.
with base as (
    select c.departamento as curso, a.faixaeconomica, a.assistenciaestudantil, f.medianota
    from fatorendimentoaluno f
    join aluno a on a.id_aluno = f.id_aluno
    join curso c on c.id_curso = f.id_curso
    join data dt on dt.id_data = f.id_data
    join disciplina d on d.id_disciplina = f.id_disciplina
    join turmaaluno ta on ta.id_turmaaluno = f.id_turmaaluno
    where f.medianota is not null
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
with por_aluno as (
    select c.turno, a.assistenciaestudantil, a.id_aluno, bool_or(f.periodotrancado) as trancou
    from fatorendimentoaluno f
    join aluno a on a.id_aluno = f.id_aluno
    join curso c on c.id_curso = f.id_curso
    join data dt on dt.id_data = f.id_data
    join disciplina d on d.id_disciplina = f.id_disciplina
    join turmaaluno ta on ta.id_turmaaluno = f.id_turmaaluno
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

-- 1.3 Nota × frequência por gênero na disciplina em foco  [dispersão]
-- Um ponto por matrícula na "Disciplina em foco"; recorte por Faixa etária, Semestre etc. nos filtros.
-- Acima de 1.500 matrículas, mostra uma amostra fixa de 1.500 (pontos demais viram uma mancha).
select f.medianota as nota,
       round(100 - 100.0 * f.qtdfaltas / d.cargahoraria, 1) as frequencia,
       a.genero
from fatorendimentoaluno f
    join aluno a on a.id_aluno = f.id_aluno
    join curso c on c.id_curso = f.id_curso
    join data dt on dt.id_data = f.id_data
    join disciplina d on d.id_disciplina = f.id_disciplina
    join turmaaluno ta on ta.id_turmaaluno = f.id_turmaaluno
where not f.periodotrancado
  and f.medianota is not null
  and 'Disc. ' || f.id_disciplina = 'Disc. 105'
order by md5(f.id_fatoaluno::text)
limit 1500;

-- 1.4 Percentual de faltas por bairro (%)  [barras horizontais]
-- Faltas ÷ carga horária da disciplina, sem períodos trancados.
-- A barra "MÉDIA GERAL" é a referência: bairros acima dela faltam mais que a média.
with base as (
    select a.bairroresidencia, a.id_aluno, 100.0 * f.qtdfaltas / d.cargahoraria as pct
    from fatorendimentoaluno f
    join aluno a on a.id_aluno = f.id_aluno
    join curso c on c.id_curso = f.id_curso
    join data dt on dt.id_data = f.id_data
    join disciplina d on d.id_disciplina = f.id_disciplina
    join turmaaluno ta on ta.id_turmaaluno = f.id_turmaaluno
    where not f.periodotrancado
)
select bairro, pct_faltas from (
    select bairroresidencia || ' (n=' || count(distinct id_aluno) || ')' as bairro, round(avg(pct), 1) as pct_faltas
    from base group by bairroresidencia
    union all
    select 'MÉDIA GERAL', round(avg(pct), 1) from base
) t
order by pct_faltas desc;

-- 1.5.1 Reprovação por disciplina, por nota e por falta (%)  [barras]
-- Reprovações ÷ matrículas (sem trancados). Use os filtros Curso / departamento (o Y da pergunta) e Semestre.
-- A disciplina 101 (registro de exemplo do PDF) tem 1 matrícula e fica de fora.
select 'Disc. ' || f.id_disciplina as disciplina,
       round(100.0 * count(*) filter (where f.statusaluno = 'Reprovado por Nota') / count(*), 1) as reprov_nota,
       round(100.0 * count(*) filter (where f.statusaluno = 'Reprovado por Falta') / count(*), 1) as reprov_falta
from fatorendimentoaluno f
    join aluno a on a.id_aluno = f.id_aluno
    join curso c on c.id_curso = f.id_curso
    join data dt on dt.id_data = f.id_data
    join disciplina d on d.id_disciplina = f.id_disciplina
    join turmaaluno ta on ta.id_turmaaluno = f.id_turmaaluno
where not f.periodotrancado
  and f.id_disciplina <> 101
group by f.id_disciplina
order by count(*) filter (where f.statusaluno like 'Reprovado%') * 1.0 / count(*) desc;

-- 1.5.2 Alunos ativos retidos por curso (%)  [barras horizontais]
-- Alunos ativos no último semestre. Acima do tempo máximo: semestres decorridos > tempoMaximoConcluir.
-- Em risco: no ritmo regular (cargaHorariaTotal ÷ tempoMinimoConcluir por semestre), o que falta não cabe até o tempo máximo.
-- Atrasado: carga integralizada abaixo da esperada para os semestres decorridos. Dentro do fluxo: os demais.
-- Retido = Atrasado + Em risco + Acima do tempo máximo; cursos ordenados pelo total retido.
with ref as (select ano, semestre from data order by ano desc, semestre desc limit 1),
alunos as (
    select c.departamento as curso, ta.anosemestreingresso as coorte, a.tipoevasao is not null as evadiu,
           a.cargahorariaintegralizadaatual as ch, c.cargahorariatotal as total,
           c.tempominimoconcluir as tmin, c.tempomaximoconcluir as tmax,
           (r.ano - ta.anoingresso) * 2 + (r.semestre - ta.semestreingresso) + 1 as n
    from aluno a
    join curso c on c.id_curso = a.id_curso
    join (select distinct id_aluno, id_turmaaluno from fatorendimentoaluno) fa on fa.id_aluno = a.id_aluno
    join turmaaluno ta on ta.id_turmaaluno = fa.id_turmaaluno
    cross join ref r
    where c.cargahorariatotal is not null
),
situacao as (
    select curso, coorte, case
        when evadiu then 'Evadido'
        when n > tmax then 'Acima do tempo máximo'
        when (total - ch) / (total * 1.0 / tmin) > tmax - n then 'Em risco de ultrapassar o tempo máximo'
        when ch < total * least(n, tmin) * 1.0 / tmin then 'Atrasado'
        else 'Dentro do fluxo' end as situacao
    from alunos
)
select curso || ' (n=' || count(*) || ')' as curso,
       round(100.0 * count(*) filter (where situacao = 'Atrasado') / count(*), 1) as atrasado,
       round(100.0 * count(*) filter (where situacao = 'Em risco de ultrapassar o tempo máximo') / count(*), 1) as em_risco,
       round(100.0 * count(*) filter (where situacao = 'Acima do tempo máximo') / count(*), 1) as acima
from situacao
where situacao <> 'Evadido'
group by curso
order by count(*) filter (where situacao <> 'Dentro do fluxo') * 1.0 / count(*) desc;

-- 1.6a Evasão por faixa econômica, raça/etnia e deficiência (%)  [barras horizontais]
-- Cada característica analisada separadamente; "TAXA GERAL" é a referência.
-- Barras em vez de Sankey: comparar a taxa de cada grupo com a geral fica mais direto. Notas e faltas: gráfico 1.6b.
with base as (
    select a.tipoevasao is not null as evadiu, a.faixaeconomica, a.raca_etnia, a.deficiencia
    from aluno a
    join curso c on c.id_curso = a.id_curso
    where true
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

-- 1.6b Nota e faltas até o semestre anterior à evasão: evadidos × demais  [barras + linha]
-- Segunda parte da consulta 1.6: a fato não tem o semestre da saída, então o histórico do evadido vai até
-- o semestre anterior à evasão. Recorte por faixa econômica, raça/etnia ou deficiência nos filtros.
select case when a.tipoevasao is null then 'Não evadidos' else 'Evadidos' end
         || ' (n=' || count(distinct a.id_aluno) || ')' as grupo,
       round(avg(f.medianota), 2) as media_nota,
       round(avg(100.0 * f.qtdfaltas / d.cargahoraria), 1) as pct_faltas
from fatorendimentoaluno f
    join aluno a on a.id_aluno = f.id_aluno
    join curso c on c.id_curso = f.id_curso
    join data dt on dt.id_data = f.id_data
    join disciplina d on d.id_disciplina = f.id_disciplina
    join turmaaluno ta on ta.id_turmaaluno = f.id_turmaaluno
where not f.periodotrancado
group by a.tipoevasao is null
order by a.tipoevasao is null;

-- 1.7 Situação de integralização dos alunos ativos por curso (%)  [barras horizontais]
-- Alunos ativos no último semestre. Acima do tempo máximo: semestres decorridos > tempoMaximoConcluir.
-- Em risco: no ritmo regular (cargaHorariaTotal ÷ tempoMinimoConcluir por semestre), o que falta não cabe até o tempo máximo.
-- Atrasado: carga integralizada abaixo da esperada para os semestres decorridos. Dentro do fluxo: os demais.
with ref as (select ano, semestre from data order by ano desc, semestre desc limit 1),
alunos as (
    select c.departamento as curso, ta.anosemestreingresso as coorte, a.tipoevasao is not null as evadiu,
           a.cargahorariaintegralizadaatual as ch, c.cargahorariatotal as total,
           c.tempominimoconcluir as tmin, c.tempomaximoconcluir as tmax,
           (r.ano - ta.anoingresso) * 2 + (r.semestre - ta.semestreingresso) + 1 as n
    from aluno a
    join curso c on c.id_curso = a.id_curso
    join (select distinct id_aluno, id_turmaaluno from fatorendimentoaluno) fa on fa.id_aluno = a.id_aluno
    join turmaaluno ta on ta.id_turmaaluno = fa.id_turmaaluno
    cross join ref r
    where c.cargahorariatotal is not null
),
situacao as (
    select curso, coorte, case
        when evadiu then 'Evadido'
        when n > tmax then 'Acima do tempo máximo'
        when (total - ch) / (total * 1.0 / tmin) > tmax - n then 'Em risco de ultrapassar o tempo máximo'
        when ch < total * least(n, tmin) * 1.0 / tmin then 'Atrasado'
        else 'Dentro do fluxo' end as situacao
    from alunos
)
select curso || ' (n=' || count(*) || ')' as curso,
       round(100.0 * count(*) filter (where situacao = 'Dentro do fluxo') / count(*), 1) as dentro,
       round(100.0 * count(*) filter (where situacao = 'Atrasado') / count(*), 1) as atrasado,
       round(100.0 * count(*) filter (where situacao = 'Em risco de ultrapassar o tempo máximo') / count(*), 1) as em_risco,
       round(100.0 * count(*) filter (where situacao = 'Acima do tempo máximo') / count(*), 1) as acima
from situacao
where situacao <> 'Evadido'
group by curso
order by curso;

-- 2.1 Resultados de cada professor na disciplina em foco (%)  [barras horizontais]
-- Escolha a disciplina no filtro "Disciplina em foco". "DISCIPLINA TODA" é a referência.
-- Professor responsável pela turma (id_professor1); ordenado pela taxa de reprovação total.
with base as (
    select p.nome as professor, f.qtdaprovacoesnota as ap, f.qtdreprovacoesnota as rn, f.qtdreprovacoesfalta as rf
    from fatorendimentodisciplina f
    join curso c on c.id_curso = f.id_curso
    join data dt on dt.id_data = f.id_data
    join disciplina d on d.id_disciplina = f.id_disciplina
    join turmadisciplina t on t.id_turmadisciplina = f.id_turmadisciplina
    join professor p on p.id_professor = t.id_professor1
    where 'Disc. ' || f.id_disciplina = 'Disc. 105'
)
select professor, aprovados, reprovados_nota, reprovados_falta from (
    select professor, sum(ap) as aprovados, sum(rn) as reprovados_nota, sum(rf) as reprovados_falta, 1 as ordem
    from base group by professor
    union all
    select 'DISCIPLINA TODA', sum(ap), sum(rn), sum(rf), 0 from base
) t
order by ordem, (reprovados_nota + reprovados_falta) * 1.0
                / nullif(aprovados + reprovados_nota + reprovados_falta, 0) desc;

-- 2.2 Distribuição das notas por departamento (%)  [barras horizontais]
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
    join data dt on dt.id_data = f.id_data
    join disciplina d on d.id_disciplina = f.id_disciplina
    join turmadisciplina t on t.id_turmadisciplina = f.id_turmadisciplina
where true
group by 1
order by (sum(f.qtdnotas8_8_9) + sum(f.qtdnotas9_10)) * 1.0
         / nullif(sum(f.qtdnotas0_2_9 + f.qtdnotas3_6_9 + f.qtdnotas7_7_9 + f.qtdnotas8_8_9 + f.qtdnotas9_10), 0) desc;

-- 2.3a Aprovação por nota ao longo dos semestres (%)  [linhas]
-- Aprovados por nota ÷ matriculados. Use o filtro "Separar evolução por" (Turno ou Modalidade).
select dt.anosemestre as semestre,
       case when lower('Turno') = 'modalidade' then c.modalidadeensino else c.turno end as grupo,
       round(100.0 * sum(f.qtdaprovacoesnota) / sum(f.qtdmatriculados), 1) as pct_aprovacao
from fatorendimentodisciplina f
    join curso c on c.id_curso = f.id_curso
    join data dt on dt.id_data = f.id_data
    join disciplina d on d.id_disciplina = f.id_disciplina
    join turmadisciplina t on t.id_turmadisciplina = f.id_turmadisciplina
where true
group by 1, 2
order by 1, 2;

-- 2.3b Faltas ao longo dos semestres (% da carga horária)  [linhas]
-- Média de faltas ponderada pelos matriculados, convertida em % da carga horária da disciplina.
select dt.anosemestre as semestre,
       case when lower('Turno') = 'modalidade' then c.modalidadeensino else c.turno end as grupo,
       round(sum(f.mediafaltas * f.qtdmatriculados / d.cargahoraria * 100) / sum(f.qtdmatriculados), 1)
         as pct_faltas
from fatorendimentodisciplina f
    join curso c on c.id_curso = f.id_curso
    join data dt on dt.id_data = f.id_data
    join disciplina d on d.id_disciplina = f.id_disciplina
    join turmadisciplina t on t.id_turmadisciplina = f.id_turmadisciplina
where true
group by 1, 2
order by 1, 2;

-- 2.7a Mediana das notas por disciplina e horário  [barras]
-- Horário traduzido: 2 = segunda, 3 = terça, 4 = quarta, 5 = quinta; M = manhã, N = noite.
select 'Disc. ' || f.id_disciplina as disciplina,
       case t.horario when '24M12' then 'Seg/Qua – manhã' when '35N12' then 'Ter/Qui – noite' else t.horario end
         as horario,
       round(avg(f.medianotas), 2) as mediana_notas
from fatorendimentodisciplina f
    join curso c on c.id_curso = f.id_curso
    join data dt on dt.id_data = f.id_data
    join disciplina d on d.id_disciplina = f.id_disciplina
    join turmadisciplina t on t.id_turmadisciplina = f.id_turmadisciplina
where f.id_disciplina <> 101
group by f.id_disciplina, t.horario
order by f.id_disciplina, t.horario;

-- 2.7b Reprovação por falta por disciplina e horário (%)  [barras]
-- Reprovados por falta ÷ matriculados, mesma disciplina em horários diferentes.
select 'Disc. ' || f.id_disciplina as disciplina,
       case t.horario when '24M12' then 'Seg/Qua – manhã' when '35N12' then 'Ter/Qui – noite' else t.horario end
         as horario,
       round(100.0 * sum(f.qtdreprovacoesfalta) / sum(f.qtdmatriculados), 1) as pct_reprov_falta
from fatorendimentodisciplina f
    join curso c on c.id_curso = f.id_curso
    join data dt on dt.id_data = f.id_data
    join disciplina d on d.id_disciplina = f.id_disciplina
    join turmadisciplina t on t.id_turmadisciplina = f.id_turmadisciplina
where f.id_disciplina <> 101
group by f.id_disciplina, t.horario
order by f.id_disciplina, t.horario;

-- 2.4 Disciplinas obrigatórias mais críticas por centro (% de notas de 0 a 2,9)  [barras horizontais]
-- As 10 combinações centro × disciplina obrigatória com maior parcela de notas críticas.
select c.centro || ' · Disc. ' || f.id_disciplina as disciplina,
       round(100.0 * sum(f.qtdnotas0_2_9)
             / sum(f.qtdnotas0_2_9 + f.qtdnotas3_6_9 + f.qtdnotas7_7_9 + f.qtdnotas8_8_9 + f.qtdnotas9_10), 1)
         as pct_notas_criticas
from fatorendimentodisciplina f
    join curso c on c.id_curso = f.id_curso
    join data dt on dt.id_data = f.id_data
    join disciplina d on d.id_disciplina = f.id_disciplina
    join turmadisciplina t on t.id_turmadisciplina = f.id_turmadisciplina
where d.tipo = 'Obrigatória' and f.id_disciplina <> 101
group by c.centro, f.id_disciplina
order by pct_notas_criticas desc
limit 10;

-- 2.5 Co-docência: aprovação e amplitude das notas por nº de professores  [barras + linha]
-- Taxa de aprovação por nota (barras) e amplitude média das notas, maior − menor (linha, eixo direito),
-- por número de professores da turma.
with turmas as (
    select f.*, 1 + (t.id_professor2 is not null)::int + (t.id_professor3 is not null)::int as n_prof
    from fatorendimentodisciplina f
    join curso c on c.id_curso = f.id_curso
    join data dt on dt.id_data = f.id_data
    join disciplina d on d.id_disciplina = f.id_disciplina
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

-- 2.6 Matriculados por semestre e modalidade de ensino  [área empilhada]
-- Área empilhada: a altura total é a demanda do semestre; cada cor, a parcela da modalidade.
select dt.anosemestre as semestre, c.modalidadeensino as modalidade, sum(f.qtdmatriculados) as matriculados
from fatorendimentodisciplina f
    join curso c on c.id_curso = f.id_curso
    join data dt on dt.id_data = f.id_data
    join disciplina d on d.id_disciplina = f.id_disciplina
    join turmadisciplina t on t.id_turmadisciplina = f.id_turmadisciplina
where true
group by 1, 2
order by 1, 2;
