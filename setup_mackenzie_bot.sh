#!/usr/bin/env bash
# =============================================================================
# setup_mackenzie_bot.sh
# One-time setup: checks dependencies, installs cron job, configures
# notify-send to work from cron (including Mako on Wayland/Hyprland).
# Run this ONCE before using mackenzie_estagio.sh
# All files are saved in the same directory as the scripts.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAIN_SCRIPT="${SCRIPT_DIR}/mackenzie_estagio.sh"

APPLIED_LOG="${SCRIPT_DIR}/.mackenzie_applied.txt"
SESSION_LOG="${SCRIPT_DIR}/.mackenzie_session.log"
STATE_FILE="${SCRIPT_DIR}/.mackenzie_last_jobs.txt"
ENV_FILE="${SCRIPT_DIR}/.mackenzie_bot_env"
COOKIE_FILE="${SCRIPT_DIR}/.mackenzie_cookies.txt"

BASE_URL="https://carreiras.mackenzie.br"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

header() { echo -e "\n${BLUE}══════════════════════════════════════${NC}"; echo -e "${BLUE}  $*${NC}"; echo -e "${BLUE}══════════════════════════════════════${NC}"; }
ok()     { echo -e "${GREEN}  ✔ $*${NC}"; }
warn()   { echo -e "${YELLOW}  ⚠ $*${NC}"; }
err()    { echo -e "${RED}  ✘ $*${NC}"; }

# ─── LANGUAGE SELECTION ───────────────────────────────────────────────────────
echo ""
echo -e "${BLUE}  🌐 Select language / Selecione o idioma:${NC}"
echo ""
echo "     1) 🇧🇷  Português (PT-BR)  [padrão / default]"
echo "     2) 🇺🇸  English (EN)"
echo ""
read -rp "  → Enter 1 or 2 / Digite 1 ou 2: " lang_choice

case "${lang_choice:-1}" in
    2) LANG="en" ;;
    *) LANG="pt" ;;
esac

echo ""
[[ "$LANG" == "en" ]] \
    && echo -e "${GREEN}  ✔ Language set to English${NC}" \
    || echo -e "${GREEN}  ✔ Idioma definido como Português${NC}"

