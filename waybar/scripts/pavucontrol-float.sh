#!/bin/bash

# Проверяем, запущен ли уже pavucontrol
if pgrep -x "pavucontrol" > /dev/null; then
    # Если запущен - закрываем
    pkill pavucontrol
else
    # Если не запущен - открываем и применяем правила
    pavucontrol 2>/dev/null
fi