-- ========================================================
-- Povoamento adicional com dados sintéticos em português
-- Complementa o registro de exemplo do PDF (02_seed_pdf.sql).
-- Todos os dados são fictícios e determinísticos (sem random()),
-- então rodar o script sempre gera o mesmo resultado.
-- Volume: 7 cursos, 11 professores, 9 disciplinas, 6 semestres,
-- 201 alunos e ~2.400 registros de rendimento.
-- ========================================================

-- Função auxiliar: número pseudoaleatório determinístico em [0, modulo)
CREATE OR REPLACE FUNCTION pseudo(semente TEXT, modulo INT) RETURNS INT AS $$
    SELECT (('x' || substr(md5(semente), 1, 7))::bit(28)::int) % modulo;
$$ LANGUAGE sql IMMUTABLE;

-- Ajuste no curso do PDF: modalidadeCurso passa a descrever o grau e
-- modalidadeEnsino a forma de oferta (Presencial/EAD), usada nas consultas 2.3 e 2.6.
UPDATE Curso SET modalidadeCurso = 'Bacharelado', modalidadeEnsino = 'Presencial' WHERE id_curso = 1;

-- --------------------------------------------------------
-- Dimensão Data (semestres 2024.1 a 2025.2)
-- --------------------------------------------------------
INSERT INTO Data VALUES
    (3, 2024, 1, '2024.1'),
    (4, 2024, 2, '2024.2'),
    (5, 2025, 1, '2025.1'),
    (6, 2025, 2, '2025.2');

-- --------------------------------------------------------
-- Dimensão Curso
-- --------------------------------------------------------
INSERT INTO Curso VALUES
    (2, 'Graduação', 8,  'Noturno',    'Sistemas de Informação',  'CIn',  'Campus Recife',   'Bacharelado',  'Presencial', 8,  14, '2019.1'),
    (3, 'Graduação', 10, 'Integral',   'Engenharia Civil',        'CTG',  'Campus Recife',   'Bacharelado',  'Presencial', 10, 15, '2018.2'),
    (4, 'Graduação', 12, 'Integral',   'Medicina',                'CCM',  'Campus Recife',   'Bacharelado',  'Presencial', 12, 18, '2017.1'),
    (5, 'Graduação', 8,  'Noturno',    'Administração',           'CCSA', 'Ensino a Distância', 'Bacharelado', 'EAD',        8,  12, '2021.1'),
    (6, 'Graduação', 8,  'Matutino',   'Letras',                  'CAC',  'Campus Recife',   'Licenciatura', 'Presencial', 8,  12, '2019.2'),
    (7, 'Graduação', 8,  'Vespertino', 'Física',                  'CCEN', 'Campus Caruaru',  'Licenciatura', 'Presencial', 8,  14, '2020.2');

-- --------------------------------------------------------
-- Dimensão Professor (CPFs fictícios)
-- --------------------------------------------------------
INSERT INTO Professor VALUES
    (2,  'Fernanda Albuquerque Lima',  '1975-08-21', 'Feminino',  'Casa Forte',   '000.000.002-00', 'Brasileira', 'Recife'),
    (3,  'Roberto Cavalcanti Melo',    '1968-02-03', 'Masculino', 'Graças',       '000.000.003-00', 'Brasileira', 'Olinda'),
    (4,  'Juliana Pereira Barros',     '1983-11-30', 'Feminino',  'Boa Viagem',   '000.000.004-00', 'Brasileira', 'Caruaru'),
    (5,  'Antônio Carlos Medeiros',    '1971-06-14', 'Masculino', 'Madalena',     '000.000.005-00', 'Brasileira', 'Garanhuns'),
    (6,  'Patrícia Nascimento Rocha',  '1979-04-09', 'Feminino',  'Torre',        '000.000.006-00', 'Brasileira', 'Recife'),
    (7,  'Marcelo Tavares Gomes',      '1985-09-27', 'Masculino', 'Pina',         '000.000.007-00', 'Brasileira', 'Petrolina'),
    (8,  'Luciana Ferreira Duarte',    '1973-12-18', 'Feminino',  'Várzea',       '000.000.008-00', 'Brasileira', 'Recife'),
    (9,  'Eduardo Siqueira Neves',     '1966-01-25', 'Masculino', 'Casa Amarela', '000.000.009-00', 'Brasileira', 'Jaboatão dos Guararapes'),
    (10, 'Camila Souza Vasconcelos',   '1988-07-07', 'Feminino',  'Imbiribeira',  '000.000.010-00', 'Brasileira', 'Paulista'),
    (11, 'Henrique Lacerda Pinto',     '1981-03-16', 'Masculino', 'Boa Vista',    '000.000.011-00', 'Brasileira', 'Recife');