# ─── TRANSLATIONS ─────────────────────────────────────────────────────────────
msg() {
    local key="$1"
    case "$LANG" in
        en)
            case "$key" in
                hdr_deps)          echo "Checking dependencies" ;;
                hdr_perms)         echo "Setting permissions" ;;
                hdr_files)         echo "Initializing state files" ;;
                hdr_notif)         echo "Configuring desktop notifications for cron" ;;
                hdr_cron)          echo "Installing cron job (every 30 minutes)" ;;
                hdr_browser)       echo "Browser session setup" ;;
                hdr_filters)       echo "Search filter info" ;;
                hdr_testrun)       echo "Optional test run" ;;
                hdr_done)          echo "Setup complete!" ;;
                dep_missing)       echo "Please install missing dependencies and re-run this setup." ;;
                perms_ok)          echo "Scripts are now executable" ;;
                files_created)     echo "Created:" ;;
                notif_wrote)       echo "Notification environment written to" ;;
                notif_wayland)     echo "Wayland session detected (Mako-compatible config written)" ;;
                notif_x11)         echo "X11 session detected" ;;
                notif_warn)        echo "If notifications stop working after a reboot/re-login, re-run this setup — Wayland socket values change between sessions." ;;
                notif_test_ok)     echo "Test notification sent successfully!" ;;
                notif_test_fail)   echo "Test notification failed — Wayland/DBUS env may be wrong. Try logging out and re-running setup." ;;
                cron_existing)     echo "Cron job already installed. Replacing with updated version." ;;
                cron_installed)    echo "Cron job installed:" ;;
                cron_running)      echo "Cron service is running" ;;
                cron_not_running)  echo "Cron service is NOT running. Attempting to start..." ;;
                cron_started)      echo "Cron service started" ;;
                cron_failed)       echo "Could not start cron. Run manually: sudo systemctl enable --now" ;;
                browser_intro)     echo "The bot reads cookies directly from your browser profile, so:" ;;
                browser_step1)     echo "1. Stay logged in to ${BASE_URL} in your Firefox-based browser" ;;
                browser_step2)     echo "2. Install/enable Tab Reloader on that tab, interval 30 min — keeps session alive automatically." ;;
                browser_step3)     echo "3. Bot auto-detects cookies from LibreWolf, Firefox, Floorp, Waterfox, Zen, and others (including Flatpak/Snap)." ;;
                browser_warn)      echo "Enhanced Tracking Protection may interfere with cookies. Add an exception for carreiras.mackenzie.br if you see session errors." ;;
                filter_intro)      echo "The bot POSTs to ${BASE_URL}/Oportunidades with these filters (from real browser DevTools):" ;;
                filter_tip)        echo "To change city or course: DevTools → Network → POST Oportunidades → Request tab → Form data. Then update CIDADE_ID / CURSO_ID at the top of:" ;;
                testrun_ask)       echo "Run the bot now to test everything? (y/N): " ;;
                testrun_ok)        echo "Test run completed! Check the log for details:" ;;
                testrun_warn)      echo "Test run finished with warnings. Check the log above." ;;
                testrun_skip)      echo "Skipping test run. Run manually at any time:" ;;
                summary_files)     echo "Files (all in ${SCRIPT_DIR}/):" ;;
                summary_script)    echo "Main script    :" ;;
                summary_env)       echo "Env file       :" ;;
                summary_applied)   echo "Applied log    :" ;;
                summary_session)   echo "Session log    :" ;;
                summary_state)     echo "State file     :" ;;
                summary_cookies)   echo "Cookie cache   :" ;;
                summary_cron)      echo "Cron: runs every 30 minutes." ;;
                summary_view)      echo "View:    crontab -l" ;;
                summary_remove)    echo "Remove:  crontab -e  (delete the mackenzie line)" ;;
                summary_cmds)      echo "Useful commands:" ;;
                cmd_log)           echo "Live log:      tail -f ${SESSION_LOG}" ;;
                cmd_applied)       echo "Applied jobs:  cat ${APPLIED_LOG}" ;;
                cmd_reset)         echo "Reset log:     > ${APPLIED_LOG}  ⚠ re-applies everything!" ;;
                cmd_run)           echo "Manual run:    . ${ENV_FILE} && bash ${MAIN_SCRIPT}" ;;
                cmd_notify)        echo "Test notify:   notify-send 'Test' 'Hello from Mackenzie Bot'" ;;
                ready)             echo "Bot is ready. Checks every 30 min, notifies + auto-applies for new estágios." ;;
            esac ;;
        pt|*)
            case "$key" in
                hdr_deps)          echo "Verificando dependências" ;;
                hdr_perms)         echo "Configurando permissões" ;;
                hdr_files)         echo "Inicializando arquivos de estado" ;;
                hdr_notif)         echo "Configurando notificações para o cron" ;;
                hdr_cron)          echo "Instalando cron job (a cada 30 minutos)" ;;
                hdr_browser)       echo "Configuração de sessão do navegador" ;;
                hdr_filters)       echo "Informações sobre os filtros de busca" ;;
                hdr_testrun)       echo "Execução de teste (opcional)" ;;
                hdr_done)          echo "Configuração concluída!" ;;
                dep_missing)       echo "Instale as dependências faltando e execute o setup novamente." ;;
                perms_ok)          echo "Scripts estão executáveis" ;;
                files_created)     echo "Criado:" ;;
                notif_wrote)       echo "Ambiente de notificação salvo em" ;;
                notif_wayland)     echo "Sessão Wayland detectada (configuração compatível com Mako gerada)" ;;
                notif_x11)         echo "Sessão X11 detectada" ;;
                notif_warn)        echo "Se as notificações pararem de funcionar após reinicialização/re-login, execute o setup novamente — os valores do socket Wayland mudam entre sessões." ;;
                notif_test_ok)     echo "Notificação de teste enviada com sucesso!" ;;
                notif_test_fail)   echo "Notificação de teste falhou — o ambiente Wayland/DBUS pode estar errado. Tente fazer logout e executar o setup novamente." ;;
                cron_existing)     echo "Cron job já instalado. Substituindo pela versão atualizada." ;;
                cron_installed)    echo "Cron job instalado:" ;;
                cron_running)      echo "Serviço cron está ativo" ;;
                cron_not_running)  echo "Serviço cron NÃO está ativo. Tentando iniciar..." ;;
                cron_started)      echo "Serviço cron iniciado" ;;
                cron_failed)       echo "Não foi possível iniciar o cron. Execute: sudo systemctl enable --now" ;;
                browser_intro)     echo "O bot lê os cookies diretamente do seu perfil do navegador, então:" ;;
                browser_step1)     echo "1. Mantenha o login em ${BASE_URL} no seu navegador baseado em Firefox" ;;
                browser_step2)     echo "2. Instale/ative o Tab Reloader nessa aba com intervalo de 30 min — mantém a sessão ativa automaticamente." ;;
                browser_step3)     echo "3. O bot detecta cookies do LibreWolf, Firefox, Floorp, Waterfox, Zen e outros (incluindo Flatpak/Snap)." ;;
                browser_warn)      echo "A Proteção Aprimorada contra Rastreamento pode interferir nos cookies. Adicione uma exceção para carreiras.mackenzie.br caso veja erros de sessão." ;;
                filter_intro)      echo "O bot faz POST para ${BASE_URL}/Oportunidades com estes filtros (capturados do DevTools):" ;;
                filter_tip)        echo "Para alterar cidade ou curso: DevTools → Network → POST Oportunidades → aba Request → Form data. Depois atualize CIDADE_ID / CURSO_ID no topo do arquivo:" ;;
                testrun_ask)       echo "Executar o bot agora para testar tudo? (y/N): " ;;
                testrun_ok)        echo "Teste concluído! Verifique o log para detalhes:" ;;
                testrun_warn)      echo "Teste concluído com avisos. Verifique o log acima." ;;
                testrun_skip)      echo "Pulando o teste. Execute manualmente a qualquer momento:" ;;
                summary_files)     echo "Arquivos (todos em ${SCRIPT_DIR}/):" ;;
                summary_script)    echo "Script principal :" ;;
                summary_env)       echo "Arquivo de env   :" ;;
                summary_applied)   echo "Log de aplicações:" ;;
                summary_session)   echo "Log de sessão    :" ;;
                summary_state)     echo "Arquivo de estado:" ;;
                summary_cookies)   echo "Cache de cookies :" ;;
                summary_cron)      echo "Cron: executa a cada 30 minutos." ;;
                summary_view)      echo "Ver:     crontab -l" ;;
                summary_remove)    echo "Remover: crontab -e  (delete a linha do mackenzie)" ;;
                summary_cmds)      echo "Comandos úteis:" ;;
                cmd_log)           echo "Log em tempo real:    tail -f ${SESSION_LOG}" ;;
                cmd_applied)       echo "Vagas candidatadas:   cat ${APPLIED_LOG}" ;;
                cmd_reset)         echo "Resetar aplicações:   > ${APPLIED_LOG}  ⚠ vai recandidatar tudo!" ;;
                cmd_run)           echo "Executar manualmente: . ${ENV_FILE} && bash ${MAIN_SCRIPT}" ;;
                cmd_notify)        echo "Testar notificação:   notify-send 'Teste' 'Olá do Mackenzie Bot'" ;;
                ready)             echo "Bot pronto. Verifica a cada 30 min, notifica + candidata automaticamente em novas vagas." ;;
            esac ;;
    esac
}

