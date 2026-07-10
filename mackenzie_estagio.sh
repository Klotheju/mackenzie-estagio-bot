#!/usr/bin/env bash
# =============================================================================
# mackenzie_estagio.sh
# Auto-applies to Estágios on carreiras.mackenzie.br.
# Notifies via desktop notification + log file.
# Session is kept alive by your browser's Tab Reloader extension.
#
# All state files are stored in the same directory as this script.
# Dependencies: curl, grep, sed, awk, sqlite3, notify-send (libnotify)
# =============================================================================

set -uo pipefail

# ─── PATHS ────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

COOKIE_FILE="${SCRIPT_DIR}/.mackenzie_cookies.txt"
APPLIED_LOG="${SCRIPT_DIR}/.mackenzie_applied.txt"
SESSION_LOG="${SCRIPT_DIR}/.mackenzie_session.log"
STATE_FILE="${SCRIPT_DIR}/.mackenzie_last_jobs.txt"
ENV_FILE="${SCRIPT_DIR}/.mackenzie_bot_env"

trap 'echo "[$(date "+%Y-%m-%d %H:%M:%S")] FATAL: aborted at line $LINENO (exit $?)" >> "${SESSION_LOG}"' ERR

# ─── LANGUAGE ─────────────────────────────────────────────────────────────────
LANG="${MACKENZIE_LANG:-pt}"

# ─── TRANSLATIONS ─────────────────────────────────────────────────────────────
msg() {
    local key="$1"
    case "$LANG" in
        en)
            case "$key" in
                bot_start)               echo "Mackenzie Estágio Bot starting" ;;
                session_ok)              echo "Session OK. Fetching job list..." ;;
                session_failed)          echo "Session check failed. Aborting run." ;;
                session_expired_log)     echo "SESSION EXPIRED: Login page detected." ;;
                session_expired_n_title) echo "⚠️ Mackenzie Bot: Session expired" ;;
                session_expired_n_body)  echo "Please log in at ${BASE_URL} in your browser. Tab Reloader will keep the session alive after that." ;;
                no_jobs)                 echo "No jobs found. Page structure may have changed or filters returned 0 results." ;;
                found_codes)             echo "Found job codes:" ;;
                already_applied)         echo "Already applied. Skipping." ;;
                applying)                echo "Applying to job" ;;
                apply_already)           echo "Already applied (detected from response). Marking as done." ;;
                apply_success)           echo "Successfully applied!" ;;
                apply_ambiguous)         echo "Response ambiguous — could not confirm. Flagging for manual check." ;;
                cookies_no_sqlite)       echo "WARNING: sqlite3 not found. Install it with your package manager." ;;
                cookies_use_existing)    echo "         Using existing cookie file if present." ;;
                cookies_not_found)       echo "WARNING: Could not find browser cookies.sqlite — will try without stored cookies." ;;
                cookies_extracted)       echo "Cookies extracted from browser profile:" ;;
                cookies_lines)           echo "lines" ;;
                notify_warn_fail)        echo "WARNING: notify-send failed — check .mackenzie_bot_env (Wayland/DBUS vars may be stale, re-run setup)" ;;
                notify_warn_missing)     echo "WARNING: notify-send not installed. Skipping desktop notification." ;;
                new_jobs_log)            echo "New jobs found and processed." ;;
                summary_label)           echo "Summary:" ;;
                notif_title)             echo "🎓 Mackenzie Bot: new listing(s)!" ;;
                notif_body_processed)    echo "new listing(s) applied to." ;;
                notif_body_flagged)      echo "need(s) manual review." ;;
                notif_body_log)          echo "Log:" ;;
                no_new_jobs)             echo "No new jobs found in this run." ;;
                run_complete)            echo "Run complete." ;;
                flagged_label)           echo "check manually" ;;
                no_title)                echo "untitled" ;;
            esac ;;
        pt|*)
            case "$key" in
                bot_start)               echo "Mackenzie Estágio Bot iniciando" ;;
                session_ok)              echo "Sessão OK. Buscando lista de vagas..." ;;
                session_failed)          echo "Verificação de sessão falhou. Abortando execução." ;;
                session_expired_log)     echo "SESSÃO EXPIRADA: Página de login detectada." ;;
                session_expired_n_title) echo "⚠️ Mackenzie Bot: Sessão expirada" ;;
                session_expired_n_body)  echo "Faça login em ${BASE_URL} no navegador. O Tab Reloader manterá a sessão ativa depois disso." ;;
                no_jobs)                 echo "Nenhuma vaga encontrada. A estrutura da página pode ter mudado ou os filtros retornaram 0 resultados." ;;
                found_codes)             echo "Códigos de vagas encontrados:" ;;
                already_applied)         echo "Já candidatado. Pulando." ;;
                applying)                echo "Candidatando-se à vaga" ;;
                apply_already)           echo "Já candidatado (detectado na resposta). Marcando como concluído." ;;
                apply_success)           echo "Candidatura enviada com sucesso!" ;;
                apply_ambiguous)         echo "Resposta ambígua — não foi possível confirmar. Sinalizando para verificação manual." ;;
                cookies_no_sqlite)       echo "AVISO: sqlite3 não encontrado. Instale com seu gerenciador de pacotes." ;;
                cookies_use_existing)    echo "       Usando arquivo de cookies existente, se houver." ;;
                cookies_not_found)       echo "AVISO: cookies.sqlite do navegador não encontrado — tentando sem cookies armazenados." ;;
                cookies_extracted)       echo "Cookies extraídos do perfil do navegador:" ;;
                cookies_lines)           echo "linhas" ;;
                notify_warn_fail)        echo "AVISO: notify-send falhou — verifique .mackenzie_bot_env (vars Wayland/DBUS podem estar desatualizadas, execute o setup novamente)" ;;
                notify_warn_missing)     echo "AVISO: notify-send não instalado. Pulando notificação." ;;
                new_jobs_log)            echo "Novas vagas encontradas e processadas." ;;
                summary_label)           echo "Resumo:" ;;
                notif_title)             echo "🎓 Mackenzie Bot: nova(s) vaga(s)!" ;;
                notif_body_processed)    echo "nova(s) vaga(s) candidatada(s)." ;;
                notif_body_flagged)      echo "precisa(m) de verificação manual." ;;
                notif_body_log)          echo "Log:" ;;
                no_new_jobs)             echo "Nenhuma vaga nova encontrada nesta execução." ;;
                run_complete)            echo "Execução concluída." ;;
                flagged_label)           echo "verificar manualmente" ;;
                no_title)                echo "sem-titulo" ;;
            esac ;;
    esac
}