-- --------------------------------------------------------
-- Dimensão Disciplina
-- --------------------------------------------------------
INSERT INTO Disciplina VALUES
    (102, 60, 4, 'Obrigatória'),
    (103, 60, 4, 'Obrigatória'),
    (104, 90, 6, 'Obrigatória'),
    (105, 45, 3, 'Obrigatória'),
    (106, 60, 4, 'Optativa'),
    (107, 30, 2, 'Eletiva'),
    (108, 60, 4, 'Obrigatória'),
    (109, 75, 5, 'Optativa');

-- --------------------------------------------------------
-- Dimensão TurmaDisciplina: 2 turmas (manhã e noite) por disciplina e semestre
-- id = 10000 + (disciplina - 100) * 100 + semestre * 10 + turma
-- --------------------------------------------------------
INSERT INTO TurmaDisciplina
SELECT 10000 + (d - 100) * 100 + p * 10 + t,
       d,
       2 + ((d + p + t) % 10),
       dt.anoSemestre,
       CASE t WHEN 1 THEN '24M12' ELSE '35N12' END
FROM generate_series(102, 109) AS d
CROSS JOIN generate_series(1, 6) AS p
CROSS JOIN generate_series(1, 2) AS t
JOIN Data dt ON dt.id_data = p;

-- --------------------------------------------------------
-- Dimensão TurmaAluno: coortes de 2021.1 a 2024.2 (20231 já existe no PDF)
-- --------------------------------------------------------
INSERT INTO TurmaAluno
SELECT (2021 + c / 2) * 10 + 1 + c % 2,
       2021 + c / 2,
       1 + c % 2,
       (2021 + c / 2)::text || '.' || (1 + c % 2)::text,
       8,
       14
FROM generate_series(0, 7) AS c
ON CONFLICT (id_turmaAluno) DO NOTHING;

