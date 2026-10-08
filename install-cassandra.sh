#!/usr/bin/env bash
#
# Descripción: Instalación y configuración básica de Apache Cassandra 5.0
#              en Debian 13 (Trixie) mediante los repositorios oficiales
#              de Apache Cassandra y Adoptium.
#
# Modos de ejecución:
#   --server  Instala Java 17 y el servidor Apache Cassandra.
#   --client  Instala cqlsh mediante pipx.
#   Sin parámetros: Equivale a --server.
#
# Autor: ElLucaMx
# Versión: 1.0.0
# Fecha: 2026-10-08
# Licencia: MIT
#
# Requisitos:
# - Debian 13 (Trixie) de 64 bits
# - Arquitectura x86_64
# - Usuario con privilegios sudo
# - Conexión a Internet
#
#

set -euo pipefail

# Colores
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Funciones de salida
info() {
    echo -e "${BLUE}$1${NC}"
}

success() {
    echo -e "${GREEN}$1${NC}"
}

error() {
    echo -e "${RED}$1${NC}"
}

# ============================================================
# Variables
# ============================================================

# Cassandra
CASSANDRA_VERSION="5.0"
CASSANDRA_DISTRIBUTION="50x"

CASSANDRA_PACKAGE="cassandra"
CASSANDRA_REPOSITORY="https://debian.cassandra.apache.org"

CASSANDRA_KEY_URL="https://downloads.apache.org/cassandra/KEYS"
CASSANDRA_KEYRING="/etc/apt/keyrings/apache-cassandra.asc"
CASSANDRA_LIST="/etc/apt/sources.list.d/cassandra.sources.list"

# Tiempo máximo de espera para que Cassandra esté operativa
CASSANDRA_STARTUP_TIMEOUT=120
CASSANDRA_STARTUP_INTERVAL=2

# Adoptium / Temurin
JAVA_VERSION="17"
JAVA_PACKAGE="temurin-17-jdk"

ADOPTIUM_REPOSITORY="https://packages.adoptium.net/artifactory/deb"
ADOPTIUM_KEY_URL="https://packages.adoptium.net/artifactory/api/gpg/key/public"

ADOPTIUM_KEYRING="/etc/apt/keyrings/adoptium.gpg"
ADOPTIUM_LIST="/etc/apt/sources.list.d/adoptium.list"

# Cliente cqlsh
PIPX_PACKAGE="pipx"
CQLSH_PACKAGE="cqlsh"
CQLSH_VERSION="6.2.2"

# ============================================================
# Funciones auxiliares
# ============================================================

# Comprobar si un paquete ya está instalado
is_package_installed() {
    local package="$1"

    dpkg-query -W -f='${Status}' "${package}" 2>/dev/null \
        | grep -q "install ok installed"
}

# Obtener la ruta de cqlsh instalado mediante pipx
get_cqlsh_bin() {
    local bin_dir=""

    if command -v cqlsh >/dev/null 2>&1; then
        command -v cqlsh
        return 0
    fi

    if command -v pipx >/dev/null 2>&1; then
        bin_dir="$(pipx environment --value PIPX_BIN_DIR 2>/dev/null || true)"

        if [[ -n "${bin_dir}" && -x "${bin_dir}/cqlsh" ]]; then
            echo "${bin_dir}/cqlsh"
            return 0
        fi
    fi

    if [[ -x "${HOME}/.local/bin/cqlsh" ]]; then
        echo "${HOME}/.local/bin/cqlsh"
        return 0
    fi

    return 1
}

# ============================================================
# Comprobación del sistema
# ============================================================

check_system() {
    info "Comprobando el sistema operativo..."

    if [[ ! -f /etc/os-release ]]; then
        error "ERROR: No se ha podido determinar el sistema operativo."
        exit 1
    fi

    source /etc/os-release

    if [[ "${ID}" != "debian" ]]; then
        error "ERROR: Este script está diseñado para Debian."
        error "Sistema detectado: ${ID}"
        exit 1
    fi

    if [[ "${VERSION_ID}" != "13" ]]; then
        error "ERROR: Este script requiere Debian 13 (Trixie)."
        error "Versión detectada: Debian ${VERSION_ID}"
        exit 1
    fi

    ARCHITECTURE="$(dpkg --print-architecture)"

    if [[ "${ARCHITECTURE}" != "amd64" ]]; then
        error "ERROR: Este script requiere arquitectura x86_64."
        error "Arquitectura detectada: ${ARCHITECTURE}"
        exit 1
    fi

    success "Sistema operativo: Debian ${VERSION_ID} (${VERSION_CODENAME})"
    success "Arquitectura: ${ARCHITECTURE}"

    echo
}