# ─── CONFIGURATION ────────────────────────────────────────────────────────────
BASE_URL="https://carreiras.mackenzie.br"
SEARCH_URL="${BASE_URL}/Oportunidades"
TIPO_VAGA="estagio"
CIDADE_ID="3905"
CURSO_ID="1190"

# ─── HELPERS ──────────────────────────────────────────────────────────────────
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$SESSION_LOG"; }

# notify() — Wayland/Mako-aware notification sender.
# Mako on Hyprland/CachyOS needs WAYLAND_DISPLAY + XDG_RUNTIME_DIR exported
# correctly, which cron doesn't inherit. We source the env file first (already
# done by the cron line), then try notify-send. If it fails we log clearly so
# the user knows to re-run setup to refresh stale Wayland env vars.
notify() {
    local title="$1" body="$2" urgency="${3:-normal}"

    if ! command -v notify-send &>/dev/null; then
        log "$(msg notify_warn_missing)"
        return
    fi

    # Try sending — Mako needs no extra flags beyond what's in the env
    if notify-send \
        --urgency="$urgency" \
        --app-name="Mackenzie Bot" \
        --expire-time=10000 \
        "$title" "$body" 2>/dev/null; then
        return 0
    fi

    # First attempt failed — try forcing the Wayland socket path explicitly
    local uid
    uid=$(id -u)
    local wayland_sock="${XDG_RUNTIME_DIR:-/run/user/${uid}}/wayland-1"

    if WAYLAND_DISPLAY="$wayland_sock" \
       XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/${uid}}" \
       notify-send \
           --urgency="$urgency" \
           --app-name="Mackenzie Bot" \
           --expire-time=10000 \
           "$title" "$body" 2>/dev/null; then
        return 0
    fi

    # Both failed — log clearly and suggest fix
    log "$(msg notify_warn_fail)"
}

ensure_files() { touch "$APPLIED_LOG" "$SESSION_LOG" "$STATE_FILE"; }
is_applied()   { grep -qF "$1" "$APPLIED_LOG" 2>/dev/null; }
mark_applied() { echo "$1" >> "$APPLIED_LOG"; }

