## **1\. Consultas Analíticas em Linguagem Natural**

### **Consultas para o Esquema 1 (FatoRendimentoAluno)**

1. **Taxa de Evasão Acadêmica por Forma de Ingresso e Cota:**  
   1. Qual é o percentual de alunos evadidos agrupados por formaIngresso e tipoCota?   
      \*Motivação de exemplo: saber se os alunos que ingressaram pelo SISU com cota de baixa renda evadem mais que os que também ingressaram pelo SISU, mas, sem cota.

2. **Impacto Socioeconômico no Desempenho Curricular:**   
   1. Qual a média/mediana da nota (mediaNota) dos alunos segmentados por faixaEconomica e recebimento de assistenciaEstudantil por curso?(aplicando minidimensão)  
      \*Motivação de exemplo: comparar se alunos do curso X de baixa renda que recebem assistência estudantil possuem um desempenho melhor do que aqueles que não recebem do mesmo curso.  
   2. Qual é a taxa de trancamento de período (periodoTrancado) dos alunos de baixa renda, segmentados por recebimento de assistenciaEstudantil e por turno do curso?   
      \*Motivação de exemplo: saber se alunos de baixa renda que recebem assistência estudantil trancam menos que os que não recebem, e se isso varia entre cursos integrais, matutinos e demais turnos.

3. **Análise de Desempenho por Disciplina:**   
   1. Para uma disciplina selecionada (parâmetro), qual a média de nota e o percentual de frequência dos alunos que a cursaram, comparando por genero e faixaEtaria?  
      \*Motivação de exemplo: analisar se a diferença de nota e de frequência entre mulheres e homens muda conforme a faixa etária. 

4. **Assiduidade e Local de Residência:**  
   1. Quais bairros de residência apresentam o maior percentual de faltas (faltas ÷ aulas previstas)?   
      \*Motivação de exemplo: comparar se alunos costumam faltar relacionado aos bairros que eles moram  
        
        
5. **Análise de Retenção e Reprovação de Alunos:**  
   1. Qual é a taxa de reprovação (por nota, por falta e total) de cada disciplina, por semestre, nos cursos do departamento Y, e quais ultrapassam X%?  
      Taxa: matrículas reprovadas ÷ matrículas na disciplina no semestre.  
   2. Qual o percentual de alunos ativos de cada curso que estão potencialmente retidos, isto é, com créditos integralizados abaixo do esperado para o período atual e que estão prestes a ultrapassar o tempo regular de conclusão?   
      Retido \= soma das situações “Atrasado”, “Em risco de ultrapassar o tempo máximo” e “Acima do tempo máximo” do item 7.1.  
      Motivação de exemplo: comparar quais cursos têm mais alunos retidos ou atrasados para a conclusão.   
        
6.  **Perfis de Risco de Evasão:**  
   1. Qual a taxa de evasão (abandono) dos alunos por racaEtnia, faixaEconomica e deficiencia (cada característica analisada separadamente), e como se comparam o percentual de faltas e a mediaNota acumulados até o período anterior à evasão entre alunos? (aplicando minidimensão)  
      Motivação de exemplo: identificar quais características e níveis de rendimento estão mais associados à evasão, em comparação com a base geral. 

7. **Análise do Desempenho Curricular vs. Tempo de Conclusão:**  
   1. Qual o percentual de alunos ativos de cada curso em cada situação de integralização (dentro do fluxo, atrasado, em risco de ultrapassar o tempo máximo, acima do tempo máximo), calculada pela relação entre cargaHorariaIntegralizadaAtual, a carga horária total do curso e o tempo decorrido em relação a tempoMinimoConcluir e tempoMaximoConcluir?   
      

### **Consultas para o Esquema 2 (FatoRendimentoDisciplina)**

1. **Índice de Reprovação por Disciplina e Professor:**   
   1. Para disciplinas ministradas por mais de um professor (turmas diferentes), como se comparam as taxas de reprovação por falta, por nota e total de cada professor em relação à taxa da própria disciplina?   
      \*Motivação de exemplo: identificar disciplinas em que a reprovação varia muito conforme o professor.  
        
