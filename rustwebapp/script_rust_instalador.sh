#!/usr/bin/env bash
set -euo pipefail

# =========================================================
# Despliegue de Webapp Rust con systemd en Ubuntu
# =========================================================
#
# Los ficheros del proyecto (Cargo.toml, build.rs, src/)
# deben estar en la misma carpeta que este script.
#
# Este script está adaptado para la app Rust (HTTP-only)
# que creamos, usando el puerto 8081.
# =========================================================

# ---------- Config ----------
INSTALL_DIR="/opt/rustwebapp"               # Carpeta de despliegue
APP_BIN_NAME="mi_app_rust"                  # Nombre del binario (de Cargo.toml)
APP_PORT="8081"                             # Puerto de escucha (de main.rs)
SERVICE_NAME="rustwebapp.service"
APP_USER="rustwebapp"                       # Usuario del servicio
# Ruta completa al binario compilado
APP_BIN_PATH="$INSTALL_DIR/target/release/$APP_BIN_NAME"

# --- Funciones de Utilidad ---
log() { printf "\n\033[1;34m[INFO]\033[0m %s\n" "$*"; }
require_root() { [[ $EUID -eq 0 ]] || { echo "[ERROR] Ejecuta este script como root o con sudo."; exit 1; }; }

# 0) Requisitos
require_root

# 1) Instalar Dependencias del Sistema
log "Actualizando sistema e instalando Build-Essential y Curl…"
apt update
apt upgrade -y
# ¡YA NO INSTALAMOS 'cargo' DESDE APT!
apt install -y build-essential curl

# 2) Usuario del servicio (¡SECCIÓN CORREGIDA!)
if ! id -u "$APP_USER" >/dev/null 2>&1; then
  log "Creando usuario del servicio: $APP_USER"
  # 1. Crear el usuario (sin home, para evitar conflictos)
  useradd --system --shell /usr/sbin/nologin "$APP_USER"
fi

log "Asegurando que el directorio $HOME ($APP_USER) existe..."
# 2. Crear su home directory manualmente
mkdir -p "/home/$APP_USER"
# 3. Asignar permisos ANTES de que rustup intente escribir
chown -R "$APP_USER":"$APP_USER" "/home/$APP_USER"


# 2.5) Instalar Rust (con rustup) como el usuario del servicio
log "Instalando Rust (rustup) para el usuario $APP_USER..."
# Ejecutamos el instalador de rustup como el nuevo usuario
# El -y acepta todas las opciones por defecto
# El -H es crucial para que use el $HOME (/home/rustwebapp) del nuevo usuario
sudo -u "$APP_USER" -H bash -c "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path"
log "Rust (rustup) instalado en /home/$APP_USER/.cargo"


# 3) Copiar archivos del proyecto
log "Comprobando directorio de instalación $INSTALL_DIR..."

if [ -d "$INSTALL_DIR" ]; then
  log "El directorio ya existe. Deteniendo el servicio y borrando para una instalación limpia..."
  systemctl stop "$SERVICE_NAME" || true
  rm -rf "$INSTALL_DIR"
fi

log "Creando directorio de instalación virgen en $INSTALL_DIR…"
mkdir -p "$INSTALL_DIR"

log "Copiando archivos del proyecto (Cargo.toml, build.rs, src/)..."
# Usamos '*' para copiar archivos/carpetas ocultos si los hubiera
if ! [ -f Cargo.toml ] || ! [ -f build.rs ] || ! [ -d src ]; then
  log "[ERROR] No se encuentran los archivos del proyecto (Cargo.toml, build.rs, src/)."
  log "Asegúrate de ejecutar este script desde la carpeta que contiene tu código."
  exit 1
fi

cp Cargo.toml "$INSTALL_DIR"
cp build.rs "$INSTALL_DIR"
cp -r src "$INSTALL_DIR"

# 4) Permisos (Antes de compilar)
log "Asignando permisos de compilación en $INSTALL_DIR al usuario $APP_USER..."
# Damos al usuario control sobre todo el directorio para que 'cargo' pueda escribir
chown -R "$APP_USER":"$APP_USER" "$INSTALL_DIR"

# 5) Compilar el binario (como el usuario $APP_USER)
log "Compilando binario como $APP_USER (esto puede tardar varios minutos)..."
# Ejecutamos la compilación como el $APP_USER para que use SU versión de rustup
sudo -u "$APP_USER" -H bash -c "source \$HOME/.cargo/env && cd $INSTALL_DIR && cargo build --release"
cd / # Volvemos al directorio raíz
log "Binario compilado en: $APP_BIN_PATH"

# 6) Permisos Finales
log "Asignando permisos finales de ejecución..."
chmod 750 "$INSTALL_DIR"
chmod 750 "$APP_BIN_PATH"
# (chown ya se hizo en el paso 4)

# 7) Unidad systemd
log "Creando unidad systemd: /etc/systemd/system/$SERVICE_NAME"
cat > "/etc/systemd/system/$SERVICE_NAME" <<EOF
[Unit]
Description=Rust WebApp (mi_app_rust - $APP_PORT)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$APP_USER
Group=$APP_USER
WorkingDirectory=$INSTALL_DIR
ExecStart=$APP_BIN_PATH
Restart=on-failure
RestartSec=3

# ¡IMPORTANTE! El $HOME del usuario tiene el binario de Rust
Environment="PATH=/home/$APP_USER/.cargo/bin:/usr/bin:/bin"

# Endurecimiento básico (igual que el script de Go)
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
CapabilityBoundingSet=
LockPersonality=true
MemoryDenyWriteExecute=true

[Install]
WantedBy=multi-user.target
EOF

# 8) UFW (Firewall)
if command -v ufw >/dev/null 2>&1; then
  if ufw status | grep -q "Status: active"; then
    log "UFW está activo. Abriendo puerto $APP_PORT/TCP..."
    ufw allow "${APP_PORT}/tcp" || true
  else
    log "UFW no está activo. Activándolo y abriendo puertos (SSH, $APP_PORT)..."
    ufw allow ssh
    ufw allow "${APP_PORT}/tcp"
    ufw --force enable
  fi
fi

# 9) Habilitar e iniciar servicio
log "Recargando systemd, habilitando e iniciando el servicio…"
systemctl daemon-reload
systemctl enable "$SERVICE_NAME"
systemctl restart "$SERVICE_NAME"

sleep 1
systemctl --no-pager --full status "$SERVICE_NAME" || true

# 10) ¡FIN!
echo
echo "=============================================="
echo " Despliegue de RUST completado"
echo "----------------------------------------------"
echo "Binario:          $APP_BIN_PATH"
echo "Servicio:         $SERVICE_NAME"
echo "Usuario servicio: $APP_USER"
echo
echo "Comandos útiles:"
echo "  sudo systemctl status $SERVICE_NAME"
echo "  sudo journalctl -u $SERVICE_NAME -f"
echo "  sudo systemctl restart $SERVICE_NAME"
echo
echo "Accede a:"
echo "  http://<ip_servidor>:$APP_PORT/"
echo "=============================================="