# ─── COOKIE EXTRACTION ────────────────────────────────────────────────────────
extract_cookies() {
    if ! command -v sqlite3 &>/dev/null; then
        log "$(msg cookies_no_sqlite)"
        log "$(msg cookies_use_existing)"
        return
    fi

    local search_paths=(
        # LibreWolf — standard + config-dir variant (CachyOS/Arch)
        "${HOME}/.librewolf"
        "${HOME}/.config/librewolf"
        # LibreWolf — Flatpak
        "${HOME}/.var/app/io.gitlab.librewolf-community/.librewolf"
        # LibreWolf — Snap
        "${HOME}/snap/librewolf/common/.librewolf"
        # Firefox — standard
        "${HOME}/.mozilla/firefox"
        "${HOME}/.config/firefox"
        # Firefox — Flatpak
        "${HOME}/.var/app/org.mozilla.firefox/.mozilla/firefox"
        # Firefox — Snap
        "${HOME}/snap/firefox/common/.mozilla/firefox"
        # Floorp
        "${HOME}/.floorp"
        "${HOME}/.var/app/one.ablaze.floorp/.floorp"
        # Waterfox
        "${HOME}/.waterfox"
        # GNU IceCat
        "${HOME}/.icecat"
        # Pale Moon
        "${HOME}/.moonchild productions/pale moon"
        # Zen Browser
        "${HOME}/.zen"
        "${HOME}/.var/app/io.github.zen_browser.zen/.zen"
    )

    local profile_db=""
    for base in "${search_paths[@]}"; do
        [[ -d "$base" ]] || continue
        local found
        found=$(find "$base" -maxdepth 4 -name "cookies.sqlite" 2>/dev/null | head -10)
        if [[ -n "$found" ]]; then
            profile_db=$(echo "$found" | while read -r f; do
                echo "$(stat -c '%Y' "$f" 2>/dev/null || echo 0) $f"
            done | sort -rn | head -1 | awk '{print $2}')
            break
        fi
    done

    if [[ -z "$profile_db" ]]; then
        log "$(msg cookies_not_found)"
        return 0
    fi

    local tmp_db
    tmp_db=$(mktemp /tmp/mackenzie_cookies_XXXXXX.sqlite)
    cp "$profile_db" "$tmp_db"

    {
        echo "# Netscape HTTP Cookie File"
        sqlite3 "$tmp_db" \
            "SELECT host,
                    CASE WHEN host GLOB '.*' THEN 'TRUE' ELSE 'FALSE' END,
                    path,
                    CASE WHEN isSecure THEN 'TRUE' ELSE 'FALSE' END,
                    expiry, name, value
             FROM moz_cookies
             WHERE host LIKE '%mackenzie%';" \
        | sed 's/|/\t/g'
    } > "$COOKIE_FILE"

    rm -f "$tmp_db"
    local lines
    lines=$(wc -l < "$COOKIE_FILE")
    log "$(msg cookies_extracted) ${lines} $(msg cookies_lines) [${profile_db}]"
}

# ─── SESSION CHECK ────────────────────────────────────────────────────────────
check_session() {
    local response
    response=$(curl --silent --location \
        --cookie "$COOKIE_FILE" \
        --cookie-jar "$COOKIE_FILE" \
        --user-agent "Mozilla/5.0 (X11; Linux x86_64; rv:120.0) Gecko/20100101 Firefox/120.0" \
        --max-time 30 \
        "${BASE_URL}/Oportunidades")

    if echo "$response" | grep -qi "login\|senha\|entrar\|sign.in\|password" && \
       ! echo "$response" | grep -qi "OPORTUNIDADES\|Estágio\|Buscar"; then
        log "$(msg session_expired_log)"
        notify "$(msg session_expired_n_title)" "$(msg session_expired_n_body)" "critical"
        return 1
    fi
    return 0
}

# ─── FETCH SEARCH HTML ────────────────────────────────────────────────────────
fetch_search_html() {
    curl --silent --location \
        --cookie "$COOKIE_FILE" \
        --cookie-jar "$COOKIE_FILE" \
        --user-agent "Mozilla/5.0 (X11; Linux x86_64; rv:120.0) Gecko/20100101 Firefox/120.0" \
        --header "Content-Type: application/x-www-form-urlencoded" \
        --header "Origin: ${BASE_URL}" \
        --header "Referer: ${SEARCH_URL}" \
        --data-urlencode "TipoVaga=${TIPO_VAGA}" \
        --data-urlencode "Filtro=" \
        --data-urlencode "CidadeId=${CIDADE_ID}" \
        --data-urlencode "CursoId=${CURSO_ID}" \
        --data-urlencode "CargoId=" \
        --max-time 30 \
        "${SEARCH_URL}"
}

parse_codes() {
    echo "$1" \
    | grep -oE 'Oportunidades/estagio/[0-9]+' \
    | grep -oE '[0-9]+$' \
    | sort -u
}