2. **Distribuição do Perfil de Notas dos Departamentos:**   
   1. Qual a distribuição de alunos nas faixas de notas (qtdNotas0\_2,9, qtdNotas3\_6,9, qtdNotas7\_7,9, qtdNotas8\_8,9, qtdNotas9\_10) por departamento?  
      \*Motivação de exemplo: relação entre a quantidade de notas em cada departamento, podendo comparar qual deles tem notas mais baixas e mais altas. 

3. **Evolução Temporal da Média de Faltas e Aprovação:**   
   1. Como variaram o percentual médio de faltas e a taxa de aprovação por nota ao longo dos semestres acadêmicos, por turno e modalidadeEnsino?  
      Taxa de aprovação: qtdAprovaçõesNota ÷ qtdMatriculados.   
      Percentual de faltas: média ponderada de mediaFaltas, convertida em % das aulas previstas.  
      \*Motivação de exemplo: verificar se o desempenho e a assiduidade mudam ao longo do tempo e entre turnos e modalidades. 

4. **Gargalos Académicos:**  
   1. Quais disciplinas obrigatórias possuem a maior concentração de notas na faixa crítica (qtdNotas0\_2,9) e a menor média de notas (mediaNotas), segmentadas por centro?  
      \*Motivação de exemplo: comparar a quantidade de disciplinas que são mais complicadas dentro de cada centro.

5. **Impacto de Co-docência no Desempenho:**  
   1. Qual é a taxa média de aprovação (qtdAprovaçõesNota) e a dispersão das notas (diferença entre maiorNota e menorNota) em turmas regidas por mais de um professor versus turmas de docente único?  
      \*Motivação de exemplo: comparar se existe uma diferença entre estes tipos de disciplina e se afetam o rendimento dos alunos  
6. **Evolução da Demanda por Turno e Modalidade de Ensino:**  
   1. Como evoluiu o número total de matriculados (qtdMatriculados) ao longo dos semestres acadêmicos, comparando cursos presenciais versus ensino a distância (modalidadeEnsino)?  
      \*Motivação de exemplo: comparar se a demanda é maior a depender da modalidade de ensino

        
7. **Discrepância de Desempenho entre Horários:**  
   1. Existe diferença significativa na mediana de notas (medianaNotas) e nas reprovações por falta (qtdReprovaçõesFalta) para uma mesma disciplina quando lecionada em horários/períodos distintos (ex: matutino vs. nocturno)?  
      \*Motivação de exemplo: verificar se o horário de oferta está associado a diferenças de rendimento e de reprovação por falta 

## **2\. Argumentação da Escolha de Gráficos**

**Consulta 1.1 (Taxa de Evasão Acadêmica por Forma de Ingresso e Cota):**

* **Gráfico:** Gráfico de Barras Agrupadas.  
* **Justificativa:** Para análises estáticas por período, as barras agrupadas permitem comparar diretamente o percentual de evasão entre combinações de formaIngresso e tipoCota. 

**Consulta 1.2.1 (Média/mediana de nota por faixa econômica, assistência estudantil e curso)**

* **Gráfico: Barras agrupadas com painéis por curso** (small multiples). Em cada painel, X \= faixaEconomica, e uma barra para “recebe” e outra para “não recebe” assistência. Se quiser mostrar a mediana e a dispersão, use **boxplot** no lugar das barras.  
* **Justificativa**: são três dimensões categóricas. Separar por curso em painéis evita um gráfico poluído e mantém a comparação “mesmo curso, com vs. sem assistência”.

**Consulta 1.2.2 (Taxa de trancamento de baixa renda por assistência e turno)**

* **Gráfico: Barras agrupadas** (X \= turno; barras \= recebe / não recebe assistência; Y \= % de trancamento).  
* **Justificativa:** poucas categorias (integral, matutino, demais) e uma taxa, ideal para comparação direta.  
  **Consulta 1.3 (Análise de Desempenho por Disciplina):**  
* **Gráfico:** Gráfico de Dispersão (Scatter Plot).  
* **Justificativa:** O gráfico de dispersão plota cada aluno individualmente nos eixos X (notas) e Y (faltas), utilizando cores para gênero e formatos de marcadores para faixas etárias. Permite identificar padrões de comportamento e agrupamentos dentro de uma disciplina específica.  
  **Consulta 1.4 (Assiduidade e Local de Residência):**  
