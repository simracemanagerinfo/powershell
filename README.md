# PowerShell Customization

Configurazione pubblica e riutilizzabile per personalizzare **PowerShell 7** e **Windows Terminal** senza introdurre configurazioni personali o aziendali nel repository.

## Cosa installa

Core grafico:

- PowerShell 7
- Windows Terminal
- Oh My Posh
- PSReadLine
- Terminal-Icons
- MesloLGM Nerd Font
- temi Matrix Neon, Cyber Glass, Neon Dev e Stern HUD
- pixel shader per Windows Terminal
- asset PNG/ICO usati dai profili
- quattro launcher Windows compilati durante l'installazione

Non installa JDK, Maven, NVM, CMake, BusyBox o altre toolchain da sviluppatore non necessarie al terminale.

## Installazione

```powershell
git clone https://github.com/simracemanagerinfo/powershell.git
cd powershell
.\install.ps1
```

L'installer preferisce sempre operazioni **CurrentUser / user-level**. Se una dipendenza manca, chiede prima se tentare l'installazione per il solo utente corrente. Se questa fallisce, non tenta automaticamente un'installazione elevata.

Per verificare l'ambiente dopo l'installazione:

```powershell
.\doctor.ps1
```

## `reload`: sincronizza le modifiche senza reinstallare tutto

Dopo l'installazione il comando:

```powershell
reload
```

non si limita a rieseguire `$PROFILE`.

Prima individua il clone locale di questo repository, esegue `refresh.ps1` e sincronizza nel runtime i file PowerShell versionati che possono essere cambiati durante lo sviluppo, quindi ricarica il profilo corrente.

Questo permette, per esempio, di modificare o aggiungere una funzione nel repository e renderla disponibile nella shell corrente con un solo comando, senza rilanciare l'installer completo e senza ricompilare i launcher.

La prima volta `reload` cerca il repository corrente e alcune directory standard. Quando lo trova salva il percorso soltanto nel runtime locale:

```text
%LOCALAPPDATA%\PowerShellCustomization\source-root.txt
```

Da quel momento può sincronizzare il clone anche se `reload` viene eseguito da un'altra directory.

Se il repository è stato clonato in un path non standard, eseguire `reload` una volta dalla root del clone per registrarlo.

Per avere il vecchio comportamento e ricaricare soltanto `$PROFILE` senza sincronizzare nulla:

```powershell
reload -ProfileOnly
```

> Dopo l'aggiornamento da una versione precedente che non contiene ancora questa funzionalità, eseguire una volta `git pull` e `.\install.ps1`. Da quel momento i successivi aggiornamenti dei file runtime possono essere applicati con `reload`.

## Command plugin: copia, reload, enjoy

La directory:

```text
commands\
```

è riservata ai command PowerShell autoconsistenti.

Ogni file `commands\*.ps1` viene sincronizzato nel runtime da `reload` e poi caricato automaticamente dal profilo. Un command può quindi definire da solo:

- funzioni;
- alias;
- descrizioni per `show` / `aliases` tramite `$AliasDescriptions`.

Per aggiungere un command non è necessario modificare `common.ps1`.

Esempio:

```powershell
$AliasDescriptions['ciao'] = 'Esempio di command autoconsistente'

function ciao {
    param([string]$Nome = 'mondo')
    Write-Host "Ciao $Nome"
}
```

Salvare il file come:

```text
commands\ciao.ps1
```

e poi eseguire:

```powershell
reload
ciao Diego
```

Se il command richiede file di supporto, questi possono essere messi in `scripts/`, ad esempio:

```text
commands\mio-comando.ps1
scripts\mio-helper.ps1
scripts\mio-config.json
```

Dopo aver copiato i file nei rispettivi path basta ancora una volta:

```powershell
reload
```

Rimuovendo un `.ps1` da `commands/` e rilanciando `reload`, viene rimossa anche la relativa copia runtime.

Il contratto completo e un template sono documentati in `commands/README.md`.

## I quattro EXE

Gli eseguibili non sono versionati nel repository: vengono compilati localmente da `install.ps1` a partire dai sorgenti presenti in `launchers/src`.

Durante l'installazione viene chiesto quali launcher creare. Tutti e quattro sono selezionati per impostazione predefinita, ma è possibile installarne soltanto uno, due o tre. Con la selezione predefinita vengono creati:

