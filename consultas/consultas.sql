-- Consultas usadas no Metabase (perguntas SQL nativas) sobre os esquemas estrela.
-- Cada bloco indica a consulta do PDF e o tipo de gráfico sugerido.
-- Em PostgreSQL, os nomes sem aspas ficam em minúsculas (ex.: FatoRendimentoAluno -> fatorendimentoaluno).

-- 1.1 Taxa de evasão por forma de ingresso e cota (%)  [barras]
select formaingresso || ' / ' || tipocota as forma_cota,
       round(100.0 * count(*) filter (where tipoevasao is not null) / count(*), 1) as pct_evasao
from aluno
group by 1
having count(*) >= 3
order by 2 desc;

-- 1.2 Nota média por faixa econômica e assistência estudantil  [barras agrupadas]
select a.faixaeconomica,
       case when a.assistenciaestudantil then 'Com assistência' else 'Sem assistência' end as assistencia,
       round(avg(f.medianota), 2) as media_nota
from fatorendimentoaluno f
join aluno a on a.id_aluno = f.id_aluno
where f.medianota is not null
group by 1, 2
order by 1, 2;

-- 1.3 Taxa de trancamento de alunos de baixa renda por turno (%)  [barras agrupadas]
select c.turno,
       case when a.assistenciaestudantil then 'Com assistência' else 'Sem assistência' end as assistencia,
       round(100.0 * avg(case when f.periodotrancado then 1 else 0 end), 1) as pct_trancamento
from fatorendimentoaluno f
join aluno a on a.id_aluno = f.id_aluno
join curso c on c.id_curso = f.id_curso
where a.faixaeconomica = 'Baixa'
group by 1, 2
order by 1, 2;

-- 1.4 Bairros com maior média de faltas (top 10)  [barras]
select a.bairroresidencia as bairro, round(avg(f.qtdfaltas), 2) as media_faltas
from fatorendimentoaluno f
join aluno a on a.id_aluno = f.id_aluno
where not f.periodotrancado
group by 1
order by 2 desc
limit 10;

-- 1.5 Taxa de reprovação por disciplina, por nota e por falta (%)  [barras empilhadas]
select 'Disc. ' || id_disciplina as disciplina,
       round(100.0 * count(*) filter (where statusaluno = 'Reprovado por Nota') / count(*), 1) as reprov_nota,
       round(100.0 * count(*) filter (where statusaluno = 'Reprovado por Falta') / count(*), 1) as reprov_falta
from fatorendimentoaluno
where not periodotrancado
group by id_disciplina
order by id_disciplina;

-- 1.6 Evasão por faixa econômica, raça/etnia e deficiência (%)  [barras]
select * from (
    select 'Faixa econômica' as caracteristica, faixaeconomica as grupo,
           round(100.0 * count(*) filter (where tipoevasao is not null) / count(*), 1) as pct_evasao
    from aluno group by 2
    union all
    select 'Raça/etnia', raca_etnia,
           round(100.0 * count(*) filter (where tipoevasao is not null) / count(*), 1)
    from aluno group by 2
    union all
    select 'Deficiência', case when deficiencia = 'Nenhuma' then 'Nenhuma' else 'Com deficiência' end,
           round(100.0 * count(*) filter (where tipoevasao is not null) / count(*), 1)
    from aluno group by 2
) t
order by 1, 2;

-- 2.1 Distribuição de notas por departamento  [barras empilhadas]
select c.departamento,
       sum(f.qtdnotas0_2_9) as "0 a 2,9",
       sum(f.qtdnotas3_6_9) as "3 a 6,9",
       sum(f.qtdnotas7_7_9) as "7 a 7,9",
       sum(f.qtdnotas8_8_9) as "8 a 8,9",
       sum(f.qtdnotas9_10)  as "9 a 10"
from fatorendimentodisciplina f
join curso c on c.id_curso = f.id_curso
group by 1
order by 1;

-- 2.2 Aprovação por nota (%) e média de faltas por semestre  [linhas]
select d.anosemestre as semestre,
       round(100.0 * sum(f.qtdaprovacoesnota) / sum(f.qtdmatriculados), 1) as pct_aprovacao,
       round(avg(f.mediafaltas), 2) as media_faltas
from fatorendimentodisciplina f
join data d on d.id_data = f.id_data
group by 1
order by 1;

-- 2.3 Matriculados por semestre e modalidade de ensino  [área empilhada]
select d.anosemestre as semestre, c.modalidadeensino as modalidade, sum(f.qtdmatriculados) as matriculados
from fatorendimentodisciplina f
join data d on d.id_data = f.id_data
join curso c on c.id_curso = f.id_curso
group by 1, 2
order by 1, 2;

-- 2.4 Mediana de notas e reprovações por falta por horário  [barras]
select t.horario,
       round(avg(f.medianotas), 2) as mediana_notas,
       round(100.0 * sum(f.qtdreprovacoesfalta) / sum(f.qtdmatriculados), 1) as pct_reprov_falta
from fatorendimentodisciplina f
join turmadisciplina t on t.id_turmadisciplina = f.id_turmadisciplina
group by 1
order by 1;