-- --------------------------------------------------------
-- Dimensão Aluno: 200 alunos (ids 1002 a 1201)
-- A coorte do aluno é (i % 8): 0 = 2021.1, 1 = 2021.2, ..., 7 = 2024.2
-- Alunos evadidos têm ano/semestre de evasão entre 2023.2 e 2025.2
-- --------------------------------------------------------
INSERT INTO Aluno
WITH nomes AS (
    SELECT
        ARRAY['Maria','Ana','Beatriz','Camila','Daniela','Eduarda','Fernanda','Gabriela','Helena','Isabela',
              'Juliana','Larissa','Mariana','Natália','Patrícia','Rafaela','Sandra','Tatiane','Vanessa','Yasmin'] AS fem,
        ARRAY['João','Pedro','Lucas','Gabriel','Rafael','Matheus','Felipe','Bruno','Carlos','Diego',
              'Eduardo','Fábio','Gustavo','Henrique','Igor','José','Leonardo','Marcos','Rodrigo','Thiago'] AS masc,
        ARRAY['Silva','Souza','Oliveira','Santos','Lima','Pereira','Ferreira','Costa','Rodrigues','Almeida',
              'Nascimento','Araújo','Ribeiro','Carvalho','Gomes','Martins','Barbosa','Moura','Cavalcanti','Albuquerque',
              'Vasconcelos','Medeiros','Teixeira','Pinto','Barros','Rocha','Duarte','Tavares','Lacerda','Machado'] AS sob,
        ARRAY['Boa Viagem','Iputinga','Casa Amarela','Várzea','Madalena','Torre','Afogados','Ibura','Graças','Boa Vista',
              'Cordeiro','Pina','Imbiribeira','Casa Forte','Tejipió','Jardim São Paulo','Santo Amaro','Encruzilhada','Apipucos','Peixinhos'] AS bairros,
        ARRAY['Recife','Olinda','Jaboatão dos Guararapes','Caruaru','Petrolina','Garanhuns','Paulista','Camaragibe',
              'Vitória de Santo Antão','Maceió'] AS cidades
),
base AS (
    SELECT i,
           i % 8                                    AS c,
           2021 + (i % 8) / 2                       AS ano_ing,
           1 + (i % 8) % 2                          AS sem_ing,
           CASE WHEN i % 2 = 0 THEN 'Feminino' ELSE 'Masculino' END AS genero,
           CASE WHEN pseudo('fe' || i, 10) < 4 THEN 'Baixa'
                WHEN pseudo('fe' || i, 10) < 8 THEN 'Média'
                ELSE 'Alta' END                     AS faixa
    FROM generate_series(1, 200) AS i
),
ev AS (
    SELECT b.*,
           GREATEST(1, (b.ano_ing - 2023) * 2 + b.sem_ing) AS inicio,   -- 1 = 2023.1
           (b.i % 9 = 0 OR (b.faixa = 'Baixa' AND b.i % 11 = 0)) AS evadiu
    FROM base b
),
ev2 AS (
    -- indice do semestre de evasão (1 = 2023.1 ... 6 = 2025.2), sempre após o início
    SELECT e.*,
           CASE WHEN e.evadiu THEN e.inicio + 1 + (e.i % (6 - e.inicio)) END AS idx_evasao
    FROM ev e
)
SELECT 1001 + e.i,
       1 + (e.i % 7),
       e.faixa,
       (e.ano_ing)::text || e.sem_ing::text || lpad(e.i::text, 4, '0'),
       CASE WHEN e.faixa = 'Alta' AND pseudo('esc' || e.i, 10) < 8 THEN 'Escola Privada' ELSE 'Escola Pública' END,
       CASE WHEN pseudo('fi' || e.i, 10) < 6 THEN 'Sisu'
            WHEN pseudo('fi' || e.i, 10) < 9 THEN 'Vestibular'
            ELSE 'Transferência' END,
       CASE WHEN e.faixa = 'Baixa' THEN (ARRAY['L1','L2','PPI','Ampla concorrência'])[1 + pseudo('co' || e.i, 4)]
            ELSE (ARRAY['Ampla concorrência','Ampla concorrência','Ampla concorrência','L5'])[1 + pseudo('co' || e.i, 4)] END,
       CASE WHEN pseudo('fi' || e.i, 10) < 6 THEN 'Enem'
            WHEN pseudo('fi' || e.i, 10) < 9 THEN 'Prova Própria'
            ELSE 'Transferência Externa' END,
       CASE WHEN e.evadiu THEN 2023 + (e.idx_evasao - 1) / 2 END,
       CASE WHEN e.evadiu THEN 1 + (e.idx_evasao - 1) % 2 END,
       CASE WHEN e.evadiu THEN (ARRAY['Abandono','Abandono','Cancelamento','Transferência'])[1 + pseudo('te' || e.i, 4)] END,
       (e.faixa = 'Baixa' AND pseudo('as' || e.i, 10) < 6),
       -- carga horária: semestres cursados até o último período ativo
       LEAST(3200, ((CASE WHEN e.evadiu THEN e.idx_evasao - 1 ELSE 6 END) - ((e.ano_ing - 2023) * 2 + e.sem_ing) + 1)
                    * (260 + pseudo('ch' || e.i, 100))),
       -- nome: primeiro nome + sobrenome da mãe + sobrenome do pai
       CASE WHEN e.genero = 'Feminino' THEN n.fem[1 + pseudo('pn' || e.i, 20)] ELSE n.masc[1 + pseudo('pn' || e.i, 20)] END
           || ' ' || n.sob[1 + pseudo('sm' || e.i, 30)] || ' ' || n.sob[1 + pseudo('sp' || e.i, 30)],
       make_date(e.ano_ing - 18 - CASE WHEN pseudo('ag' || e.i, 10) < 7 THEN pseudo('ay' || e.i, 5)
                                       ELSE 3 + pseudo('ay' || e.i, 15) END, 1, 1) + pseudo('dn' || e.i, 365),
       NULL,  -- faixaEtaria é calculada no UPDATE abaixo
       e.genero,
       (ARRAY['Parda','Parda','Parda','Parda','Branca','Branca','Branca','Preta','Preta','Amarela'])[1 + pseudo('ra' || e.i, 10)],
       n.bairros[1 + pseudo('ba' || e.i, 20)],
       lpad((100 + e.i)::text, 3, '0') || '.000.' || lpad(e.i::text, 3, '0') || '-00',
       'Brasileira',
       n.cidades[1 + pseudo('na' || e.i, 10)],
       n.fem[1 + pseudo('mn' || e.i, 20)]  || ' ' || n.sob[1 + pseudo('sm' || e.i, 30)],
       n.masc[1 + pseudo('pa' || e.i, 20)] || ' ' || n.sob[1 + pseudo('sp' || e.i, 30)],
       (ARRAY['Solteiro','Solteiro','Solteiro','Solteiro','Solteiro','Casado','União estável','Divorciado'])[1 + pseudo('ec' || e.i, 8)],
       CASE WHEN pseudo('de' || e.i, 20) < 17 THEN 'Nenhuma'
            ELSE (ARRAY['Visual','Auditiva','Física'])[1 + pseudo('dt' || e.i, 3)] END,
       e.ano_ing - 1
