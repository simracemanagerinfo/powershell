# PowerShell Customization — edizione pubblica

Profilo e temi per **PowerShell 7 + Windows Terminal**, installabili per singolo utente senza copiare configurazioni private, token, SSH o impostazioni aziendali. Il progetto rimane indipendente dal repository personale dell'autore.

## Installazione rapida (Windows 10 22H2 / Windows 11)

In PowerShell (anche Windows PowerShell 5.1) esegui:

```powershell
git clone https://github.com/simracemanagerinfo/powershell.git
cd powershell
.\setup.ps1
```

In alternativa puoi scaricare lo ZIP del repository da GitHub, estrarlo e lanciare `setup.ps1` dalla cartella estratta. Per scaricare aggiornamenti futuri sarà però preferibile il clone Git.

**Il primo setup non richiede domande:** seleziona tutte le cinque grafiche e lascia OpenShift/Stern disattivato. In automatico prova a installare ciò che manca: PowerShell 7, Windows Terminal, Oh My Posh, moduli PSReadLine/Terminal-Icons, font Meslo Nerd Font e compilatore portable per i launcher (quando GCC non è disponibile). Il codice usa `winget`/PSGallery e tenta operazioni in ambito **CurrentUser**, senza chiedere elevazione.

**Limiti aziendali:** Git (per il clone), WinGet/Microsoft App Installer e l'accesso alle fonti degli strumenti sono prerequisiti esterni. Policy aziendali, proxy, antivirus o restrizioni su MSIX/font/script possono impedire l'installazione senza diritti o intervento IT. In quel caso lo script deve segnalare l'errore, non aggirare le restrizioni. Con `-SkipDependencies` si installano soltanto componenti già disponibili, utile per chi prepara l'ambiente in modo gestito.

Al termine, **chiudi tutte le finestre di Windows Terminal e riaprilo**: finché rimane un processo attivo può continuare a usare i profili precedenti. Se necessario, da un prompt esterno a Windows Terminal si può chiudere con `taskkill /F /IM WindowsTerminal.exe` **dopo aver salvato il lavoro nelle sessioni aperte**.

## I cinque launcher

Dal menu Start, sotto **PowerShell Customization Public**, puoi aprire:

- **Matrix GPT.exe** — Matrix Neon, verde;
- **Cyber Glass.exe** — sfondi a rotazione, trasparenze;
- **Neon Dev.exe** — effetto neon per lo sviluppo;
- **Stern HUD.exe** — grafica log, utilizzabile anche senza OpenShift/Stern CLI;
- **Claude Code.exe** — palette terracotta e crema, selettore dei progetti e avvio di Claude CLI.

Sono creati localmente in `%LOCALAPPDATA%\PowerShellCustomizationPublic\launchers`. Il compilatore è usato come toolchain portable nella cache dell'app, senza modificarne il PATH globale.

Claude CLI **non viene installata né autenticata** da questo progetto. Se non è presente nel PATH, il launcher lo segnala e rimani nella shell PowerShell. Non esistono token, URL privati o configurazioni Claude predefinite.

### Cartelle recenti di Claude

Aprendo `Claude Code.exe` compare il menu degli ultimi 15 progetti (`1`–`15`), con `N` per un nuovo percorso, `B` per sfogliare, `C` per la directory corrente e `Q` per annullare. Claude parte solo dopo la scelta della directory.

Da una normale PowerShell già personalizzata:

```powershell
claudeCode                        # apri subito nella directory corrente
claudeCode -Path 'C:\workspace\mio-progetto'
claudeCode -Choose                # scegli dalla cronologia
```

I percorsi recenti restano **solo nel computer**, in `%LOCALAPPDATA%\PowerShellCustomizationPublic\claude-project-history.json`: non sono pubblicati nel repo, non vengono cancellati da `setup.ps1`.

## Installazione conservativa e isolamento

Il runtime pubblico si trova in `%LOCALAPPDATA%\PowerShellCustomizationPublic`; il fragment Windows Terminal è sotto:

```text
%LOCALAPPDATA%\Microsoft\Windows Terminal\Fragments\PowerShellCustomizationPublic\powershell-customization-public.json
```

Il setup **non scrive direttamente `settings.json`** di Windows Terminal. Ogni profilo pubblico ha un GUID distinto dai profili del repository personale. Copia soltanto file pubblici e rigenera i file gestiti quando cambiano; conserva lo sfondo corrente, le scelte di installazione e il file locale della cronologia.

Il file `Documents\PowerShell\Microsoft.PowerShell_profile.ps1` esistente non viene azzerato: sono aggiornate soltanto le righe tra `# >>> powershell-customization managed >>>` e `# <<< powershell-customization managed <<<`. Prima di modificarlo viene creato un backup nel runtime pubblico. Altri comandi, alias e personalizzazioni fuori dal blocco sono preservati.

**Installazioni pubbliche più vecchie:** le voci legacy aggiunte direttamente al `settings.json` non vengono eliminate automaticamente, per non cancellare profili dell'utente. Se sono visibili vecchi profili doppi, occorre valutarli prima di rimuoverli. Il vecchio runtime condiviso non viene cancellato.

## Aggiornare / riparare

Da PowerShell nella root del clone:

```powershell
git pull --ff-only
.\setup.ps1
.\doctor.ps1
```

`setup.ps1` è eseguibile più volte: aggiorna i file solo se cambiati e riusa launcher già compilati quando il sorgente non è cambiato. Per riconfigurare la scelta dei launcher oppure attivare OpenShift/Stern, esegui `setup.ps1 -Reconfigure`.

Per aggiungere soltanto il launcher Claude Code alle preferenze salvate:

```powershell
.\setup.ps1 -AddLauncher 'Claude Code'
```

Per sincronizzare e ricaricare soltanto i command PowerShell, usa `reload` nella shell già aperta. **`reload` non rigenera i profili di Windows Terminal**: usa `setup.ps1` per temi, shader, asset e launcher. Il comando `reload` usa `source-root.txt` nel runtime pubblico per trovare il repository installato.

## OpenShift / Stern (facoltativo)

Con `-Reconfigure` puoi scegliere se abilitare i comandi operativi per OpenShift/Stern. Per la feature possono servire `oc.exe`, `stern.exe` e una configurazione JSON locale. Nessun cluster, namespace o indirizzo aziendale è precompilato e non ci sono workaround per la VPN o le policy di sicurezza. `Stern HUD.exe` resta un semplice tema grafico anche senza queste CLI.

## Estendere comandi e configurazioni

I comandi autonomi si scrivono in `commands\*.ps1`; `reload` sincronizza le nuove funzioni senza modificare `profiles/common/runtime.ps1`. Per impostazioni personali locali usa `%LOCALAPPDATA%\PowerShellCustomizationPublic\profile.local.ps1`, mai Git.

Non pubblicare token, file `*.local.ps1`, credenziali, impostazioni SSH o URL interni. La pipeline GitHub Actions esegue controlli sintattici, JSON, collegamenti dei profili, cronologia e una installazione conservativa su un runner Windows.

> **Nota compatibilità:** la parte grafica è destinata a Windows Terminal su Windows. Linux e macOS richiedono un adattamento dell'host del terminale.

La parte pubblica utilizza anche un modulo con nome distinto, `PowerShellCustomizationPublic.psm1`. I comandi condivisi (`reload`, `show`, ecc.) possono comunque sovrapporsi se si installano sia il repository personale sia quello pubblico **nello stesso profilo PowerShell**: la precedenza dipende dall'ordine di caricamento. I colleghi che installano solo la versione pubblica non hanno questa sovrapposizione.
