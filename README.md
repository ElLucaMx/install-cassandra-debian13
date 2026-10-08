<h1 align="center">Apache Cassandra 5.0 en Debian Trixie</h1>

<p align="center">
  <b>Instalación automatizada de Apache Cassandra 5.0 en Debian 13 (Trixie)</b>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Apache%20Cassandra-5.0-1287B1?style=for-the-badge&logo=apachecassandra&logoColor=white" alt="Apache Cassandra 5.0" />
  <img src="https://img.shields.io/badge/Debian-13%20(Trixie)-a80030?style=for-the-badge&logo=debian&logoColor=white" alt="Debian 13" />
</p>

---

## Descripción

Script Bash para instalar **Apache Cassandra 5.0** en **Debian 13 (Trixie)** mediante los repositorios oficiales de **Apache Cassandra** y **Adoptium**.

El script comprueba el sistema, configura las claves GPG y los repositorios necesarios, instala **Temurin 17** y Cassandra y, en el caso del servidor, inicia y habilita el servicio `cassandra`.

Después del arranque, espera a que Cassandra esté completamente operativa antes de realizar la comprobación del nodo mediante `nodetool`.

También permite instalar **cqlsh** de forma independiente mediante `pipx`.

## Requisitos

- Debian 13 (Trixie)
- Arquitectura `amd64` (`x86_64`)
- Privilegios `sudo` para la instalación del servidor
- Conexión a Internet

## Uso

Dar permisos de ejecución:

```bash
chmod +x install-cassandra.sh
```

### Instalar el servidor

```bash
./install-cassandra.sh --server
```

Instala:

- Temurin 17
- Apache Cassandra 5.0

Además, inicia el servicio `cassandra` y lo habilita para que se inicie automáticamente con el sistema.

### Instalar cqlsh

```bash
./install-cassandra.sh --client
```

Instala **cqlsh** mediante `pipx` para el usuario actual.

Después de ejecutar `pipx ensurepath`, puede ser necesario abrir una nueva terminal o volver a iniciar sesión para que la ruta de `pipx` esté disponible en el `PATH`.

### Ayuda

```bash
./install-cassandra.sh --help
```

## Comportamiento

El script comprueba automáticamente que el sistema sea **Debian 13 `amd64`**.

También detecta si el componente solicitado ya está instalado. En ese caso, muestra un mensaje indicando que ya está instalado y evita repetir la instalación.

Durante la instalación del servidor, Cassandra puede tardar unos segundos en estar completamente operativa después de que el servicio aparezca como `active`.

## Comprobar Cassandra

Estado del servicio:

```bash
sudo systemctl status cassandra
```

Comprobación rápida:

```bash
sudo systemctl is-active cassandra
```

Estado del nodo:

```bash
nodetool status
```

En una instalación correcta, el nodo debería aparecer con el estado:

```text
UN
```

donde:

```text
U = Up
N = Normal
```

Versión de Cassandra:

```bash
nodetool version
```

Versión de Java:

```bash
java -version
```

Versión de cqlsh:

```bash
cqlsh --version
```

## Control del servicio

```bash
sudo systemctl start cassandra
sudo systemctl stop cassandra
sudo systemctl restart cassandra
```

Para habilitar Cassandra al arrancar:

```bash
sudo systemctl enable cassandra
```

## Desinstalación

Para eliminar el servidor:

```bash
sudo apt remove cassandra
```

Para eliminar también los archivos de configuración:

```bash
sudo apt purge cassandra
```

El paquete `cassandra-tools` es independiente y no se instala automáticamente mediante este script.

La instalación de `cqlsh` mediante `pipx` se gestiona independientemente del paquete Cassandra. Para eliminarlo:

```bash
pipx uninstall cqlsh
```

Los datos y archivos generados por Cassandra pueden requerir eliminación manual.
