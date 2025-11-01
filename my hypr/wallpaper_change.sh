#!/bin/bash

DIR="$HOME/wallpapers"

# Получаем текущий файл
current_file=$(readlink $DIR/current.png | awk -F/ '{print $NF}')

# Создаём массив всех обоев
mapfile -t wallpapers < <(ls "$DIR" | grep -v "current" | grep -v "wlogout")

# Находим индекс текущего файла
current_index=-1
for i in "${!wallpapers[@]}"; do
    if [[ "${wallpapers[$i]}" == "$current_file" ]]; then
        current_index=$i
        break
    fi
done

# Следующий индекс с циклическим переходом
next_index=$(( (current_index + 1) % ${#wallpapers[@]} ))
next_file="${wallpapers[$next_index]}"

ln -sf "$DIR/$next_file" "$DIR/current.png"
hyprctl hyprpaper reload eDP-1,~/wallpapers/current.png
convert "$DIR/$next_file" -blur 0x15 "$DIR/wlogout_back.jpg"
