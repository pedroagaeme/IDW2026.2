# IDW 2026.2 – Esquemas estrela de rendimento acadêmico

Banco PostgreSQL com os esquemas **FatoRendimentoAluno** e **FatoRendimentoDisciplina** (modelo do PDF
*Prototipação – Construção dos Esquemas Estrela*), dados sintéticos em português e Metabase local para os gráficos.
Tudo roda no seu computador com Docker.

## Como rodar

```bash
docker compose up -d
```

- PostgreSQL: `localhost:5434` (banco `idw`, usuário `idw`, senha `idw_local`)
- Metabase: http://localhost:3000

A primeira inicialização leva alguns minutos. O serviço `metabase-setup` espera o Metabase subir e configura tudo
sozinho: cria o admin de demonstração, conecta o banco `idw` e importa as 18 perguntas do documento
"Consultas em Linguagem Natural" (todas as consultas) e o dashboard, em duas abas (uma por esquema).

**Filtros do dashboard** (vários valores por filtro; as opções vêm do próprio banco; cada aba mostra só os que
valem para os seus gráficos):

- Recorte institucional: semestre, centro, campus, curso/departamento (opções limitadas pelo centro e campus
  escolhidos), turno do curso, modalidade de ensino e grau.
- Disciplina: tipo (obrigatória/optativa/eletiva) e códigos das disciplinas.
- Perfil do aluno (aba do Esquema 1): coorte de ingresso, forma de ingresso, tipo de cota, faixa econômica,
  escola do ensino médio, gênero, raça/etnia, faixa etária e deficiência.
- Específicos: "Disciplina em foco" (dispersão nota × frequência e comparação de professores) e
  "Separar evolução por" (turno ou modalidade nas séries temporais).
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

Se a porta 3000 ou 5434 já estiver em uso, pare o outro serviço ou altere as portas no `docker-compose.yml`.

## Salvar os gráficos para enviar

- **Um gráfico:** abra a pergunta e use o ícone de download (canto inferior direito) para salvar em PNG.
- **Dashboard inteiro:** no menu **⋯** do dashboard, exporte em PDF.

## Conteúdo

- `db/01_schema.sql`: criação das tabelas (dimensões e fatos).
- `db/02_seed_pdf.sql`: registros de exemplo do PDF.
- `db/03_seed_extra_pt.sql`: povoamento adicional, determinístico e em português (7 cursos, 31 professores,
  21 disciplinas, 6 semestres, 5.001 alunos de 12 coortes (2019.1 a 2024.2), ~110 mil registros de rendimento).
- `metabase/configurar.py`: configuração automática do Metabase (admin, banco, perguntas e dashboard).
- `consultas/consultas.sql`: as mesmas consultas em SQL puro, para usar fora do Metabase (gerado com `python metabase/configurar.py --sql > consultas/consultas.sql`; não edite à mão).

## Observações sobre o esquema

- `qtdNotas0_2,9` (e as demais faixas) viraram `qtdNotas0_2_9`, porque a vírgula não é válida em identificador.
- O curso 1 do PDF foi ajustado para `modalidadeEnsino = 'Presencial'` (necessário para as consultas presencial × EAD).
- `Disciplina` não tem nome; nos gráficos as disciplinas aparecem como "Disc. 102" etc.
- `TurmaDisciplina` não tem `id_disciplina` (a disciplina da turma está nas tabelas fato) e tem `id_professor2` e
  `id_professor3` para co-docência: ~20% das turmas têm 2 professores e ~10% têm 3 (consulta 2.5).
- `Curso.cargaHorariaTotal` não está no diagrama do PDF: vem do SQL do documento de consultas ("ajustes para
  avaliar retenção de alunos") e é usada nas consultas 1.5.2 (retidos) e 1.7 (integralização).
- Todos os dados, inclusive CPFs, são fictícios.
