layout=$(hyprctl devices -j | jq -r '.keyboards[] | select(.main).active_keymap')

case $layout in
    *English* ) echo '{"text":"EN"}' ;;
    *Russian* ) echo '{"text":"RU"}' ;;
    *) echo "{\"text\":\"$layout\"}" ;;
esac