# 🤖 Mackenzie Estágio Bot

🇧🇷 [Leia em Português](#-mackenzie-estágio-bot-pt-br)

---

Automatically applies to Computer Science internships (*Estágios em Ciência da Computação*) in São Paulo - SP on [carreiras.mackenzie.br](https://carreiras.mackenzie.br/Oportunidades), and sends a desktop notification when new listings are found.

## How it works

1. Every 30 minutes a cron job runs `mackenzie_estagio.sh`
2. The script reads your active browser session cookies directly from its SQLite database — supports LibreWolf, Firefox, Floorp, Waterfox, Zen Browser, and more
3. It POSTs to the Mackenzie job board with the correct filters — exactly replicating what the browser sends when you click *Buscar*
4. Job titles are extracted from the same search response — no extra requests needed
5. New jobs are applied to via a GET to `Candidatar/{code}` (site returns HTTP 302 on success)
6. A desktop notification pops up for each new listing applied to
7. Everything is logged to `.mackenzie_session.log` in the script's own directory

All state files (log, applied list, cookies, env) are saved **in the same directory as the scripts** — no files scattered in your home folder.

## Requirements

| Tool | Arch | Debian/Ubuntu | Fedora/RHEL |
|---|---|---|---|
| `curl` | `sudo pacman -S curl` | `sudo apt install curl` | `sudo dnf install curl` |
| `sqlite3` | `sudo pacman -S sqlite` | `sudo apt install sqlite3` | `sudo dnf install sqlite` |
| `notify-send` | `sudo pacman -S libnotify` | `sudo apt install libnotify-bin` | `sudo dnf install libnotify` |
| `crontab` | `sudo pacman -S cronie` | `sudo apt install cron` | `sudo dnf install cronie` |

- A **Firefox-based browser** (LibreWolf, Firefox, Floorp, Waterfox, Zen…) logged in to carreiras.mackenzie.br
- **Tab Reloader** extension set to reload the Mackenzie tab every 30 minutes

## Setup

```bash
git clone https://github.com/Klotheju/mackenzie-estagio-bot
cd mackenzie-estagio-bot
chmod +x setup_mackenzie_bot.sh mackenzie_estagio.sh
./setup_mackenzie_bot.sh
```

The setup script will:
- Ask you to choose a language (🇧🇷 PT-BR or 🇺🇸 EN)
- Check all dependencies with distro-specific install hints
- Detect your graphical session (DBUS/DISPLAY) so notifications work from cron
- Install the cron job (`*/30 * * * *`)
- Optionally run the bot immediately to test everything

## Language

Your choice is saved to `.mackenzie_bot_env` in the script directory and inherited by every cron run automatically. To switch, just run setup again:

```bash
./setup_mackenzie_bot.sh
```

To override for a single manual run:

```bash
MACKENZIE_LANG=en bash mackenzie_estagio.sh
```

## Files

All files live next to the scripts in the same directory:

```
mackenzie_estagio.sh         # Main bot script
setup_mackenzie_bot.sh       # One-time setup

.mackenzie_applied.txt       # Job codes already applied to (never double-applies)
.mackenzie_session.log       # Full run log
.mackenzie_last_jobs.txt     # Last seen job list (used to detect new listings)
.mackenzie_bot_env           # DBUS/DISPLAY/LANG env vars sourced by cron
.mackenzie_cookies.txt       # Exported browser session cookies
```

## Useful commands

```bash
# Watch live log output
tail -f /path/to/mackenzie-estagio-bot/.mackenzie_session.log

# See all jobs applied to so far
cat /path/to/mackenzie-estagio-bot/.mackenzie_applied.txt

# Run the bot manually right now
. /path/to/mackenzie-estagio-bot/.mackenzie_bot_env && \
  bash /path/to/mackenzie-estagio-bot/mackenzie_estagio.sh

# Test desktop notifications
notify-send 'Test' 'Hello from Mackenzie Bot'

# View the cron job
crontab -l

# Remove the cron job
crontab -e   # delete the mackenzie line
```

## Customizing your filters (city and course)

The default config searches for **Ciência da Computação** internships in **São Paulo - SP**. To search for a different city or course:

### Step 1 — Open DevTools and clear the Network log

Open [carreiras.mackenzie.br/Oportunidades](https://carreiras.mackenzie.br/Oportunidades) in your browser, press `F12`, go to the **Network** tab, and click the 🗑 trash icon to clear existing entries.

### Step 2 — Apply your desired filters and click Buscar

Use the dropdowns to select your **city** and **course**, click the job type button (e.g. *Estágio*), then click **BUSCAR**.

### Step 3 — Inspect the POST request

In the Network tab click `POST Oportunidades`, then click the **Request** tab in the right panel. You will see **Form data** like this:

```
TipoVaga: "estagio"
Filtro:   ""
CidadeId: "3905"
CursoId:  "1190"
CargoId:  ""
```

Note down your `CidadeId` and `CursoId` values.

### Step 4 — Update the script

Open `mackenzie_estagio.sh` and edit the two lines near the top:

```bash
CIDADE_ID="3905"   # ← replace with your CidadeId
CURSO_ID="1190"    # ← replace with your CursoId
```

> **Tip:** change `TIPO_VAGA` from `estagio` to `efetivo` or `trainee` to search for a different job type.

## Supported browsers

The bot automatically searches for cookies in the following locations (standard, Flatpak, and Snap):

| Browser | Paths searched |
|---|---|
| LibreWolf | `~/.librewolf`, `~/.config/librewolf`, Flatpak, Snap |
| Firefox | `~/.mozilla/firefox`, `~/.config/firefox`, Flatpak, Snap |
| Floorp | `~/.floorp`, Flatpak |
| Waterfox | `~/.waterfox` |
| Zen Browser | `~/.zen`, Flatpak |
| GNU IceCat | `~/.icecat` |
| Pale Moon | `~/.moonchild productions/pale moon` |

To add any other Firefox-based browser, add its profile path to the `search_paths` array in `extract_cookies()` inside `mackenzie_estagio.sh`.

## Uninstall

To fully remove the bot:

```bash
# 1. Remove the cron job
crontab -e
# Delete the line containing mackenzie_estagio.sh, save and exit

# 2. Delete all bot files (replace with your actual path)
rm -rf /path/to/mackenzie-estagio-bot

# 3. That's it — no files were written outside the script directory
```

To verify the cron job is gone:

```bash
crontab -l   # should show no mackenzie line
```

## Reinstall

```bash
# 1. Clone fresh copy
git clone https://github.com/Klotheju/mackenzie-estagio-bot
cd mackenzie-estagio-bot

# 2. Run setup (picks up your language preference again)
chmod +x setup_mackenzie_bot.sh mackenzie_estagio.sh
./setup_mackenzie_bot.sh
```

If you want to keep your applied jobs history from the old install, copy it over before reinstalling:

```bash
cp /old/path/.mackenzie_applied.txt /new/path/mackenzie-estagio-bot/
```

## Troubleshooting

**Bot starts but finds no jobs**
The form field names or IDs may have changed. Open DevTools → Network → click BUSCAR → POST request → Request tab → Form data, and update `CIDADE_ID` / `CURSO_ID` at the top of `mackenzie_estagio.sh`.

**Browser cookies not found**
The bot will log a warning and continue — if Tab Reloader kept your session alive, it will proceed without locally stored cookies. If you see session errors, make sure you're logged in to carreiras.mackenzie.br in your browser, then run the bot manually.

**Session keeps expiring**
Make sure Tab Reloader is active on the Mackenzie tab, set to ≤ 30 minutes. If the browser's Enhanced Tracking Protection is blocking the site, add an exception for `carreiras.mackenzie.br`.

**Desktop notifications not showing**
Run `./setup_mackenzie_bot.sh` again after logging in/out — the DBUS address can change between sessions, especially on Wayland.

**Titles show HTML entities (e.g. `&#225;`)**
Update to the latest version of `mackenzie_estagio.sh` — HTML entity decoding was added in a recent update.

## Notes

- The bot never applies to the same job twice — applied codes are persisted in `.mackenzie_applied.txt`
- Job titles are extracted from the search results page HTML — no extra per-job HTTP requests
- The POST filter IDs (`CidadeId=3905`, `CursoId=1190`) were captured from browser DevTools on 2026-06-30
- The `Candidatar/{code}` endpoint uses a plain GET + 302 redirect (confirmed from DevTools) — no CSRF token required

---

---

# 🤖 Mackenzie Estágio Bot (PT-BR)

🇺🇸 [Read in English](#-mackenzie-estágio-bot)

---

Candidata-se automaticamente a estágios em Ciência da Computação em São Paulo - SP no [carreiras.mackenzie.br](https://carreiras.mackenzie.br/Oportunidades) e envia notificações de área de trabalho quando novas vagas são encontradas.

## Como funciona

1. A cada 30 minutos, um cron job executa o `mackenzie_estagio.sh`
2. O script lê os cookies da sessão ativa do navegador diretamente do banco de dados SQLite — suporta LibreWolf, Firefox, Floorp, Waterfox, Zen Browser e outros
3. Faz um POST para o portal de vagas da Mackenzie com os filtros corretos — replicando exatamente o que o navegador envia ao clicar em *Buscar*
4. Os títulos das vagas são extraídos da mesma resposta da busca — sem requisições extras
5. Novas vagas são candidatadas via GET em `Candidatar/{código}` (o site retorna HTTP 302 em caso de sucesso)
6. Uma notificação de área de trabalho aparece para cada nova vaga candidatada
7. Tudo é registrado em `.mackenzie_session.log` no diretório do próprio script

Todos os arquivos de estado (log, lista de candidaturas, cookies, env) são salvos **no mesmo diretório dos scripts** — nenhum arquivo espalhado na sua pasta home.

## Requisitos

| Ferramenta | Arch | Debian/Ubuntu | Fedora/RHEL |
|---|---|---|---|
| `curl` | `sudo pacman -S curl` | `sudo apt install curl` | `sudo dnf install curl` |
| `sqlite3` | `sudo pacman -S sqlite` | `sudo apt install sqlite3` | `sudo dnf install sqlite` |
| `notify-send` | `sudo pacman -S libnotify` | `sudo apt install libnotify-bin` | `sudo dnf install libnotify` |
| `crontab` | `sudo pacman -S cronie` | `sudo apt install cron` | `sudo dnf install cronie` |

- Um **navegador baseado em Firefox** (LibreWolf, Firefox, Floorp, Waterfox, Zen…) com login em carreiras.mackenzie.br
- Extensão **Tab Reloader** configurada para recarregar a aba da Mackenzie a cada 30 minutos

## Instalação

```bash
git clone https://github.com/Klotheju/mackenzie-estagio-bot
cd mackenzie-estagio-bot
chmod +x setup_mackenzie_bot.sh mackenzie_estagio.sh
./setup_mackenzie_bot.sh
```

O script de setup vai:
- Perguntar o idioma (🇧🇷 PT-BR ou 🇺🇸 EN)
- Verificar todas as dependências com dicas de instalação por distro
- Detectar sua sessão gráfica (DBUS/DISPLAY) para que as notificações funcionem no cron
- Instalar o cron job (`*/30 * * * *`)
- Opcionalmente executar o bot imediatamente para testar tudo

## Idioma

A escolha é salva em `.mackenzie_bot_env` no diretório do script e herdada automaticamente por toda execução do cron. Para trocar, basta executar o setup novamente:

```bash
./setup_mackenzie_bot.sh
```

Para sobrescrever em uma execução manual:

```bash
MACKENZIE_LANG=pt bash mackenzie_estagio.sh
```

## Arquivos

Todos os arquivos ficam no mesmo diretório dos scripts:

```
mackenzie_estagio.sh         # Script principal do bot
setup_mackenzie_bot.sh       # Configuração inicial (executar uma vez)

.mackenzie_applied.txt       # Códigos de vagas já candidatadas (nunca candidata duas vezes)
.mackenzie_session.log       # Log completo de execução
.mackenzie_last_jobs.txt     # Última lista de vagas (para detectar novidades)
.mackenzie_bot_env           # Variáveis DBUS/DISPLAY/LANG para o cron
.mackenzie_cookies.txt       # Cache de cookies de sessão do navegador
```

## Comandos úteis

```bash
# Acompanhar o log em tempo real
tail -f /caminho/para/mackenzie-estagio-bot/.mackenzie_session.log

# Ver todas as vagas candidatadas até agora
cat /caminho/para/mackenzie-estagio-bot/.mackenzie_applied.txt

# Executar o bot manualmente agora
. /caminho/para/mackenzie-estagio-bot/.mackenzie_bot_env && \
  bash /caminho/para/mackenzie-estagio-bot/mackenzie_estagio.sh

# Testar notificações de área de trabalho
notify-send 'Teste' 'Olá do Mackenzie Bot'

# Ver o cron job instalado
crontab -l

# Remover o cron job
crontab -e   # delete a linha do mackenzie
```

## Personalizando os filtros (cidade e curso)

A configuração padrão busca estágios em **Ciência da Computação** em **São Paulo - SP**. Para buscar em outra cidade ou curso:

### Passo 1 — Abra o DevTools e limpe o log de rede

Abra [carreiras.mackenzie.br/Oportunidades](https://carreiras.mackenzie.br/Oportunidades) no seu navegador, pressione `F12`, vá para a aba **Network** e clique no ícone de 🗑 lixeira.

### Passo 2 — Aplique os filtros desejados e clique em Buscar

Use os menus suspensos para selecionar sua **cidade** e **curso**, clique no botão do tipo de vaga (ex: *Estágio*) e clique em **BUSCAR**.

### Passo 3 — Inspecione a requisição POST

Na aba Network clique em `POST Oportunidades`, depois na aba **Request** no painel à direita. Você verá **Form data** assim:

```
TipoVaga: "estagio"
Filtro:   ""
CidadeId: "3905"
CursoId:  "1190"
CargoId:  ""
```

Anote os valores de `CidadeId` e `CursoId`.

### Passo 4 — Atualize o script

Abra o `mackenzie_estagio.sh` e edite as duas linhas próximas ao topo:

```bash
CIDADE_ID="3905"   # ← substitua pelo seu CidadeId
CURSO_ID="1190"    # ← substitua pelo seu CursoId
```

> **Dica:** altere `TIPO_VAGA` de `estagio` para `efetivo` ou `trainee` para buscar outro tipo de vaga.

## Navegadores suportados

O bot busca cookies automaticamente nos seguintes locais (instalação padrão, Flatpak e Snap):

| Navegador | Caminhos buscados |
|---|---|
| LibreWolf | `~/.librewolf`, `~/.config/librewolf`, Flatpak, Snap |
| Firefox | `~/.mozilla/firefox`, `~/.config/firefox`, Flatpak, Snap |
| Floorp | `~/.floorp`, Flatpak |
| Waterfox | `~/.waterfox` |
| Zen Browser | `~/.zen`, Flatpak |
| GNU IceCat | `~/.icecat` |
| Pale Moon | `~/.moonchild productions/pale moon` |

Para adicionar outro navegador baseado em Firefox, adicione o caminho do perfil ao array `search_paths` na função `extract_cookies()` dentro de `mackenzie_estagio.sh`.

## Desinstalar

Para remover completamente o bot:

```bash
# 1. Remova o cron job
crontab -e
# Delete a linha que contém mackenzie_estagio.sh, salve e saia

# 2. Delete todos os arquivos do bot (substitua pelo seu caminho real)
rm -rf /caminho/para/mackenzie-estagio-bot

# 3. Pronto — nenhum arquivo foi criado fora do diretório dos scripts
```

Para confirmar que o cron job foi removido:

```bash
crontab -l   # não deve mostrar nenhuma linha do mackenzie
```

## Reinstalar

```bash
# 1. Clone uma cópia nova
git clone https://github.com/Klotheju/mackenzie-estagio-bot
cd mackenzie-estagio-bot

# 2. Execute o setup (escolha o idioma novamente)
chmod +x setup_mackenzie_bot.sh mackenzie_estagio.sh
./setup_mackenzie_bot.sh
```

Se quiser manter o histórico de vagas candidatadas da instalação anterior, copie o arquivo antes:

```bash
cp /caminho/antigo/.mackenzie_applied.txt /novo/caminho/mackenzie-estagio-bot/
```

## Solução de problemas

**O bot inicia mas não encontra vagas**
Os IDs do formulário podem ter mudado. Abra DevTools → Network → clique em BUSCAR → requisição POST → aba Request → Form data, e atualize `CIDADE_ID` / `CURSO_ID` no topo do `mackenzie_estagio.sh`.

**Cookies do navegador não encontrados**
O bot registra um aviso e continua — se o Tab Reloader manteve a sessão ativa, ele prossegue sem cookies locais. Se ver erros de sessão, certifique-se de que está logado em carreiras.mackenzie.br e execute o bot manualmente.

**A sessão continua expirando**
Certifique-se de que o Tab Reloader está ativo na aba da Mackenzie com intervalo ≤ 30 minutos. Se a Proteção Aprimorada do navegador estiver bloqueando o site, adicione uma exceção para `carreiras.mackenzie.br`.

**Notificações não aparecem**
Execute `./setup_mackenzie_bot.sh` novamente após fazer login/logout — o endereço DBUS pode mudar entre sessões, especialmente no Wayland.

**Títulos mostram entidades HTML (ex: `&#225;`)**
Atualize para a versão mais recente do `mackenzie_estagio.sh` — a decodificação de entidades HTML foi adicionada em uma atualização recente.

## Observações

- O bot nunca se candidata à mesma vaga duas vezes — os códigos ficam salvos em `.mackenzie_applied.txt`
- Os títulos das vagas são extraídos da página de resultados — sem requisições HTTP extras por vaga
- Os IDs de filtro do POST (`CidadeId=3905`, `CursoId=1190`) foram capturados do DevTools em 30/06/2026
- O endpoint `Candidatar/{código}` usa GET + redirect 302 (confirmado pelo DevTools) — nenhum token CSRF necessário
