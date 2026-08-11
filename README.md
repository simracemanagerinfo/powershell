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
- temi Matrix Neon, Cyber Glass e Neon Dev
- pixel shader per Windows Terminal

Non installa JDK, Maven, NVM, CMake, BusyBox o altre toolchain da sviluppatore: non sono necessarie per la personalizzazione PowerShell.

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

I profili grafici vengono distribuiti tramite i **JSON Fragments** di Windows Terminal sotto:

```text
%LOCALAPPDATA%\Microsoft\Windows Terminal\Fragments\PowerShellCustomization
```

Non viene sostituito il `settings.json` personale dell'utente.

## OpenShift / Stern opzionale

Durante l'installazione viene chiesto:

```text
Ti serve il supporto OpenShift / Stern? [S/N]
```

Se la risposta è `N`, non vengono installati Stern, `oc.exe`, il profilo Stern HUD o le funzioni OpenShift.

Se la risposta è `S`:

- se `oc.exe` esiste già, viene mostrato e si può scegliere se usarlo;
- altrimenti viene richiesto un link diretto a `oc.exe` oppure un path locale;
- Stern viene installato solo come feature opzionale;
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
- configurazioni locali OpenShift.

I file `*.local.ps1` e `*.local.json` sono ignorati da Git.

## Portabilità

La parte PowerShell / Oh My Posh è pensata per essere portabile anche su macOS e Linux. Le integrazioni specifiche di Windows Terminal, come JSON Fragments e pixel shader, sono invece Windows-specifiche e richiederanno un adattatore per il terminale scelto sugli altri sistemi.