* **Gráfico:** Gráfico de Barras Empilhadas (100%).  
* **Justificativa:** Caso a ferramenta não suporte mapas, barras empilhadas por turno mostram a proporção de trancamento de período e faltas médias por região.

**Consulta 1.5.1 Taxa de reprovação (nota, falta, total) por disciplina e semestre, com limite X%**

* **Gráfico: Barras empilhadas** (reprovação por nota \+ por falta \= total) por disciplina, com uma **linha de referência no limite X%**, filtrado por semestre.  
* **Justificativa***: o empilhado mostra a composição da reprovação, e a linha de corte destaca visualmente quais ultrapassam X%.*

**Consulta 1.5.2 Percentual de alunos retidos por curso**

* **Gráfico: Barras horizontais ordenadas**, com a opção de empilhar as três situações de retenção (Atrasado, Em risco, Acima do tempo máximo).  
* **Justificativa:** a pergunta é um ranking entre cursos, e o empilhamento mostra a gravidade da retenção.  
  **Consulta 1.6 (Perfis de Risco de Evasão):**  
* **Gráfico:** Diagrama de Sankey.  
* **Justificativa:** O Diagrama de Sankey visualiza o fluxo e o volume de alunos desde suas características sociodemográficas (raça/etnia, faixaEconomica, deficiencia), passando por faixas de faltas e notas, até o desfecho no tipo de evasão (tipoEvasao).  
  **Consulta 1.7 (Análise do Desempenho Curricular vs. Tempo de Conclusão):**  
* **Gráfico:** Gráfico de Progresso.  
* **Justificativa:** O gráfico de progresso permite comparar a carga horária integralizada atual de um aluno ou coorte contra metas e limites bem definidos, exibindo claramente o intervalo esperado de conclusão (tempoMinimoConcluir e tempoMaximoConcluir).  
  **Consulta 2.1 (Índice de Reprovação por Disciplina e Professor):**  
* **Gráfico:** Gráfico de Barras Empilhadas (100%).  
* **Justificativa:** As barras empilhadas representam perfeitamente a proporção de aprovados vs. reprovados por nota vs. reprovados por falta para cada professor/disciplina.  
  **Consulta 2.2 (Distribuição do Perfil de Notas dos Departamentos):**  
* **Gráfico:** Gráfico de Área Empilhada.  
* **Justificativa:** As faixas (qtdNotas0\_2,9 a qtdNotas9\_10) já formam um agrupamento contínuo de histograma para cada departamento e curso, evidenciando o formato da curva de distribuição de notas da instituição.  
    
  **Consulta 2.3 (Evolução Temporal da Média de Faltas e Aprovação):**  
* **Gráfico:** Gráfico de Linhas de Eixo Duplo.  
* **Justificativa:** Permite acompanhar temporalmente duas métricas com escalas distintas ao longo dos semestres (Data): o eixo esquerdo acompanha o volume absoluto de aprovados (qtdAprovaçõesNota) e o eixo direito acompanha a média de faltas (mediaFaltas), segmentados por turno ou modalidade.  
  **Consulta 2.4 (Gargalos Acadêmicos):**  
* **Gráfico:** Treemap (Mapa de Árvore).  
* **Justificativa:** No Treemap, a área de cada retângulo representa a concentração de notas na faixa crítica (qtdNotas0\_2,9) e a cor representa a menor média geral de notas, organizados por hierarquia de centro e departamento.  
  **Consulta 2.5 (Impacto de Co-docência no Desempenho):**  
* **Gráfico:** Gráfico de Barras Duplas com Barras de Erro (Dispersão).  
* **Justificativa:** A altura da barra compara a taxa média de aprovação entre turmas de docente único e turmas com co-docência, enquanto a barra de erro sobreposta indica a amplitude/dispersão das notas (diferença entre maiorNota e menorNota).  
  **Consulta 2.6 (Evolução da Demanda por Turno e Modalidade de Ensino):**  