FROM ev2 e CROSS JOIN nomes n;

-- Faixa etária calculada pela idade em 31/12/2025
UPDATE Aluno
SET faixaEtaria = CASE
        WHEN date_part('year', age(DATE '2025-12-31', dataNascimento)) <= 20 THEN '18-20'
        WHEN date_part('year', age(DATE '2025-12-31', dataNascimento)) <= 25 THEN '21-25'
        WHEN date_part('year', age(DATE '2025-12-31', dataNascimento)) <= 30 THEN '26-30'
        ELSE '31+' END
WHERE id_aluno > 1001;

-- --------------------------------------------------------
-- Fato 1: FatoRendimentoAluno
-- Cada aluno cursa 3 disciplinas por semestre, do início (ou 2023.1)
-- até o semestre anterior à evasão. Semestre trancado: nota NULL.
-- --------------------------------------------------------
INSERT INTO FatoRendimentoAluno
WITH matriculas AS (
    SELECT a.id_aluno,
           a.id_curso,
           a.faixaEconomica,
           a.assistenciaEstudantil,
           (a.id_aluno - 1001)                                   AS i,
           p.p                                                   AS periodo,
           k.k                                                   AS k,
           ((a.id_aluno - 1001) % 8)                             AS c
    FROM Aluno a
    CROSS JOIN generate_series(1, 6) AS p(p)
    CROSS JOIN generate_series(0, 2) AS k(k)
    WHERE a.id_aluno > 1001
      -- semestre >= início (ingresso ou 2023.1) e anterior à evasão
      AND p.p >= GREATEST(1, ((2021 + ((a.id_aluno - 1001) % 8) / 2) - 2023) * 2 + 1 + ((a.id_aluno - 1001) % 8) % 2)
      AND p.p <= CASE WHEN a.anoEvasao IS NULL THEN 6
                      ELSE (a.anoEvasao - 2023) * 2 + a.semestreEvasao - 1 END
),
com_turma AS (
    SELECT m.*,
           102 + (pseudo(m.i || '-' || m.periodo, 8) + m.k * 3) % 8 AS d,
           1 + pseudo('t' || m.i || '-' || m.periodo || '-' || m.k, 2) AS t,
           -- trancamento vale para o semestre inteiro; mais frequente em baixa renda sem assistência
           (pseudo('tr' || m.i || '-' || m.periodo,
                   CASE WHEN m.faixaEconomica = 'Baixa' AND NOT m.assistenciaEstudantil THEN 12 ELSE 30 END) = 0) AS trancado,
           CASE WHEN pseudo('z' || m.i || '-' || m.periodo || '-' || m.k, 25) = 0
                THEN pseudo('zn' || m.i || m.periodo || m.k, 30) / 10.0           -- notas muito baixas (0 a 2,9)
                ELSE LEAST(10, 4.2 + pseudo('n' || m.i || '-' || m.periodo || '-' || m.k, 100) * 0.058
                               + CASE m.faixaEconomica WHEN 'Alta' THEN 0.4 WHEN 'Média' THEN 0.2 ELSE 0 END
                               + CASE WHEN m.assistenciaEstudantil THEN 0.3 ELSE 0 END)
           END AS nota,
           pseudo('f' || m.i || '-' || m.periodo || '-' || m.k, 13)
             + CASE WHEN pseudo('s' || m.i || '-' || m.periodo || '-' || m.k, 19) = 0 THEN 18 ELSE 0 END AS faltas
    FROM matriculas m
)
SELECT 1 + ROW_NUMBER() OVER (ORDER BY t.id_aluno, t.periodo, t.k),
       t.id_aluno,
       (2021 + t.c / 2) * 10 + 1 + t.c % 2,
       t.d,
       10000 + (t.d - 100) * 100 + t.periodo * 10 + t.t,
       t.id_curso,
       t.periodo,
       CASE WHEN t.trancado        THEN 'Trancado'
            WHEN t.faltas >= 18    THEN 'Reprovado por Falta'
            WHEN t.nota < 5        THEN 'Reprovado por Nota'
            ELSE 'Aprovado' END,
       CASE WHEN t.trancado THEN 0 ELSE t.faltas END,
       CASE WHEN t.trancado THEN NULL ELSE ROUND(t.nota::numeric, 2) END,
       t.trancado
