#!/usr/bin/env bash

# Путь к файлам с DHCP-настройками
DHCP_LEASES="/run/systemd/netif/leases/*"

# Искомая переменная
VARIABLE="SERVER_ADDRESS"

for file in $DHCP_LEASES; do
  if [ -f "$file" ]; then
    # Проверяем содержимое файла на соответствие искомой переменной
    if grep -q "$VARIABLE=" "$file"; then
      # Если переменная найдена, то выводим ее значение
      IP=$(grep $VARIABLE= "$file" | cut -d'=' -f2-)
      echo "SERVER_ADDRESS = $IP"

      # Скачиваем публичный ключ с URL
      publickey=$(wget -t 3 -T 20 -O - http://$IP/latest/public-keys 2>/dev/null)
      if [ $? -eq 0 ]; then
        echo "Public key: $publickey"

        # Определяем имя пользователя с uid 1000 и путь до домашней директории
        USER=$(getent passwd 1000 | cut -d: -f1)
        eval HOME_DIR=~$USER

        # Добавляем публичный ключ в файл .ssh/authorized_keys домашней директории пользователя
        AUTHORIZED_KEYS_PATH=$HOME_DIR/.ssh/authorized_keys

        if [ ! -f "$AUTHORIZED_KEYS_PATH" ]; then
          mkdir -p $(dirname $AUTHORIZED_KEYS_PATH)
          touch $AUTHORIZED_KEYS_PATH
        fi

        if ! grep -q "$publickey" "$AUTHORIZED_KEYS_PATH"; then
          echo "${publickey} ${USER}@${IP}" >> "$AUTHORIZED_KEYS_PATH"
          chown $USER:$USER "$AUTHORIZED_KEYS_PATH"
          chmod 600 "$AUTHORIZED_KEYS_PATH"
          echo "Public key added to authorized keys file"
        else
          echo "Public key already exists in authorized keys file"
        fi

      else
        echo "Error downloading public key"
      fi

    fi
  fi
done