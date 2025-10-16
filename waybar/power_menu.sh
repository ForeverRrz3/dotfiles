#!/bin/bash
# ~/.config/waybar/scripts/dynamic_menu.sh

echo '<?xml version="1.0" encoding="UTF-8"?>'
echo '<openbox_pipe_menu>'

# Динамическое добавление пунктов
if ping -c1 google.com &>/dev/null; then
  echo '  <item label="Интернет есть" icon="network-wired">'
  echo '    <action name="Execute"><command>echo "Online"</command></action>'
  echo '  </item>'
else
  echo '  <item label="Нет интернета" icon="network-wireless-disconnected">'
  echo '    <action name="Execute"><command>nm-connection-editor</command></action>'
  echo '  </item>'
fi

echo '</openbox_pipe_menu>'