# ─── DEPENDENCY CHECK ─────────────────────────────────────────────────────────
header "$(msg hdr_deps)"

MISSING_DEPS=false
check_dep() {
    if command -v "$1" &>/dev/null; then
        ok "$1 → $(command -v "$1")"
    else
        err "$1 → $2"
        MISSING_DEPS=true
    fi
}

check_dep curl        "sudo pacman -S curl  /  sudo apt install curl  /  sudo dnf install curl"
check_dep sqlite3     "sudo pacman -S sqlite  /  sudo apt install sqlite3  /  sudo dnf install sqlite"
check_dep notify-send "sudo pacman -S libnotify  /  sudo apt install libnotify-bin  /  sudo dnf install libnotify"
check_dep grep        "(pre-installed on all distros)"
check_dep sed         "(pre-installed on all distros)"
check_dep awk         "(pre-installed on all distros)"
check_dep crontab     "sudo pacman -S cronie  /  sudo apt install cron  /  sudo dnf install cronie"

if $MISSING_DEPS; then
    err "$(msg dep_missing)"
    exit 1
fi

# ─── MAKE SCRIPTS EXECUTABLE ──────────────────────────────────────────────────
header "$(msg hdr_perms)"
chmod +x "$MAIN_SCRIPT"
chmod +x "${SCRIPT_DIR}/setup_mackenzie_bot.sh"
ok "$(msg perms_ok)"