# ============================================================
# Comprobación de instalación
# ============================================================

check_server_installed() {
    if is_package_installed "${CASSANDRA_PACKAGE}"; then
        success "Apache Cassandra ya está instalado."
        success "No es necesario realizar ninguna acción."

        echo

        info "Paquete: ${CASSANDRA_PACKAGE}"
        info "Servicio: cassandra"

        if sudo systemctl is-active --quiet cassandra; then
            success "Estado: active"
        else
            info "Estado: inactive"
        fi

        echo

        return 0
    fi

    return 1
}

check_client_installed() {
    local cqlsh_bin=""

    if cqlsh_bin="$(get_cqlsh_bin)"; then
        success "cqlsh ya está instalado."
        success "No es necesario realizar ninguna acción."

        echo

        info "Comando: ${cqlsh_bin}"

        echo

        return 0
    fi

    return 1
}

# ============================================================
# Dependencias
# ============================================================

install_server_dependencies() {
    info "Instalando dependencias necesarias..."

    sudo apt-get update

    sudo apt-get install -y curl gnupg

    success "Dependencias instaladas correctamente."

    echo
}

install_client_dependencies() {
    info "Instalando dependencias necesarias para cqlsh..."

    sudo apt-get update

    sudo apt-get install -y "${PIPX_PACKAGE}" python3

    success "Dependencias instaladas correctamente."

    echo
}

# ============================================================
# Java / Adoptium
# ============================================================

configure_adoptium_repository() {
    info "Configurando el repositorio de Adoptium..."

    sudo mkdir -p /etc/apt/keyrings

    if [[ ! -f "${ADOPTIUM_KEYRING}" ]]; then
        curl -fsSL "${ADOPTIUM_KEY_URL}" \
            | sudo gpg --dearmor -o "${ADOPTIUM_KEYRING}"

        success "Clave GPG de Adoptium instalada correctamente."
    else
        info "La clave GPG de Adoptium ya existe."
        info "No es necesario volver a importarla."
    fi

    sudo chmod 644 "${ADOPTIUM_KEYRING}"

    echo

    echo "deb [signed-by=${ADOPTIUM_KEYRING}] ${ADOPTIUM_REPOSITORY} trixie main" \
        | sudo tee "${ADOPTIUM_LIST}" > /dev/null

    success "Repositorio de Adoptium configurado correctamente."

    echo

    info "Actualizando la lista de paquetes..."

    sudo apt-get update

    success "Lista de paquetes actualizada correctamente."

    echo
}

install_java() {
    if is_package_installed "${JAVA_PACKAGE}"; then
        success "Temurin ${JAVA_VERSION} ya está instalado."
        echo
        return 0
    fi

    info "Instalando Temurin ${JAVA_VERSION}..."

    sudo apt-get install -y "${JAVA_PACKAGE}"

    success "Temurin ${JAVA_VERSION} instalado correctamente."

    echo
}

select_java() {
    local java_binary=""

    info "Seleccionando Java ${JAVA_VERSION} como versión predeterminada..."

    java_binary="$(
        update-alternatives --list java 2>/dev/null \
            | grep '/temurin-17[^/]*/bin/java$' \
            | head -n 1 || true
    )"

    if [[ -z "${java_binary}" ]]; then
        error "ERROR: No se ha encontrado la instalación de Temurin ${JAVA_VERSION}."
        exit 1
    fi

    sudo update-alternatives --set java "${java_binary}"

    success "Java ${JAVA_VERSION} seleccionado como versión predeterminada."

    echo
}

check_java() {
    info "Comprobando la versión de Java..."

    local java_major

    java_major="$(
        java -version 2>&1 \
            | sed -n 's/.*version "\([0-9]\+\).*/\1/p' \
            | head -n 1
    )"

    if [[ "${java_major}" != "${JAVA_VERSION}" ]]; then
        error "ERROR: Se esperaba Java ${JAVA_VERSION}."
        error "Versión detectada: ${java_major:-desconocida}"
        exit 1
    fi

    success "Java ${JAVA_VERSION} está correctamente instalado."

    echo

    java -version

    echo
}

