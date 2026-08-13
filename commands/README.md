# Command plugin

Questa directory contiene command PowerShell autoconsistenti caricati automaticamente dal profilo.

## Installare un command

Copia il file `.ps1` dentro la directory `commands/` del clone locale del repository e poi esegui:

```powershell
reload
```

`reload` esegue `refresh.ps1`, copia i command nel runtime locale e ricarica il profilo. Non è necessario modificare `common.ps1`.

Esempio:

```text
powershell\
├── commands\
│   └── mio-comando.ps1
└── ...
```

```powershell
reload
mio-comando
```

## Contratto di un command

Un command deve limitarsi a **registrare** funzioni, alias e metadati quando viene caricato. Non deve eseguire automaticamente operazioni applicative, login, chiamate remote o modifiche al sistema durante il caricamento del profilo.

Template minimo:

```powershell
$AliasDescriptions['ciao'] = 'Esempio di command autoconsistente'

function ciao {
    param([string]$Nome = 'mondo')
    Write-Host "Ciao $Nome"
}
```

Se serve un alias:

```powershell
$AliasDescriptions['gsx'] = 'Mostra i servizi Windows'
Set-Alias gsx Get-Service
```

I file vengono caricati in ordine alfabetico per nome.

## File di supporto

Se un command ha bisogno di logica o configurazione separata, i file di supporto possono essere messi in `scripts/`.

Esempio da condividere con un collega:

```text
commands\mio-comando.ps1
scripts\mio-script.ps1
scripts\mio-config.json
```

Dopo aver copiato i file nei rispettivi path basta:

```powershell
reload
```

`refresh.ps1` copia automaticamente i file presenti in `commands/` e `scripts/` nel runtime sotto `%LOCALAPPDATA%\PowerShellCustomization`.

## Rimuovere un command

Elimina il relativo `.ps1` da `commands/` e lancia:

```powershell
reload
```

Il refresh rimuove anche la copia runtime del command, quindi alla successiva ricarica non viene più definito.

## Regola di portabilità

Un command destinato alla condivisione non dovrebbe dipendere da path personali, credenziali o nomi aziendali hardcoded. Eventuali dati specifici vanno tenuti in file di configurazione separati o in file locali esclusi da Git.