# ─── INITIALIZE STATE FILES ───────────────────────────────────────────────────
header "$(msg hdr_files)"
touch "$APPLIED_LOG" "$SESSION_LOG" "$STATE_FILE" "$COOKIE_FILE"
ok "$(msg files_created) $APPLIED_LOG"
ok "$(msg files_created) $SESSION_LOG"
ok "$(msg files_created) $STATE_FILE"
ok "$(msg files_created) $COOKIE_FILE"

# ─── NOTIFICATION ENVIRONMENT ─────────────────────────────────────────────────
# Mako (Wayland) needs WAYLAND_DISPLAY + XDG_RUNTIME_DIR.
# X11 needs DISPLAY + XAUTHORITY + DBUS_SESSION_BUS_ADDRESS.
# We capture ALL of them from the current live session so cron has everything.
header "$(msg hdr_notif)"

CURRENT_UID="$(id -u)"
XDG_RT="${XDG_RUNTIME_DIR:-/run/user/${CURRENT_UID}}"

# Detect Wayland display — try env var first, then probe the runtime dir
if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
    DETECTED_WAYLAND="${WAYLAND_DISPLAY}"
elif [[ -S "${XDG_RT}/wayland-1" ]]; then
    DETECTED_WAYLAND="wayland-1"
elif [[ -S "${XDG_RT}/wayland-0" ]]; then
    DETECTED_WAYLAND="wayland-0"
else
    DETECTED_WAYLAND=""
fi

DETECTED_DISPLAY="${DISPLAY:-:0}"
DETECTED_DBUS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=${XDG_RT}/bus}"
DETECTED_XAUTHORITY="${XAUTHORITY:-${HOME}/.Xauthority}"

cat > "$ENV_FILE" <<EOF
# Auto-generated by setup_mackenzie_bot.sh — re-run setup after reboot/re-login
# to refresh Wayland socket values.
export XDG_RUNTIME_DIR="${XDG_RT}"
export WAYLAND_DISPLAY="${DETECTED_WAYLAND}"
export DISPLAY="${DETECTED_DISPLAY}"
export DBUS_SESSION_BUS_ADDRESS="${DETECTED_DBUS}"
export XAUTHORITY="${DETECTED_XAUTHORITY}"
export MACKENZIE_LANG="${LANG}"
EOF

ok "$(msg notif_wrote) ${ENV_FILE}"
if [[ -n "$DETECTED_WAYLAND" ]]; then
    ok "$(msg notif_wayland)"
    echo "      XDG_RUNTIME_DIR=${XDG_RT}"
    echo "      WAYLAND_DISPLAY=${DETECTED_WAYLAND}"
else
    ok "$(msg notif_x11)"
    echo "      DISPLAY=${DETECTED_DISPLAY}"
fi
echo "      DBUS_SESSION_BUS_ADDRESS=${DETECTED_DBUS}"
echo "      MACKENZIE_LANG=${LANG}"