# ============================================================
# Repositorio Cassandra
# ============================================================

configure_cassandra_repository() {
    info "Configurando el repositorio oficial de Cassandra..."

    sudo mkdir -p /etc/apt/keyrings

    if [[ ! -f "${CASSANDRA_KEYRING}" ]]; then
        sudo curl -fsSL -o "${CASSANDRA_KEYRING}" \
            "${CASSANDRA_KEY_URL}"

        success "Clave GPG de Cassandra instalada correctamente."
    else
        info "La clave GPG de Cassandra ya existe."
        info "No es necesario volver a descargarla."
    fi

    sudo chmod 644 "${CASSANDRA_KEYRING}"

    echo

    echo "deb [signed-by=${CASSANDRA_KEYRING}] ${CASSANDRA_REPOSITORY} ${CASSANDRA_DISTRIBUTION} main" \
        | sudo tee "${CASSANDRA_LIST}" > /dev/null

    success "Repositorio oficial de Cassandra configurado correctamente."

    echo

    info "Actualizando la lista de paquetes..."

    sudo apt-get update

    success "Lista de paquetes actualizada correctamente."

    echo
}

# ============================================================
# Cassandra
# ============================================================

install_server() {
    info "Instalando Apache Cassandra ${CASSANDRA_VERSION}..."

    sudo apt-get install -y "${CASSANDRA_PACKAGE}"

    success "Apache Cassandra instalado correctamente."

    echo
}

start_server() {
    info "Iniciando el servicio cassandra..."

    sudo systemctl start cassandra

    success "Servicio cassandra iniciado correctamente."

    echo
}

enable_server() {
    info "Habilitando Cassandra al arrancar..."

    sudo systemctl enable cassandra

    success "Cassandra se iniciará automáticamente con el sistema."

    echo
}

check_server() {
    echo

    info "=============================================="
    info " Estado del servicio Cassandra"
    info "=============================================="

    echo

    if sudo systemctl is-active --quiet cassandra; then
        success "Cassandra está funcionando correctamente."
    else
        error "ERROR: Cassandra no está funcionando."

        echo

        sudo systemctl status cassandra --no-pager

        exit 1
    fi

    echo
}

wait_for_cassandra() {
    local elapsed=0
    local remaining

    info "Esperando a que Cassandra esté completamente operativa..."

    while (( elapsed < CASSANDRA_STARTUP_TIMEOUT )); do

        if nodetool status >/dev/null 2>&1; then
            success "Cassandra está lista para recibir operaciones."

            echo

            return 0
        fi

        remaining=$((CASSANDRA_STARTUP_TIMEOUT - elapsed))

        info "Cassandra todavía está iniciándose."
        info "Tiempo restante: ${remaining}s"

        sleep "${CASSANDRA_STARTUP_INTERVAL}"

        elapsed=$((elapsed + CASSANDRA_STARTUP_INTERVAL))
    done

    error "ERROR: Cassandra no ha terminado de iniciar dentro del tiempo esperado."

    echo

    info "Estado del servicio:"

    sudo systemctl status cassandra --no-pager || true

    echo

    info "Estado de nodetool:"

    nodetool status || true

    echo

    info "Últimos registros de Cassandra:"

    sudo journalctl -u cassandra -n 50 --no-pager || true

    exit 1
}

check_node() {
    info "Comprobando el estado del nodo Cassandra..."

    local status_output=""

    if ! status_output="$(nodetool status 2>&1)"; then
        error "ERROR: No se ha podido consultar el estado del nodo."

        echo

        echo "${status_output}"

        exit 1
    fi

    echo "${status_output}"

    echo

    if ! grep -Eq '^[[:space:]]*UN[[:space:]]' <<< "${status_output}"; then
        error "ERROR: El nodo Cassandra no está en estado UN (Up/Normal)."
        exit 1
    fi

    success "Nodo Cassandra en estado UN (Up/Normal)."

    echo
}

show_server_version() {
    info "=============================================="
    info " Versión instalada"
    info "=============================================="

    echo

    local installed_version

    installed_version="$(
        dpkg-query -W -f='${Version}' "${CASSANDRA_PACKAGE}"
    )"

    info "Paquete: ${CASSANDRA_PACKAGE}"
    info "Versión del paquete: ${installed_version}"

    echo

    nodetool version

    echo
}

