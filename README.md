# IDW 2026.2 – Esquemas estrela de rendimento acadêmico

Banco PostgreSQL com os esquemas **FatoRendimentoAluno** e **FatoRendimentoDisciplina** (modelo do PDF
*Prototipação – Construção dos Esquemas Estrela*), dados sintéticos em português e Metabase local para os gráficos.
Tudo roda no seu computador com Docker.

## Como rodar

```bash
docker compose up -d
```

- PostgreSQL: `localhost:5433` (banco `idw`, usuário `idw`, senha `idw_local`)
- Metabase: http://localhost:3000

A primeira inicialização leva alguns minutos. O serviço `metabase-setup` espera o Metabase subir e configura tudo
sozinho: cria o admin de demonstração, conecta o banco `idw` e importa as 16 perguntas do documento
"Consultas em Linguagem Natural" e o dashboard, com filtros de disciplina, departamento, semestre e turno/modalidade.
Acompanhe com `docker compose logs -f metabase-setup`; ao final ele mostra o link do dashboard.

**Login do Metabase (somente demonstração, dados fictícios):**

| Campo | Valor |
|---|---|
| E-mail | `admin@example.com` |
| Senha | `Idw@Demo2026` |

Depois de entrar, abra **Our analytics → IDW – Rendimento Acadêmico**. Para trocar o login de demonstração,
altere `MB_ADMIN_EMAIL` e `MB_ADMIN_SENHA` no serviço `metabase-setup` antes da primeira subida.

Para recriar tudo do zero (os scripts só rodam com os volumes vazios):

```bash
docker compose down -v
docker compose up -d
```

Se a porta 3000 ou 5433 já estiver em uso, pare o outro serviço ou altere as portas no `docker-compose.yml`.

## Salvar os gráficos para enviar

- **Um gráfico:** abra a pergunta e use o ícone de download (canto inferior direito) para salvar em PNG.
- **Dashboard inteiro:** no menu **⋯** do dashboard, exporte em PDF.

## Conteúdo

- `db/01_schema.sql`: criação das tabelas (dimensões e fatos).
- `db/02_seed_pdf.sql`: registros de exemplo do PDF.
- `db/03_seed_extra_pt.sql`: povoamento adicional, determinístico e em português (7 cursos, 31 professores,
  21 disciplinas, 6 semestres, 5.001 alunos, ~110 mil registros de rendimento).
- `metabase/configurar.py`: configuração automática do Metabase (admin, banco, perguntas e dashboard).
- `consultas/consultas.sql`: as mesmas consultas em SQL puro, para usar fora do Metabase (gerado a partir de `metabase/configurar.py`).

## Observações sobre o esquema

- `qtdNotas0_2,9` (e as demais faixas) viraram `qtdNotas0_2_9`, porque a vírgula não é válida em identificador.
- O curso 1 do PDF foi ajustado para `modalidadeEnsino = 'Presencial'` (necessário para as consultas presencial × EAD).
- `Disciplina` não tem nome; nos gráficos as disciplinas aparecem como "Disc. 102" etc.
- `TurmaDisciplina` não tem `id_disciplina` (a disciplina da turma está nas tabelas fato) e tem `id_professor2` e
  `id_professor3` para co-docência: ~20% das turmas têm 2 professores e ~10% têm 3 (consulta 2.5).
- `Curso` não tem `cargaHorariaTotal`, então as consultas 1.5.2 (retidos) e 1.7 (integralização) ficam de fora.
- Todos os dados, inclusive CPFs, são fictícios.
