#!/bin/bash

set -u

if [[ "$(uname -s)" != "Darwin" ]]; then
    printf 'This cleaner is designed for macOS.\n' >&2
    exit 1
fi

if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    printf 'For safety, run this script as your normal user (without sudo).\n' >&2
    exit 1
fi

usage() {
    cat <<'EOF'
Usage: ./run.sh [--dry-run | --help]

  --dry-run  Show cache locations and estimated sizes without deleting anything.
  --help     Show this help.

Without options, choose cache locations interactively before cleaning.
EOF
}

DRY_RUN=0
case "${1:-}" in
    "")
        ;;
    --dry-run)
        DRY_RUN=1
        ;;
    --help|-h)
        usage
        exit 0
        ;;
    *)
        printf 'Unknown option: %s\n\n' "$1" >&2
        usage >&2
        exit 2
        ;;
esac

if [[ "$#" -gt 1 ]]; then
    printf 'Only one option may be provided.\n\n' >&2
    usage >&2
    exit 2
fi

if [[ "$DRY_RUN" -eq 0 && ! -t 0 ]]; then
    printf 'Interactive mode needs a terminal. Use --dry-run to preview safely.\n' >&2
    exit 2
fi

if [[ -z "${HOME:-}" || "$HOME" == "/" ]]; then
    printf 'Could not verify a safe home directory; refusing to continue.\n' >&2
    exit 1
fi

if [[ ! -d "$HOME" || -L "$HOME" ]]; then
    printf 'Home directory is missing or is a symbolic link; refusing to continue.\n' >&2
    exit 1
fi

if [[ -t 1 ]]; then
    RESET=$'\033[0m'
    BOLD=$'\033[1m'
    DIM=$'\033[2m'
    CYAN=$'\033[36m'
    GREEN=$'\033[32m'
    YELLOW=$'\033[33m'
    RED=$'\033[31m'
else
    RESET=''
    BOLD=''
    DIM=''
    CYAN=''
    GREEN=''
    YELLOW=''
    RED=''
fi

TARGETS=()
LABELS=()