FROM com_turma t;

-- --------------------------------------------------------
-- Fato 2: FatoRendimentoDisciplina
-- Agregação da Fato 1 por turma e curso (alunos trancados não contam como matriculados)
-- --------------------------------------------------------
INSERT INTO FatoRendimentoDisciplina
SELECT 1 + ROW_NUMBER() OVER (ORDER BY id_turmaDisciplina, id_curso),
       id_disciplina,
       id_turmaDisciplina,
       id_curso,
       id_data,
       COUNT(*) FILTER (WHERE statusAluno = 'Aprovado'),
       COUNT(*) FILTER (WHERE statusAluno = 'Reprovado por Nota'),
       COUNT(*) FILTER (WHERE statusAluno = 'Reprovado por Falta'),
       MIN(mediaNota),
       MAX(mediaNota),
       percentile_cont(0.5) WITHIN GROUP (ORDER BY mediaNota),
       AVG(mediaNota),
       AVG(qtdFaltas),
       COUNT(*),
       COUNT(*) FILTER (WHERE mediaNota <  3),
       COUNT(*) FILTER (WHERE mediaNota >= 3 AND mediaNota < 7),
       COUNT(*) FILTER (WHERE mediaNota >= 7 AND mediaNota < 8),
       COUNT(*) FILTER (WHERE mediaNota >= 8 AND mediaNota < 9),
       COUNT(*) FILTER (WHERE mediaNota >= 9)
FROM FatoRendimentoAluno
WHERE periodoTrancado = FALSE
  AND id_fatoAluno > 1
GROUP BY id_disciplina, id_turmaDisciplina, id_curso, id_data;