* **Gráfico:** Gráfico de Área Empilhada.  
* **Justificativa:** O gráfico de área empilhada mostra a evolução do volume total de alunos matriculados ao longo dos semestres, evidenciando a mudança no ganho ou perda de participação entre o ensino presencial e a distância (modalidadeEnsino).  
  **Consulta 2.7 (Discrepância de Desempenho entre Períodos Horários):**  
* **Gráfico:** Gráfico de Colunas Lado a Lado.  
* **Justificativa:** O gráfico de colunas lado a lado compara diretamente a mediana de notas e as reprovações por falta para uma mesma disciplina lecionada em horários distintos (ex: matutino vs. noturno).

## **3\. Povoamento dos Esquemas com Dados Sintéticos (SQL)**

Abaixo estão os scripts em SQL ANSI compatíveis com PostgreSQL/MySQL para criação e povoamento sintético básico dos esquemas:

| \-- \======================================================== \-- 1\. CRIAÇÃO DAS TABELAS DIMENSÃO COMPARTILHADAS \-- \========================================================  CREATE TABLE Data (     id\_data INT PRIMARY KEY,     ano INT NOT NULL,     semestre INT NOT NULL,     anoSemestre VARCHAR(10) NOT NULL ); CREATE TABLE Curso (     id\_curso INT PRIMARY KEY,     nivelEnsino VARCHAR(50),     duracao INT,     cargaHorariaTotal INT,  \*ajustes para avaliar retênção de alunos     turno VARCHAR(20),     departamento VARCHAR(100),     centro VARCHAR(100),     campim VARCHAR(100),     modalidadeCurso VARCHAR(50),     modalidadeEnsino VARCHAR(50),     tempoMinimoConcluir INT,     tempoMaximoConcluir INT,     curriculo VARCHAR(50) ); CREATE TABLE Professor (     id\_professor INT PRIMARY KEY,     nome VARCHAR(100),     dataNascimento DATE,     genero VARCHAR(20),     bairroResidencia VARCHAR(100),     cpf VARCHAR(14),     nacionalidade VARCHAR(50),     naturalidade VARCHAR(50) ); CREATE TABLE Disciplina (     id\_disciplina INT PRIMARY KEY,     cargaHoraria INT,     creditos INT,     tipo VARCHAR(50) ); CREATE TABLE TurmaDisciplina (     id\_turmaDisciplina INT PRIMARY KEY,     id\_disciplina INT,     id\_professor1 INT,     id\_professor2 INT, \*ajustes para turmas de co\-docência     periodo VARCHAR(20),     horario VARCHAR(50),     FOREIGN KEY (id\_disciplina) REFERENCES Disciplina(id\_disciplina),     FOREIGN KEY (id\_professor1) REFERENCES Professor(id\_professor) ); CREATE TABLE TurmaAluno (     id\_turmaAluno INT PRIMARY KEY,     anoIngresso INT,     semestreIngresso INT,     anoSemestreIngresso VARCHAR(10),     semestreMinimoConclusao INT,     semestreMaximoConclusao INT ); CREATE TABLE Aluno (     id\_aluno INT PRIMARY KEY,     id\_curso INT,     faixaEconomica VARCHAR(20),     numeroMatricula VARCHAR(20),     escolaEnsinoMedio VARCHAR(50),     formaIngresso VARCHAR(50),     tipoCota VARCHAR(50),     meioIngresso VARCHAR(50),     anoEvasao INT,     semestreEvasao INT,     tipoEvasao VARCHAR(50),     assistenciaEstudantil BOOLEAN,     cargaHorariaIntegralizadaAtual INT,     nome VARCHAR(100),     dataNascimento DATE,     faixaEtaria VARCHAR(20),     genero VARCHAR(20),     raca\_etnia VARCHAR(50),     bairroResidencia VARCHAR(100),     cpf VARCHAR(14),     nacionalidade VARCHAR(50),     naturalidade VARCHAR(50),     nomeMae VARCHAR(100),     nomePai VARCHAR(100),     estadoCivil VARCHAR(20),     deficiencia VARCHAR(50),     anoConclusaoEnsinoMedio INT,     FOREIGN KEY (id\_curso) REFERENCES Curso(id\_curso) ); \-- \======================================================== \-- 2\. CRIAÇÃO DAS TABELAS FATO \-- \========================================================  \-- Fato 1: Rendimento Aluno CREATE TABLE FatoRendimentoAluno (     id\_fatoAluno INT PRIMARY KEY,     id\_aluno INT,     id\_turmaAluno INT,     id\_disciplina INT,     id\_turmaDisciplina INT,     id\_curso INT,     id\_data INT,     statusAluno VARCHAR(30),     qtdFaltas INT,     mediaNota DECIMAL(4,2),     periodoTrancado BOOLEAN,     FOREIGN KEY (id\_aluno) REFERENCES Aluno(id\_aluno),     FOREIGN KEY (id\_turmaAluno) REFERENCES TurmaAluno(id\_turmaAluno),     FOREIGN KEY (id\_disciplina) REFERENCES Disciplina(id\_disciplina),     FOREIGN KEY (id\_turmaDisciplina) REFERENCES TurmaDisciplina(id\_turmaDisciplina),     FOREIGN KEY (id\_curso) REFERENCES Curso(id\_curso),     FOREIGN KEY (id\_data) REFERENCES Data(id\_data) ); \-- Fato 2: Rendimento Disciplina CREATE TABLE FatoRendimentoDisciplina (     id\_fatoDisciplina INT PRIMARY KEY,     id\_disciplina INT,     id\_turmaDisciplina INT,     id\_curso INT,     id\_data INT,     qtdAprovacoesNota INT,     qtdReprovacoesNota INT,     qtdReprovacoesFalta INT,     menorNota DECIMAL(4,2),     maiorNota DECIMAL(4,2),     medianaNotas DECIMAL(4,2),     mediaNotas DECIMAL(4,2),     mediaFaltas DECIMAL(4,2),     qtdMatriculados INT,     qtdNotas0\_2,9 INT,     qtdNotas3\_6,9 INT,     qtdNotas7\_7,9 INT,     qtdNotas8\_8,9 INT,     qtdNotas9\_10 INT,     FOREIGN KEY (id\_disciplina) REFERENCES Disciplina(id\_disciplina),     FOREIGN KEY (id\_turmaDisciplina) REFERENCES TurmaDisciplina(id\_turmaDisciplina),     FOREIGN KEY (id\_curso) REFERENCES Curso(id\_curso),     FOREIGN KEY (id\_data) REFERENCES Data(id\_data) ); \-- \========================================================\-- 3\. POVOAMENTO COM DADOS SINTÉTICOS\-- \========================================================INSERT INTO Data VALUES (1, 2023, 1, '2023.1'),(2, 2023, 2, '2023.2');INSERT INTO Curso VALUES (1, 'Graduação', 8, 'Integral', 'Computação', 'CIn', 'Campus Recife', 'Presencial', 'Regular', 8, 14, '2020.1');INSERT INTO Professor VALUES (1, 'Carlos Silva', '1980-05-12', 'Masculino', 'Boa Viagem', '111.222.333-44', 'Brasileira', 'Recife');INSERT INTO Disciplina VALUES (101, 60, 4, 'Obrigatória');INSERT INTO TurmaDisciplina VALUES (501, 101, 1, '2023.1', '24M12');INSERT INTO TurmaAluno VALUES (20231, 2023, 1, '2023.1', 8, 14);INSERT INTO Aluno VALUES (1001, 1, 'Baixa', '20230001', 'Escola Pública', 'Sisu', 'L1', 'Enem', NULL, NULL, NULL, TRUE, 120, 'Maria Souza', '2002-03-15', '20-25', 'Feminino', 'Parda', 'Iputinga', '555.666.777-88', 'Brasileira', 'Recife', 'Ana Souza', 'José Souza', 'Solteiro', 'Nenhuma', 2022);\-- Inserção Fato Rendimento AlunoINSERT INTO FatoRendimentoAluno VALUES (1, 1001, 20231, 101, 501, 1, 1, 'Aprovado', 4, 8.50, FALSE);\-- Inserção Fato Rendimento DisciplinaINSERT INTO FatoRendimentoDisciplina VALUES (1, 101, 501, 1, 1, 35, 5, 2, 2.00, 10.00, 7.50, 7.20, 3.50, 42, 2, 5, 15, 12, 8); |
| :---- |

