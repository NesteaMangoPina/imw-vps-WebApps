# 🚀 Instalador Automático para WebApp en Rust (Ubuntu Server)

Este proyecto incluye un script completamente automatizado para instalar Rust, compilar tu aplicación y desplegarla como servicio **systemd** en Ubuntu Server.

No necesitas configurar nada manualmente:  
**solo ejecutar el script y todo quedará instalado, compilado y funcionando.**

---

## 📁 Requisitos

- Ubuntu Server 20.04 / 22.04 / 24.04  
- Permisos de root o `sudo`  
- Los archivos del proyecto deben estar en la misma carpeta que este script:

Cargo.toml
build.rs
src/
script_rust_instalador.sh

yaml
Copiar código

---

## ▶️ 1. Dar permisos al script

```sh
chmod +x script_rust_instalador.sh

```
--- 

## ▶️ 2. Ejecutar el script (obligatorio como root o con sudo)

sh
Copiar código
sudo ./script_rust_instalador.sh
El script realizará automáticamente:

Actualización del sistema

Instalación de dependencias (build-essential, curl)

Creación del usuario del servicio

Instalación de Rust mediante rustup

Copia del proyecto a /opt/rustwebapp

Compilación en modo --release

Creación del servicio systemd

Apertura del puerto configurado en UFW

Inicio y habilitación del servicio al arrancar

---

## 🌐 3. Acceso a la WebApp
Una vez completada la instalación, la app estará disponible en:

cpp
Copiar código
http://<IP_DEL_SERVIDOR>:8081/
(Puerto configurado dentro del script: APP_PORT="8081")

---

## 🛠 4. Comandos útiles del servicio systemd
sh
Copiar código
sudo systemctl status rustwebapp
sudo systemctl restart rustwebapp
sudo systemctl stop rustwebapp
sudo journalctl -u rustwebapp -f

---

## 📌 Notas importantes
El script despliega el proyecto en:

bash
Copiar código
/opt/rustwebapp
Compila usando el usuario interno rustwebapp

El binario final queda en:

swift
Copiar código
/opt/rustwebapp/target/release/mi_app_rust
El servicio creado en systemd se llama:

Copiar código
rustwebapp.service
