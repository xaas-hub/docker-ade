[![Docker Pulls](https://img.shields.io/docker/pulls/frugan/ade)](https://hub.docker.com/r/frugan/ade)
[![Docker Image Size](https://img.shields.io/docker/image-size/frugan/ade/latest)](https://hub.docker.com/r/frugan/ade)
[![Build Status](https://github.com/xaas-hub/docker-ade/actions/workflows/ci.yml/badge.svg)](https://github.com/xaas-hub/docker-ade/actions/workflows/ci.yml)
[![GitHub Release](https://img.shields.io/github/v/release/xaas-hub/docker-ade)](https://github.com/xaas-hub/docker-ade/releases)
[![License](https://img.shields.io/github/license/xaas-hub/docker-ade)](https://github.com/xaas-hub/docker-ade/blob/main/LICENSE)

# docker-ade

Container Debian per far girare su Linux il software desktop dell'**Agenzia
delle Entrate**: **Desktop Telematico** (controllo, autenticazione, invio) e le
applicazioni distribuite come file `.jnlp` — **RedditiOnLine PF**, **Il tuo
ISA**, e in generale qualunque altra — tramite **OpenWebStart** e una JVM
**Zulu 8 con JavaFX**.

La GUI esce sul server X dell'host tramite socket unix: niente porte aperte,
niente VNC, uso esclusivamente locale.

> Progetto non ufficiale, senza alcuna affiliazione con l'Agenzia delle
> Entrate. L'immagine **non contiene** software dell'Agenzia: viene scaricato
> dai server ufficiali al primo avvio, dentro il volume persistente.

<details>
<summary>In English</summary>

A Debian container that runs the Italian Revenue Agency's desktop tax software
on Linux: Desktop Telematico plus any of its JNLP applications, through
OpenWebStart and a Zulu 8 JVM with JavaFX. The GUI is displayed on the host X
server over a unix socket. The published image ships only the generic runtime —
no Agency software is redistributed; it is downloaded from the official servers
on first run. The documentation is in Italian because the applications, their
error messages and the tax rules they implement are.
</details>

---

## Cosa c'è nell'immagine

| | |
|---|---|
| OpenWebStart | pacchetto `.deb` ufficiale di Karakun, in `/opt/OpenWebStart` |
| Zulu 8 + JavaFX | risolto in build tramite la metadata API di Azul, in `/opt/jvm` |
| GTK 2/3, WebKit2, font | dipendenze di Desktop Telematico e delle app JNLP |
| `desktop-telematico`, `jws` (+ alias `rpf`, `isa`) | launcher |

Il JRE incluso in OpenWebStart serve solo a eseguire OpenWebStart stesso: le
applicazioni JNLP girano sulle JVM registrate nel JVM Manager. Le app
dell'Agenzia sono JavaFX su Java 8, e un OpenJDK 8 senza JavaFX (per esempio
Adoptium) non le avvia: per questo l'immagine registra Zulu tramite
`ows.jvm.manager.customSearchLocation`.

## Tag disponibili

| Tag | Contenuto |
|---|---|
| `latest` | ultima build del branch `main` |
| `main` | la stessa, per riferirsi esplicitamente al branch |
| `1`, `1.2`, `1.2.3` | release semantiche, dai tag `v*` |

Solo `linux/amd64`: l'Agenzia pubblica il proprio software Linux unicamente per
x86-64, e nemmeno Zulu 8 con JavaFX ha una build linux-aarch64.

## Prerequisiti

- Docker Engine + plugin `compose` (2.24 o superiore)
- Un server X sull'host (su Wayland serve XWayland, di norma già attivo)
- `userns-remap` attivo nel daemon, **oppure** `DOCKER_USER` valorizzato nel
  `.env` (vedi sotto)
- Circa 2 GB di spazio

## Avvio rapido

```bash
git clone https://github.com/xaas-hub/docker-ade.git
cd docker-ade
cp .env.dist .env      # verifica che DISPLAY coincida con `echo $DISPLAY`
./run.sh               # scarica Desktop Telematico e lo apre
```

Al primo avvio Desktop Telematico chiede di creare un'area di lavoro con un
identificativo utente e una password a tua scelta: sono locali, non hanno nulla
a che vedere con le credenziali Fisconline/Entratel.

### Permessi sui file

L'utente predefinito del container è root, che con `userns-remap` viene mappato
sul tuo utente host: è ciò che rende `./data` scrivibile e il socket X11
accettabile. Se il daemon **non** usa `userns-remap`, metti nel `.env`:

```
DOCKER_USER=1000:1000     # id -u : id -g
```

L'entrypoint registra quell'uid in `/etc/passwd`, perché Java ricava
`user.home` dal database passwd e ignora `$HOME`.

## Applicazioni JNLP

I file `.jnlp` vanno scaricati a mano in `vendor/`: il portale
`agenziaentrate.gov.it` risponde con una pagina di bot detection ai client non
browser, quindi non è automatizzabile.

| Applicazione | Dove |
|---|---|
| `RPF<aa>.jnlp` | Archivio → "Software di compilazione Redditi PF `<anno>`" |
| `ISA<anno>.jnlp` | "Software Indici Sintetici di Affidabilità — Il tuo ISA `<anno>`", link JWS |
| qualunque altra | scaricala e mettila lì: il launcher non ha un elenco di app note |

> **Attenzione al nome del modello.** `Redditi PF 2022` serve a dichiarare i
> redditi del **2021**, e il file si chiama `RPF22.jnlp`. Se scarichi l'anno
> sbagliato ricompili la dichiarazione errata.

Poi:

```bash
./run.sh jws --list           # cosa c'è in vendor/
./run.sh RPF22                # vendor/RPF22.jnlp
./run.sh iva 26               # vendor/IVA26.jnlp
./run.sh isa 2024             # vendor/*isa*2024*.jnlp
./run.sh jws /vendor/x.jnlp   # percorso esplicito
./run.sh jws --check          # quale javaws è in uso
```

Il match è case-insensitive e si rifiuta di indovinare: se più file
corrispondono, li elenca e si ferma. Ogni anno d'imposta è un file a sé, quindi
puoi tenere in `vendor/` tutte le annualità che ti servono e lanciarle
indifferentemente — la cache di OpenWebStart le tiene separate.

### Percorso di installazione

Alcune applicazioni — "Il tuo ISA" fra queste — al primo avvio chiedono una
directory in cui installarsi. Il valore proposto è `/root/<nome>/`, che grazie
al symlink `/root` → `/data/home` finisce già nel volume persistente, ma
conviene indicare il percorso esteso:

```
/data/home/Isa2022
```

L'applicazione lo memorizza in forma assoluta e non lo aggiorna più: un
percorso che non dipende dal symlink sopravvive a un cambio di layout. Vale la
stessa logica della riga `/data/home` in "Persistenza", dove stanno le banche
dati locali delle app JNLP.

Alla domanda "Add shortcut to start menu" togli la spunta: nel container non
c'è un menu applicazioni.

## Uso

```bash
./run.sh                      # Desktop Telematico
./run.sh isa 2024             # una app JNLP
./run.sh bash                 # shell nel container
```

`run.sh` autorizza il tuo utente sul server X con
`xhost +SI:localuser:$(id -un)` e revoca l'autorizzazione all'uscita. È molto
più stretto di `xhost +local:` — non usare quest'ultimo.

I file di lavoro (`.dcm`, `.ccf`, ricevute) stanno in `./data/workspace`,
visibili dall'host.

## Persistenza

| Percorso container | Contenuto |
|---|---|
| `/data/home` | home dell'utente: cache e impostazioni OpenWebStart, installazioni e banche dati locali delle app JNLP |
| `/data/desktop-telematico` | installazione scrivibile, necessaria perché l'app si autoaggiorna |
| `/data/workspace` | file `.dcm`, `.ccf`, ricevute |
| `/vendor` | sola lettura, i `.jnlp` scaricati a mano |

Per ripartire da zero con Desktop Telematico:
`rm -rf data/desktop-telematico`. Per azzerare la configurazione di
OpenWebStart:
`rm -rf data/home/.config/icedtea-web data/home/.cache/icedtea-web`.

## Aggiornare Desktop Telematico

Il download avviene a runtime, quindi non serve ricostruire l'immagine: prendi
URL e checksum da
`https://telematici.agenziaentrate.gov.it/Main/Desktop.jsp`, mettili nel `.env`
come `DT_URL` e `DT_SHA256`, poi:

```bash
docker compose run --rm ade install-desktop-telematico --force
```

## Build locale

La sezione `build:` del `docker-compose.yml` è attiva. `image` fa però da
riferimento per il pull **e** da tag per la build, quindi va valorizzato in
entrambi i comandi: costruire senza `IMAGE` sovrascrive `frugan/ade:latest`
nella cache locale, e da quel momento l'immagine pubblicata non viene più
scaricata.

```bash
IMAGE=ade:local docker compose build
IMAGE=ade:local ./run.sh
```

Se è già successo, `docker rmi frugan/ade:latest` rimette le cose a posto.

Per una build senza rete verso l'esterno, metti in `vendor/` il `.deb` di
OpenWebStart (`OpenWebStart_linux_*.deb`) e l'archivio Zulu
(`zulu8*fx*linux_x64.tar.gz`): l'installer li preferisce al download. Il
checksum del `.deb` viene verificato comunque.

## Se qualcosa non parte

**`cannot open display`.** `DISPLAY` nel `.env` deve coincidere con quello
dell'host. Su Wayland verifica che XWayland sia attivo; controlla anche
`userns-remap` o `DOCKER_USER`.

**Finestre nere o dialoghi vuoti.** Il rimedio è `shm_size`, già a 512m.

**Desktop Telematico si chiude subito.** Avvialo da shell per vedere l'errore:
`./run.sh bash`, poi `cd $DT_HOME && ./DesktopTelematico`. L'errore storico su
Debian è `libwebkitgtk-1.0`, non più nei repository; le versioni recenti usano
WebKit2, già installato.

**Il JNLP non parte o si apre e muore.** Apri le impostazioni di OpenWebStart
(`./run.sh bash`, poi `/opt/OpenWebStart/OpenWebStartSettings`) e controlla che
nel JVM Manager compaia la JVM Zulu di `/opt/jvm`. Se manca, "Add local…" e
indica quella directory. I `.jnlp` dell'Agenzia sono notoriamente incompatibili
con IcedTea-Web e con le JVM moderne senza JavaFX.

**Il checksum di Desktop Telematico non torna.** È uscita una nuova versione:
vedi "Aggiornare Desktop Telematico".

## Se lo esponi in rete

Il container conterrà credenziali fiscali e dichiarazioni firmate. Se un giorno
lo sposti su una base `jlesage/baseimage-gui` per l'accesso da browser (gli
script in `scripts/` restano identici: cambiano `FROM`, `CMD` e il mount X11),
**non esporlo direttamente**: reverse proxy con TLS e autenticazione davanti, e
preferibilmente raggiungibile solo da VPN o rete interna.

## Contributing

Per i tuoi contributi usa:

- [Conventional Commits](https://www.conventionalcommits.org)
- [Pull request workflow](https://docs.github.com/en/get-started/exploring-projects-on-github/contributing-to-a-project)

Vedi [CONTRIBUTING](.github/CONTRIBUTING.md) per le linee guida complete.

## Sponsor

[<img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" width="200" alt="Buy Me A Coffee">](https://buymeacoff.ee/frugan)

## Licenza

(ɔ) Copyleft 2026 [Frugan](https://frugan.it).
[MIT](https://choosealicense.com/licenses/mit/), vedi il file [LICENSE](LICENSE).

Il packaging in questo repository è MIT. Il software dell'Agenzia non è incluso
né ridistribuito, ed è distribuito per l'uso da parte del contribuente e dei
soggetti abilitati: resta soggetto alle sue condizioni d'uso.
