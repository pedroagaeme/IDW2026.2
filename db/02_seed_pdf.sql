-- Povoamento básico, exatamente como no PDF (um registro por tabela).
INSERT INTO Data VALUES (1, 2023, 1, '2023.1'), (2, 2023, 2, '2023.2');

INSERT INTO Curso VALUES (1, 'Graduação', 8, 'Integral', 'Computação', 'CIn', 'Campus Recife', 'Presencial', 'Regular', 8, 14, '2020.1');

INSERT INTO Professor VALUES (1, 'Carlos Silva', '1980-05-12', 'Masculino', 'Boa Viagem', '111.222.333-44', 'Brasileira', 'Recife');

INSERT INTO Disciplina VALUES (101, 60, 4, 'Obrigatória');

INSERT INTO TurmaDisciplina VALUES (501, 101, 1, '2023.1', '24M12');

INSERT INTO TurmaAluno VALUES (20231, 2023, 1, '2023.1', 8, 14);

INSERT INTO Aluno VALUES (1001, 1, 'Baixa', '20230001', 'Escola Pública', 'Sisu', 'L1', 'Enem', NULL, NULL, NULL, TRUE, 120, 'Maria Souza', '2002-03-15', '20-25', 'Feminino', 'Parda', 'Iputinga', '555.666.777-88', 'Brasileira', 'Recife', 'Ana Souza', 'José Souza', 'Solteiro', 'Nenhuma', 2022);

INSERT INTO FatoRendimentoAluno VALUES (1, 1001, 20231, 101, 501, 1, 1, 'Aprovado', 4, 8.50, FALSE);

INSERT INTO FatoRendimentoDisciplina VALUES (1, 101, 501, 1, 1, 35, 5, 2, 2.00, 10.00, 7.50, 7.20, 3.50, 42, 2, 5, 15, 12, 8);
