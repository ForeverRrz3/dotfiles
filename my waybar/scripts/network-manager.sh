#!/usr/bin/env bash

SESSION_TYPE="$XDG_SESSION_TYPE"
ENABLED_COLOR="#929292"
DISABLED_COLOR="#D35F5E"
SIGNAL_ICONS=("󰤟 " "󰤢 " "󰤥 " "󰤨 ")
SECURED_SIGNAL_ICONS=("󰤡 " "󰤤 " "󰤧 " "󰤪 ")
WIFI_CONNECTED_ICON=" "
ETHERNET_CONNECTED_ICON=" "

# Определяем имена интерфейсов
WIFI_DEV=$(nmcli -t -f DEVICE,TYPE device status | awk -F: '$2=="wifi"{print $1; exit}')
ETH_DEVS=($(nmcli -t -f DEVICE,TYPE device status | awk -F: '$2=="ethernet"{print $1}'))

get_status() {
    # Проверяем Ethernet
    if nmcli -t -f TYPE,STATE device status | grep 'ethernet:connected' > /dev/null; then
        status_icon="󰈀"
        status_color=$ENABLED_COLOR

    # Проверяем Wi-Fi
    elif nmcli -t -f TYPE,STATE device status | grep 'wifi:connected' > /dev/null; then
        local wifi_info
        wifi_info=$(nmcli -t -f IN-USE,SIGNAL,SECURITY,SSID device wifi list --rescan no | grep '^\*')
        if [[ -n "$wifi_info" ]]; then
            IFS=: read -r in_use signal security ssid <<< "$wifi_info"
            signal_level=$((signal/25))
            [[ $signal_level -ge ${#SIGNAL_ICONS[@]} ]] && signal_level=$((${#SIGNAL_ICONS[@]}-1))
            signal_icon=${SIGNAL_ICONS[$signal_level]}
            [[ "$security" =~ WPA|WEP ]] && signal_icon=${SECURED_SIGNAL_ICONS[$signal_level]}
            status_icon=$signal_icon
            status_color=$ENABLED_COLOR
        else
            status_icon=" "
            status_color=$DISABLED_COLOR
        fi

    # Ни то ни другое
    else
        status_icon=" "
        status_color=$DISABLED_COLOR
    fi

    if [[ "$SESSION_TYPE" == "wayland" ]]; then
        printf '<span color="%s">%s</span>' "$status_color" "$status_icon"
    else
        printf '%%{F%s}%s%%{F-}' "$status_color" "$status_icon"
    fi
}

manage_wifi() {
    # Проверяем, включён ли Wi-Fi
    if [[ "$(nmcli radio wifi)" != "enabled" ]]; then
        notify-send "Wi-Fi отключён" "Сначала включите Wi-Fi."
        return
    fi

    # Собираем список сетей
    mapfile -t lines < <(nmcli --terse --fields IN-USE,SIGNAL,SECURITY,SSID device wifi list --rescan no)
    ssids=()
    formatted=()
    active_ssid=""

    for line in "${lines[@]}"; do
        IFS=: read -r in_use signal security ssid <<< "$line"
        [[ -z "$ssid" ]] && continue
        level=$((signal/25))
        [[ $level -ge ${#SIGNAL_ICONS[@]} ]] && level=$((${#SIGNAL_ICONS[@]}-1))
        icon=${SIGNAL_ICONS[$level]}
        [[ "$security" =~ WPA|WEP ]] && icon=${SECURED_SIGNAL_ICONS[$level]}
        entry="$icon $ssid"
        if [[ "$in_use" == "*" ]]; then
            entry="$WIFI_CONNECTED_ICON $entry"
            active_ssid="$ssid"
        fi
        ssids+=("$ssid")
        formatted+=("$entry")
    done

    choice=$(printf '%s\n' "${formatted[@]}" | rofi -dmenu -i -p "Wi-Fi SSID:")
    [[ -z "$choice" ]] && return
    idx=-1
    for i in "${!formatted[@]}"; do
        [[ "${formatted[$i]}" == "$choice" ]] && idx=$i && break
    done
    sel_ssid=${ssids[$idx]}

    # Действие
    if [[ "$sel_ssid" == "$active_ssid" ]]; then
        action="  Disconnect"
    else
        action="󰸋  Connect"
    fi
    action=$(printf '%s\n  Forget' "$action" | rofi -dmenu -p "Action:")
    case "$action" in
        "󰸋  Connect")
            if nmcli -g NAME connection show | grep -Fxq "$sel_ssid"; then
                nmcli connection up id "$sel_ssid" && notify-send "Подключено" "Вы подключены к $sel_ssid."
            else
                pass=$(rofi -dmenu -p "Пароль:" -password)
                nmcli device wifi connect "$sel_ssid" password "$pass" && notify-send "Подключено" "Вы подключены к $sel_ssid."
            fi
            ;;
        "  Disconnect")
            nmcli device disconnect "$WIFI_DEV" && notify-send "Отключено" "Отключено от $sel_ssid."
            ;;
        "  Forget")
            nmcli connection delete id "$sel_ssid" && notify-send "Забыт" "Сеть $sel_ssid забыта."
            ;;
    esac
}

manage_ethernet() {
    # Список Ethernet-устройств
    choices=()
    for dev in "${ETH_DEVS[@]}"; do
        state=$(nmcli -t -f DEVICE,STATE device status | awk -F: -v d="$dev" '$1==d{print $2}')
        [[ "$state" == "connected" ]] && choices+=("$ETHERNET_CONNECTED_ICON$dev") || choices+=("$dev")
    done

    sel=$(printf '%s\n' "${choices[@]}" | rofi -dmenu -i -p "Ethernet:")
    [[ -z "$sel" ]] && return
    dev="${sel//${ETHERNET_CONNECTED_ICON}/}"

    state=$(nmcli -t -f DEVICE,STATE device status | awk -F: -v d="$dev" '$1==d{print $2}')
    if [[ "$state" == "connected" ]]; then
        nmcli device disconnect "$dev" && notify-send "Отключено" "Ethernet $dev отключен."
    else
        nmcli device connect "$dev" && notify-send "Подключено" "Ethernet $dev подключен."
    fi
}

main_menu() {
    local status_mode=false
    while [[ $# -gt 0 ]]; do
        case $1 in
            --status) status_mode=true; shift ;;
            --enabled-color) ENABLED_COLOR="$2"; shift 2 ;;
            --disabled-color) DISABLED_COLOR="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    if $status_mode; then
        get_status
        exit
    fi

    if ! pgrep -x NetworkManager >/dev/null; then
        echo -n "Root Password: "
        read -s pw
        echo "$pw" | sudo -S systemctl start NetworkManager
    fi

    wifi_state=$(nmcli radio wifi)
    if [[ "$wifi_state" == "enabled" ]]; then
        wifi_toggle="󱛅  Disable Wi-Fi"
        wifi_cmd="off"
    else
        wifi_toggle="󱚽  Enable Wi-Fi"
        wifi_cmd="on"
    fi

    manage_wifi_btn='󱓥 Manage Wi-Fi'
    choice=$(printf '%s\n%s\n󱓥 Manage Ethernet' \
        "$wifi_toggle" \
        "$manage_wifi_btn" | \
        rofi -dmenu -theme config -p " Network Management:")
    case "$choice" in
        "$wifi_toggle"*)
            if nmcli radio wifi $wifi_cmd; then
                notify-send "Wi-Fi" "Wi-Fi $wifi_cmd"
            else
                notify-send "Ошибка Wi-Fi" "Не удалось изменить состояние"
            fi
            ;;
        *Manage\ Wi-Fi) manage_wifi ;;
        *Manage\ Ethernet) manage_ethernet ;;
    esac
}

main_menu "$@"

