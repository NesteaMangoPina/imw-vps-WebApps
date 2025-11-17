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

# 1) Instalar Dependencias de Rust
log "Actualizando sistema e instalando Cargo, RustC y Build-Essential…"
apt update
apt upgrade -y
# Instalamos 'cargo' desde apt. Esto trae 'rustc' y es más simple 
# para un script de servidor que 'rustup'.
apt install -y cargo build-essential curl

log "Verificando Cargo y RustC instalados…"
cargo version
rustc --version

# 2) Usuario del servicio
if ! id -u "$APP_USER" >/dev/null 2>&1; then
  log "Creando usuario del servicio: $APP_USER"
  # Usuario de sistema, sin home, sin login
  useradd --system --no-create-home --shell /usr/sbin/nologin "$APP_USER"
fi

# 3) Copiar archivos del proyecto
log "Creando directorio de instalación en $INSTALL_DIR…"
mkdir -p "$INSTALL_DIR"

log "Copiando archivos del proyecto (Cargo.toml, build.rs, src/)..."
# Comprobamos que estamos en la carpeta correcta (donde están los archivos fuente)
if ! [ -f Cargo.toml ] || ! [ -f build.rs ] || ! [ -d src ]; then
  log "[ERROR] No se encuentran los archivos del proyecto (Cargo.toml, build.rs, src/)."
  log "Asegúrate de ejecutar este script desde la carpeta que contiene tu código."
  exit 1
fi

# Copiamos la estructura del proyecto
cp Cargo.toml "$INSTALL_DIR"
cp build.rs "$INSTALL_DIR"
cp -r src "$INSTALL_DIR"

# 4) Compilar el binario
log "Compilando binario en modo release (esto puede tardar varios minutos)..."
cd "$INSTALL_DIR"
# Ejecutamos 'cargo build' como root, ya que instalamos cargo globalmente
cargo build --release
cd / # Volvemos al directorio raíz
log "Binario compilado en: $APP_BIN_PATH"

# 5) Permisos
log "Asignando permisos en $INSTALL_DIR al usuario $APP_USER..."
# Damos al usuario control sobre todo el directorio
chown -R "$APP_USER":"$APP_USER" "$INSTALL_DIR"
# Solo el usuario puede entrar, leer y ejecutar
chmod 750 "$INSTALL_DIR"
chmod 750 "$APP_BIN_PATH"

# 6) Env del servicio (Saltado)
log "Saltando creación de ENV_FILE (El puerto $APP_PORT está hardcodeado en main.rs)..."

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