```text
%LOCALAPPDATA%\PowerShellCustomization\launchers\Matrix GPT.exe
%LOCALAPPDATA%\PowerShellCustomization\launchers\Cyber Glass.exe
%LOCALAPPDATA%\PowerShellCustomization\launchers\Neon Dev.exe
%LOCALAPPDATA%\PowerShellCustomization\launchers\Stern HUD.exe
```

Nel menu Start, sotto **PowerShell Customization**, viene creato un collegamento per ciascun launcher selezionato; con la selezione predefinita sono quattro.

Eseguendo nuovamente `install.ps1 -Reconfigure` si può cambiare selezione. Gli EXE e i collegamenti precedentemente generati ma non più selezionati vengono rimossi.

Se sul PC sono già disponibili `gcc.exe` e `windres.exe`, vengono usati. Altrimenti il build scarica una toolchain LLVM-MinGW portable nella cache locale dell'applicazione e la usa senza installarla globalmente e senza aggiungerla al PATH dell'utente.

## PNG e ICO

I PNG e gli ICO originali sono inclusi e versionati sotto `assets/`. Durante l'installazione vengono copiati, senza rigenerarli, in:

```text
%LOCALAPPDATA%\PowerShellCustomization\assets\icons
%LOCALAPPDATA%\PowerShellCustomization\assets\backgrounds
%LOCALAPPDATA%\PowerShellCustomization\assets\watermarks
```

Cyber Glass mantiene un pool di sei wallpaper. L'installer inizializza `current.png` dal primo asset del pool e il launcher lo cambia prima di aprire Windows Terminal, evitando quando possibile di ripetere immediatamente lo stesso sfondo.

Gli EXE non sono inclusi nel repository: `install.ps1` li compila localmente usando le icone versionate e salva soltanto i risultati nell'area applicativa dell'utente.

## Il tuo profile non viene sovrascritto

Se `Documents\PowerShell\Microsoft.PowerShell_profile.ps1` esiste già, il suo contenuto viene preservato.

L'installer:

1. crea un backup sotto `%LOCALAPPDATA%\PowerShellCustomization\backups`;
2. rileva e mantiene la codifica del file esistente;
3. aggiunge o aggiorna soltanto il blocco compreso fra:

```text
# >>> powershell-customization managed >>>
...
# <<< powershell-customization managed <<<
```

Il resto del profile non viene modificato.

## Windows Terminal

I profili grafici vengono aggiunti direttamente al `settings.json` dell'installazione di Windows Terminal rilevata. L'installer crea prima un backup con timestamp e sostituisce esclusivamente i quattro profili e gli schemi colore gestiti dal progetto; gli altri profili e le altre preferenze restano invariati.

```text
%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json
```

Bootstrap, temi e shader vengono installati separatamente in `%LOCALAPPDATA%\PowerShellCustomization\terminal`.

Tutti i launcher aprono PowerShell nella cartella personale dell'utente (`%USERPROFILE%`), mai nella directory applicativa sotto AppData.

## OpenShift / Stern opzionale

Il **tema grafico Stern HUD e il relativo EXE vengono sempre installati**. Il supporto operativo OpenShift/Stern rimane invece opzionale.

Durante l'installazione viene chiesto:

```text
Ti serve il supporto OpenShift / Stern? [S/N]
```

Se la risposta è `N`, non vengono installati `stern.exe`, `oc.exe` o le funzioni OpenShift; `Stern HUD.exe` resta comunque disponibile come profilo grafico.

Se la risposta è `S`:

- se `oc.exe` esiste già, viene mostrato e si può scegliere se usarlo;
- altrimenti viene richiesto un link diretto a `oc.exe` oppure un path locale;
- Stern viene installato come feature opzionale;
- viene creato un `openshift.local.json` locale da personalizzare con cluster, namespace e servizi.

Endpoint, namespace e nomi di servizi reali **non appartengono al repository pubblico**.

Per cambiare scelta successivamente:

```powershell
.\install.ps1 -Reconfigure
```

## Dati esclusi dal repository pubblico

Non devono essere versionati:

- chiavi o configurazioni SSH personali;
- token e credenziali;
- URL di cluster aziendali;
- namespace e nomi di servizi aziendali;
- path specifici del singolo PC;
- configurazioni locali OpenShift;
- EXE compilati, output di build e cache della toolchain.

I file `*.local.ps1` e `*.local.json` sono ignorati da Git.

## Portabilità

La parte PowerShell / Oh My Posh è pensata per essere portabile anche su macOS e Linux. Le integrazioni specifiche di Windows Terminal, come profili, launcher Win32 e pixel shader, sono invece Windows-specifiche e richiederanno un adattatore per il terminale scelto sugli altri sistemi.