add_target() {
    TARGETS[${#TARGETS[@]}]="$1"
    LABELS[${#LABELS[@]}]="$2"
}

add_target "$HOME/Library/Caches" "User application caches"
add_target "$HOME/Library/Developer/Xcode/DerivedData" "Xcode build data"
add_target "$HOME/Library/Developer/CoreSimulator/Caches" "iOS Simulator caches"
add_target "$HOME/Library/Application Support/Adobe/Common/Media Cache Files" "Adobe media cache files"
add_target "$HOME/Library/Application Support/Adobe/Common/Media Cache" "Adobe media cache"
add_target "$HOME/Library/Application Support/Adobe/Common/Peak Files" "Adobe audio peak files"
add_target "$HOME/Library/Application Support/Code/CachedExtensionVSIXs" "VS Code extension download cache"
add_target "$HOME/.npm/_cacache" "npm download cache"
add_target "$HOME/.gradle/caches" "Gradle dependency/build cache"
add_target "$HOME/.cache/pip" "pip package cache"
add_target "$HOME/.cache/uv" "uv package cache"
add_target "$HOME/.cache/go-build" "Go build cache"
add_target "$HOME/.cargo/registry/cache" "Cargo package archive cache"

add_browser_profile_targets() {
    local profiles_root="$1"
    local browser_label="$2"
    local profile

    for profile in "$profiles_root"/*; do
        [[ -d "$profile" && ! -L "$profile" ]] || continue
        add_target "$profile/Cache" "$browser_label cache ($(basename "$profile"))"
        add_target "$profile/Code Cache" "$browser_label code cache ($(basename "$profile"))"
        add_target "$profile/GPUCache" "$browser_label GPU cache ($(basename "$profile"))"
    done
}

add_browser_profile_targets "$HOME/Library/Application Support/Google/Chrome" "Chrome"
add_browser_profile_targets "$HOME/Library/Application Support/Chromium" "Chromium"
add_browser_profile_targets "$HOME/Library/Application Support/BraveSoftware/Brave-Browser" "Brave"
add_browser_profile_targets "$HOME/Library/Application Support/Microsoft Edge" "Edge"

add_firefox_targets() {
    local profiles_root="$HOME/Library/Application Support/Firefox/Profiles"
    local profile

    for profile in "$profiles_root"/*; do
        [[ -d "$profile" && ! -L "$profile" ]] || continue
        add_target "$profile/cache2" "Firefox cache ($(basename "$profile"))"
        add_target "$profile/startupCache" "Firefox startup cache ($(basename "$profile"))"
    done
}
add_firefox_targets

format_size() {
    awk -v kb="${1:-0}" 'BEGIN {
        if (kb >= 1048576) printf "%.2f GB", kb / 1048576
        else if (kb >= 1024) printf "%.0f MB", kb / 1024
        else printf "%.0f KB", kb
    }'
}

target_size_kb() {
    local target="$1"
    local size

    size=$(du -sk "$target" 2>/dev/null | awk 'NR == 1 { print $1 }')
    [[ "$size" =~ ^[0-9]+$ ]] || size=0
    printf '%s' "$size"
}

is_safe_target() {
    local target="$1"
    local current="$HOME"
    local relative
    local component
    local components

    [[ "$target" == "$HOME/"* ]] || return 1
    relative="${target#"$HOME"/}"
    IFS='/' read -r -a components <<< "$relative"
    for component in "${components[@]}"; do
        current="$current/$component"
        [[ ! -L "$current" ]] || return 1
    done

    [[ "$target" != "$HOME" && "$target" != "$HOME/" && -d "$target" ]]
}

printf '%s%s macOS CACHE CLEANER %s\n' "$BOLD" "$CYAN" "$RESET"
printf '%sPreview first. Choose only caches you want to rebuild or download again.%s\n\n' "$DIM" "$RESET"
printf '%sNote:%s Quit related apps first. Cache cleanup may sign you out of some sites or make the next launch slower.\n\n' "$YELLOW" "$RESET"

AVAILABLE=()
TOTAL_KB=0
for i in "${!TARGETS[@]}"; do
    if is_safe_target "${TARGETS[$i]}"; then
        size_kb=$(target_size_kb "${TARGETS[$i]}")
        AVAILABLE[${#AVAILABLE[@]}]="$i"
        TARGET_SIZE_KB[$i]="$size_kb"
        TOTAL_KB=$((TOTAL_KB + size_kb))
        printf '  %2d) %-43s %8s\n' \
            "$(( ${#AVAILABLE[@]} ))" \
            "${LABELS[$i]}" \
            "$(format_size "$size_kb")"
    fi
done

if [[ "${#AVAILABLE[@]}" -eq 0 ]]; then
    printf '%sNo supported cache locations were found.%s\n' "$DIM" "$RESET"
    exit 0
fi

printf '\nFound %d locations, approximately %s total.\n' \
    "${#AVAILABLE[@]}" "$(format_size "$TOTAL_KB")"

if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '%sDry run only:%s nothing was deleted.\n' "$GREEN" "$RESET"
    exit 0
fi

printf '\nEnter numbers separated by spaces or commas, "all", or "q" to quit: '
IFS= read -r selection
case "$selection" in
    q|Q|quit|QUIT)
        printf 'Cancelled; nothing was deleted.\n'
        exit 0
        ;;
    all|ALL)
        selection=''
        for ((i = 1; i <= ${#AVAILABLE[@]}; i++)); do
            selection+="$i "
        done
        ;;
esac

if [[ ! "$selection" =~ ^[0-9,\ ]+$ ]]; then
    printf '%sInvalid selection; nothing was deleted.%s\n' "$RED" "$RESET" >&2
    exit 2
fi

selection="${selection//,/ }"
CHOSEN=()
for item in $selection; do
    if (( item < 1 || item > ${#AVAILABLE[@]} )); then
        printf '%sSelection out of range; nothing was deleted.%s\n' "$RED" "$RESET" >&2
        exit 2
    fi
    CHOSEN[$((item - 1))]=1
done

if [[ "${#CHOSEN[@]}" -eq 0 ]]; then
    printf 'No locations selected; nothing was deleted.\n'
    exit 0
fi

SELECTED_KB=0
printf '\nSelected cache locations:\n'
for ((i = 0; i < ${#AVAILABLE[@]}; i++)); do
    [[ "${CHOSEN[$i]:-0}" -eq 1 ]] || continue
    target_index="${AVAILABLE[$i]}"
    SELECTED_KB=$((SELECTED_KB + TARGET_SIZE_KB[$target_index]))
    printf '  - %-43s %8s\n' \
        "${LABELS[$target_index]}" \
        "$(format_size "${TARGET_SIZE_KB[$target_index]}")"
done
printf 'Estimated selected total: %s\n' "$(format_size "$SELECTED_KB")"
printf 'Type CLEAN to confirm: '
IFS= read -r confirmation
if [[ "$confirmation" != "CLEAN" ]]; then
    printf 'Cancelled; nothing was deleted.\n'
    exit 0
fi

BEFORE_KB=$(df -Pk "$HOME" | awk 'NR == 2 { print $4 }')
FAILED=0
for ((i = 0; i < ${#AVAILABLE[@]}; i++)); do
    [[ "${CHOSEN[$i]:-0}" -eq 1 ]] || continue
    target_index="${AVAILABLE[$i]}"
    target="${TARGETS[$target_index]}"

    if ! is_safe_target "$target"; then
        printf '%sSkipped unsafe or missing location:%s %s\n' "$RED" "$RESET" "$target" >&2
        FAILED=1
        continue
    fi

    printf 'Cleaning %-43s ' "${LABELS[$target_index]}"
    if find "$target" -mindepth 1 -maxdepth 1 -exec rm -rf {} +; then
        printf '%sDone%s\n' "$GREEN" "$RESET"
    else
        printf '%sSome items could not be removed%s\n' "$YELLOW" "$RESET"
        FAILED=1
    fi
done

AFTER_KB=$(df -Pk "$HOME" | awk 'NR == 2 { print $4 }')
if [[ "$BEFORE_KB" =~ ^[0-9]+$ && "$AFTER_KB" =~ ^[0-9]+$ ]]; then
    RECOVERED_KB=$((AFTER_KB - BEFORE_KB))
    (( RECOVERED_KB < 0 )) && RECOVERED_KB=0
else
    RECOVERED_KB=0
fi

printf '\n%sCleanup finished.%s Approximate space recovered: %s\n' \
    "$BOLD" "$RESET" "$(format_size "$RECOVERED_KB")"
if [[ "$FAILED" -ne 0 ]]; then
    printf '%sSome items could not be removed. Check permissions and close related apps.%s\n' "$YELLOW" "$RESET"
    exit 1
fi