parse_title_for_code() {
    local html="$1"
    local code="$2"
    local title

    title=$(echo "$html" \
        | grep -oE '<a [^>]*estagio/'"${code}"'/[^>]*>[^<]+</a>' \
        | sed 's/<[^>]*>//g;s/^[[:space:]]*//;s/[[:space:]]*$//' \
        | head -1)

    if [[ -z "$title" ]]; then
        title=$(echo "$html" \
            | grep -A2 "estagio/${code}/" \
            | sed 's/<[^>]*>//g;/^[[:space:]]*$/d' \
            | head -1 \
            | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    fi

    title=$(echo "$title" | sed \
        's/&#225;/á/g;s/&#233;/é/g;s/&#237;/í/g;s/&#243;/ó/g;s/&#250;/ú/g;
         s/&#226;/â/g;s/&#234;/ê/g;s/&#244;/ô/g;
         s/&#227;/ã/g;s/&#245;/õ/g;
         s/&#231;/ç/g;
         s/&#193;/Á/g;s/&#201;/É/g;s/&#205;/Í/g;s/&#211;/Ó/g;s/&#218;/Ú/g;
         s/&#194;/Â/g;s/&#202;/Ê/g;s/&#212;/Ô/g;
         s/&#195;/Ã/g;s/&#213;/Õ/g;
         s/&#199;/Ç/g;s/&amp;/\&/g;s/&quot;/"/g')

    echo "${title:-$(msg no_title)}"
}

# ─── APPLY TO A JOB ───────────────────────────────────────────────────────────
apply_to_job() {
    local code="$1"
    local title="$2"
    local job_url="${BASE_URL}/Oportunidades/estagio/${code}/"
    local apply_url="${BASE_URL}/Oportunidades/Candidatar/${code}"

    log "$(msg applying) #${code}: ${title}"

    local response
    response=$(curl --silent --location \
        --cookie "$COOKIE_FILE" \
        --cookie-jar "$COOKIE_FILE" \
        --user-agent "Mozilla/5.0 (X11; Linux x86_64; rv:120.0) Gecko/20100101 Firefox/120.0" \
        --header "Referer: ${job_url}" \
        --max-time 30 \
        "${apply_url}")

    if echo "$response" | grep -qi "JÁ ESTA PARTICIPANDO\|já está participando"; then
        log "Job #${code}: $(msg apply_already)"
        mark_applied "$code"
        return 0
    fi

    if echo "$response" | grep -qi \
        "sucesso\|interesse registrado\|REGISTRAR INTERESSE\|candidatura\|obrigad\|estagio/${code}"; then
        log "Job #${code}: $(msg apply_success)"
        mark_applied "$code"
        return 0
    fi

    log "Job #${code}: $(msg apply_ambiguous)"
    mark_applied "$code"
    return 2
}

# ─── MAIN ─────────────────────────────────────────────────────────────────────
main() {
    log "==============================="
    log "$(msg bot_start)"
    log "==============================="

    ensure_files
    extract_cookies

    if ! check_session; then
        log "$(msg session_failed)"
        exit 1
    fi

    log "$(msg session_ok)"

    local search_html
    search_html=$(fetch_search_html)

    local current_jobs
    current_jobs=$(parse_codes "$search_html")

    if [[ -z "$current_jobs" ]]; then
        log "$(msg no_jobs)"
        exit 0
    fi

    log "$(msg found_codes) $(echo "$current_jobs" | tr '\n' ' ')"

    local new_count=0
    local flagged_count=0
    local summary_lines=""

    while IFS= read -r code; do
        [[ -z "$code" ]] && continue

        if is_applied "$code"; then
            log "Job #${code}: $(msg already_applied)"
            continue
        fi

        local is_new=false
        if ! grep -qF "$code" "$STATE_FILE" 2>/dev/null; then
            is_new=true
        fi

        local title
        title=$(parse_title_for_code "$search_html" "$code")
        local job_url="${BASE_URL}/Oportunidades/estagio/${code}/"

        local apply_result=0
        apply_to_job "$code" "$title" || apply_result=$?

        if $is_new; then
            new_count=$((new_count + 1))
            if [[ $apply_result -eq 2 ]]; then
                flagged_count=$((flagged_count + 1))
                summary_lines+="⚠ ${title} (#${code}) — $(msg flagged_label)\n   ${job_url}\n\n"
            else
                summary_lines+="✅ ${title} (#${code})\n   ${job_url}\n\n"
            fi
        fi

        sleep 2
    done <<< "$current_jobs"

    echo "$current_jobs" > "$STATE_FILE"

    if [[ $new_count -gt 0 ]]; then
        log "$(msg new_jobs_log) [new=${new_count}, flagged=${flagged_count}]"
        log "$(msg summary_label)"
        log "$(echo -e "$summary_lines")"

        local notif_body="${new_count} $(msg notif_body_processed)"
        [[ $flagged_count -gt 0 ]] && \
            notif_body+=" ${flagged_count} $(msg notif_body_flagged)"
        notif_body+=" $(msg notif_body_log) ${SESSION_LOG}"

        notify "$(msg notif_title)" "$notif_body" "normal"
    else
        log "$(msg no_new_jobs)"
    fi

    log "$(msg run_complete)"
    log ""
}

main "$@"