# ============================================================
# cqlsh
# ============================================================

install_client() {
    info "Instalando cqlsh..."

    pipx install "${CQLSH_PACKAGE}==${CQLSH_VERSION}"

    success "cqlsh ${CQLSH_VERSION} instalado correctamente."

    echo
}

configure_client_path() {
    info "Configurando el PATH de pipx..."

    pipx ensurepath

    success "Ruta de ejecutables de pipx configurada correctamente."

    echo
}

show_client_version() {
    info "=============================================="
    info " Versión de cqlsh"
    info "=============================================="

    echo

    local cqlsh_bin

    cqlsh_bin="$(get_cqlsh_bin)"

    info "Comando: ${cqlsh_bin}"

    echo

    "${cqlsh_bin}" --version

    echo
}

# ============================================================
# Flujos principales
# ============================================================

server_installation() {
    info "=============================================="
    info " Instalación de Apache Cassandra ${CASSANDRA_VERSION}"
    info "=============================================="

    echo

    # Si ya está instalado, no hacemos nada más
    if check_server_installed; then
        return 0
    fi

    install_server_dependencies
    configure_adoptium_repository
    install_java
    select_java
    check_java
    configure_cassandra_repository
    install_server
    start_server
    enable_server
    check_server
    wait_for_cassandra
    check_node
    show_server_version

    echo

    success "=============================================="
    success " Instalación de Cassandra completada"
    success "=============================================="

    echo

    success "Apache Cassandra ${CASSANDRA_VERSION} ha sido instalado"
    success "en Debian 13 (Trixie)."

    echo

    info "Paquete: ${CASSANDRA_PACKAGE}"
    info "Servicio: cassandra"
    success "Estado: $(sudo systemctl is-active cassandra)"

    echo
}

client_installation() {
    info "=============================================="
    info " Instalación de cqlsh"
    info "=============================================="

    echo

    # Si ya está instalado, no hacemos nada más
    if check_client_installed; then
        return 0
    fi

    install_client_dependencies

    info "Comprobando la versión de Python..."

    local python_version

    python_version="$(
        python3 -c \
        'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")'
    )"

    info "Python detectado: ${python_version}"

    if ! python3 -c '
import sys
sys.exit(0 if sys.version_info >= (3, 10) else 1)
'; then
        error "ERROR: cqlsh ${CQLSH_VERSION} requiere Python 3.10 o superior."
        exit 1
    fi

    success "Versión de Python compatible."

    echo

    install_client
    configure_client_path
    show_client_version

    echo

    success "=============================================="
    success " Instalación de cqlsh completada"
    success "=============================================="

    echo

    success "cqlsh ${CQLSH_VERSION} ha sido instalado"
    success "para el usuario actual."

    echo

    info "Paquete: ${CQLSH_PACKAGE}"
    info "Versión: ${CQLSH_VERSION}"

    echo
}

# ============================================================
# Ayuda
# ============================================================

show_help() {
    info "Uso: $0 [OPCIÓN]"

    echo

    info "Opciones:"
    echo

    info "  --server"
    info "      Instala Java 17 y Apache Cassandra ${CASSANDRA_VERSION}."

    echo

    info "  --client"
    info "      Instala cqlsh mediante pipx."

    echo

    info "  --help"
    info "      Muestra esta ayuda."

    echo

    info "Sin parámetros:"
    info "      Equivale a --server."

    echo
}

# ============================================================
# Gestión de argumentos
# ============================================================

MODE="server"

case "${1:-}" in
    --server)
        MODE="server"
        ;;

    --client)
        MODE="client"
        ;;

    --help|-h)
        show_help
        exit 0
        ;;

    "")
        MODE="server"
        ;;

    *)
        error "ERROR: Parámetro no reconocido: $1"

        echo

        show_help

        exit 1
        ;;
esac

# ============================================================
# Punto de entrada
# ============================================================

echo

info "=============================================="
info " Apache Cassandra ${CASSANDRA_VERSION}"
info " Debian 13 (Trixie)"
info "=============================================="

echo

check_system

case "${MODE}" in
    server)
        server_installation
        ;;

    client)
        client_installation
        ;;
esac
