# IDW 2026.2 – Esquemas estrela de rendimento acadêmico

Banco PostgreSQL com os esquemas **FatoRendimentoAluno** e **FatoRendimentoDisciplina** (modelo do PDF
*Prototipação – Construção dos Esquemas Estrela*), dados sintéticos em português e Metabase local para os gráficos.
Tudo roda no seu computador com Docker.

## Como rodar

```bash
docker compose up -d
```

- PostgreSQL: `localhost:5433` (banco `idw`, usuário `idw`, senha `idw_local`)
- Metabase: http://localhost:3000 (a primeira inicialização leva alguns minutos)

Para recriar o banco do zero (os scripts só rodam com o volume vazio):

```bash
docker compose down -v
docker compose up -d
```

## Conectar o banco no Metabase

Na configuração inicial, ou em *Admin → Databases → Add database*, escolha **PostgreSQL**:

| Campo | Valor |
|---|---|
| Host | `idw-postgres` |
| Porta | `5432` |
| Banco | `idw` |
| Usuário | `idw` |
| Senha | `idw_local` |

## Conteúdo

- `db/01_schema.sql`: criação das tabelas (dimensões e fatos).
- `db/02_seed_pdf.sql`: registros de exemplo do PDF.
- `db/03_seed_extra_pt.sql`: povoamento adicional, determinístico e em português (7 cursos, 11 professores,
  8 disciplinas, 6 semestres, 201 alunos, ~2.900 registros de rendimento).
- `consultas/consultas.sql`: consultas do PDF, prontas para colar como perguntas SQL no Metabase.

## Observações sobre o esquema

- `qtdNotas0_2,9` (e as demais faixas) viraram `qtdNotas0_2_9`, porque a vírgula não é válida em identificador.
- O curso 1 do PDF foi ajustado para `modalidadeEnsino = 'Presencial'` (necessário para as consultas presencial × EAD).
- `Disciplina` não tem nome, e `TurmaDisciplina` só tem `id_professor1`; por isso a consulta de co-docência
  (2.5 do PDF) não é respondível com este esquema.
- Todos os dados, inclusive CPFs, são fictícios.