# Send a test notification right now to confirm it works
echo ""
. "$ENV_FILE"
if notify-send --app-name="Mackenzie Bot" --expire-time=5000 \
    "🎓 Mackenzie Bot" "Setup complete — notifications are working!" 2>/dev/null; then
    ok "$(msg notif_test_ok)"
else
    warn "$(msg notif_test_fail)"
fi

warn "$(msg notif_warn)"

# ─── INSTALL CRON JOB ─────────────────────────────────────────────────────────
header "$(msg hdr_cron)"

CRON_LINE="*/30 * * * * . ${ENV_FILE} && ${MAIN_SCRIPT} >> ${SESSION_LOG} 2>&1"

if crontab -l 2>/dev/null | grep -qF "$MAIN_SCRIPT"; then
    warn "$(msg cron_existing)"
    ( crontab -l 2>/dev/null | grep -vF "$MAIN_SCRIPT" ; echo "$CRON_LINE" ) | crontab -
else
    ( crontab -l 2>/dev/null || true ; echo "$CRON_LINE" ) | crontab -
fi
ok "$(msg cron_installed)"
echo "      ${CRON_LINE}"

if command -v systemctl &>/dev/null; then
    for svc in cron cronie crond fcron; do
        if systemctl list-unit-files 2>/dev/null | grep -q "^${svc}\.service"; then
            if systemctl is-active --quiet "$svc"; then
                ok "$(msg cron_running) (${svc})"
            else
                warn "$(msg cron_not_running) (${svc})"
                sudo systemctl enable --now "$svc" \
                    && ok "$(msg cron_started)" \
                    || warn "$(msg cron_failed) ${svc}"
            fi
            break
        fi
    done
fi

# ─── BROWSER SESSION NOTE ─────────────────────────────────────────────────────
header "$(msg hdr_browser)"
echo ""
echo "  $(msg browser_intro)"
echo ""
echo "    $(msg browser_step1)"
echo "    $(msg browser_step2)"
echo "    $(msg browser_step3)"
echo ""
warn "$(msg browser_warn)"

# ─── SEARCH FILTER INFO ───────────────────────────────────────────────────────
header "$(msg hdr_filters)"
echo ""
echo "  $(msg filter_intro)"
echo ""
echo "    TipoVaga : estagio"
echo "    CidadeId : 3905   (São Paulo - SP)"
echo "    CursoId  : 1190   (Ciência da Computação)"
echo ""
echo "  $(msg filter_tip)"
echo "    ${MAIN_SCRIPT}"

# ─── TEST RUN ─────────────────────────────────────────────────────────────────
header "$(msg hdr_testrun)"
read -rp "  → $(msg testrun_ask)" run_now
echo ""

if [[ "${run_now,,}" == "y" ]]; then
    bash "$MAIN_SCRIPT" \
        && { ok "$(msg testrun_ok)"; echo "      ${SESSION_LOG}"; } \
        || warn "$(msg testrun_warn)"
else
    ok "$(msg testrun_skip)"
    echo "     . ${ENV_FILE} && bash ${MAIN_SCRIPT}"
fi

# ─── SUMMARY ──────────────────────────────────────────────────────────────────
header "$(msg hdr_done)"
echo ""
echo "  $(msg summary_files)"
echo "    $(msg summary_script) ${MAIN_SCRIPT}"
echo "    $(msg summary_env) ${ENV_FILE}"
echo "    $(msg summary_applied) ${APPLIED_LOG}"
echo "    $(msg summary_session) ${SESSION_LOG}"
echo "    $(msg summary_state) ${STATE_FILE}"
echo "    $(msg summary_cookies) ${COOKIE_FILE}"
echo ""
echo "  $(msg summary_cron)"
echo "    $(msg summary_view)"
echo "    $(msg summary_remove)"
echo ""
echo "  $(msg summary_cmds)"
echo "    $(msg cmd_log)"
echo "    $(msg cmd_applied)"
echo "    $(msg cmd_reset)"
echo "    $(msg cmd_run)"
echo "    $(msg cmd_notify)"
echo ""
ok "$(msg ready)"
