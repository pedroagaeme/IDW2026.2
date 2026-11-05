-- ========================================================
-- Esquemas Estrela: FatoRendimentoAluno e FatoRendimentoDisciplina
-- Fonte: "Prototipação - Construção dos Esquemas Estrela.pdf"
-- Alvo: PostgreSQL 16
-- Ajuste em relação ao PDF: as colunas qtdNotas0_2,9 etc. não são
-- identificadores válidos; a vírgula virou "_" (qtdNotas0_2_9, ...).
-- ========================================================

-- 1. DIMENSÕES COMPARTILHADAS
CREATE TABLE Data (
    id_data      INT PRIMARY KEY,
    ano          INT NOT NULL,
    semestre     INT NOT NULL,
    anoSemestre  VARCHAR(10) NOT NULL
);

CREATE TABLE Curso (
    id_curso            INT PRIMARY KEY,
    nivelEnsino         VARCHAR(50),
    duracao             INT,
    turno               VARCHAR(20),
    departamento        VARCHAR(100),
    centro              VARCHAR(100),
    campim              VARCHAR(100),
    modalidadeCurso     VARCHAR(50),
    modalidadeEnsino    VARCHAR(50),
    tempoMinimoConcluir INT,
    tempoMaximoConcluir INT,
    curriculo           VARCHAR(50)
);

CREATE TABLE Professor (
    id_professor     INT PRIMARY KEY,
    nome             VARCHAR(100),
    dataNascimento   DATE,
    genero           VARCHAR(20),
    bairroResidencia VARCHAR(100),
    cpf              VARCHAR(14),
    nacionalidade    VARCHAR(50),
    naturalidade     VARCHAR(50)
);

CREATE TABLE Disciplina (
    id_disciplina INT PRIMARY KEY,
    cargaHoraria  INT,
    creditos      INT,
    tipo          VARCHAR(50)
);

CREATE TABLE TurmaDisciplina (
    id_turmaDisciplina INT PRIMARY KEY,
    id_disciplina      INT,
    id_professor1      INT,
    periodo            VARCHAR(20),
    horario            VARCHAR(50),
    FOREIGN KEY (id_disciplina)  REFERENCES Disciplina(id_disciplina),
    FOREIGN KEY (id_professor1)  REFERENCES Professor(id_professor)
);

CREATE TABLE TurmaAluno (
    id_turmaAluno           INT PRIMARY KEY,
    anoIngresso             INT,
    semestreIngresso        INT,
    anoSemestreIngresso     VARCHAR(10),
    semestreMinimoConclusao INT,
    semestreMaximoConclusao INT
);

CREATE TABLE Aluno (
    id_aluno                       INT PRIMARY KEY,
    id_curso                       INT,
    faixaEconomica                 VARCHAR(20),
    numeroMatricula                VARCHAR(20),
    escolaEnsinoMedio              VARCHAR(50),
    formaIngresso                  VARCHAR(50),
    tipoCota                       VARCHAR(50),
    meioIngresso                   VARCHAR(50),
    anoEvasao                      INT,
    semestreEvasao                 INT,
    tipoEvasao                     VARCHAR(50),
    assistenciaEstudantil          BOOLEAN,
    cargaHorariaIntegralizadaAtual INT,
    nome                           VARCHAR(100),
    dataNascimento                 DATE,
    faixaEtaria                    VARCHAR(20),
    genero                         VARCHAR(20),
    raca_etnia                     VARCHAR(50),
    bairroResidencia               VARCHAR(100),
    cpf                            VARCHAR(14),
    nacionalidade                  VARCHAR(50),
    naturalidade                   VARCHAR(50),
    nomeMae                        VARCHAR(100),
    nomePai                        VARCHAR(100),
    estadoCivil                    VARCHAR(20),
    deficiencia                    VARCHAR(50),
    anoConclusaoEnsinoMedio        INT,
    FOREIGN KEY (id_curso) REFERENCES Curso(id_curso)
);

-- 2. TABELAS FATO
CREATE TABLE FatoRendimentoAluno (
    id_fatoAluno       INT PRIMARY KEY,
    id_aluno           INT,
    id_turmaAluno      INT,
    id_disciplina      INT,
    id_turmaDisciplina INT,
    id_curso           INT,
    id_data            INT,
    statusAluno        VARCHAR(30),
    qtdFaltas          INT,
    mediaNota          DECIMAL(4,2),
    periodoTrancado    BOOLEAN,
    FOREIGN KEY (id_aluno)           REFERENCES Aluno(id_aluno),
    FOREIGN KEY (id_turmaAluno)      REFERENCES TurmaAluno(id_turmaAluno),
    FOREIGN KEY (id_disciplina)      REFERENCES Disciplina(id_disciplina),
    FOREIGN KEY (id_turmaDisciplina) REFERENCES TurmaDisciplina(id_turmaDisciplina),
    FOREIGN KEY (id_curso)           REFERENCES Curso(id_curso),
    FOREIGN KEY (id_data)            REFERENCES Data(id_data)
);

CREATE TABLE FatoRendimentoDisciplina (
    id_fatoDisciplina   INT PRIMARY KEY,
    id_disciplina       INT,
    id_turmaDisciplina  INT,
    id_curso            INT,
    id_data             INT,
    qtdAprovacoesNota   INT,
    qtdReprovacoesNota  INT,
    qtdReprovacoesFalta INT,
    menorNota           DECIMAL(4,2),
    maiorNota           DECIMAL(4,2),
    medianaNotas        DECIMAL(4,2),
    mediaNotas          DECIMAL(4,2),
    mediaFaltas         DECIMAL(4,2),
    qtdMatriculados     INT,
    qtdNotas0_2_9       INT,
    qtdNotas3_6_9       INT,
    qtdNotas7_7_9       INT,
    qtdNotas8_8_9       INT,
    qtdNotas9_10        INT,
    FOREIGN KEY (id_disciplina)      REFERENCES Disciplina(id_disciplina),
    FOREIGN KEY (id_turmaDisciplina) REFERENCES TurmaDisciplina(id_turmaDisciplina),
    FOREIGN KEY (id_curso)           REFERENCES Curso(id_curso),
    FOREIGN KEY (id_data)            REFERENCES Data(id_data)
);
