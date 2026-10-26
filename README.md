# win-debloat

Script PowerShell per fare il debloat di PC **Windows 10/11 Pro** aziendali, pensato per macchine **joinate a un dominio** dove stampa e servizi di dominio devono restare intatti.

## Cosa fa

- Rimuove app preinstallate inutili (Bing News/Meteo, Xbox, Solitaire, Clipchamp, Teams consumer, Copilot, app sponsorizzate tipo CandyCrush/TikTok/Spotify, ecc.), sia dagli utenti esistenti sia dal provisioning, così non tornano per i nuovi profili di dominio.
- Applica policy di registro compatibili con Windows Pro (telemetria al minimo, ID pubblicitario, consumer features, widget, Copilot, Recall, suggerimenti di ricerca web).
- Disabilita pochi servizi inutili in ufficio (DiagTrack, Xbox, geolocalizzazione, ecc.).
- Crea un punto di ripristino e scrive un log in `C:\ProgramData\Debloat\logs`.

## Cosa NON tocca (mai)

- **Stampa**: Spooler, PrintNotify, WSD, ecc.
- **Dominio/autenticazione**: Netlogon, Workstation, Kerberos, GPO client, W32Time, ecc.
- **Rete, sicurezza, aggiornamenti**: Defender, Windows Update, BITS, firewall, RDP, ecc.
- App di sistema: Store, Calcolatrice, Foto, Blocco note, Terminale, Paint, Strumento di cattura, Edge/WebView2, `*Print*`, Outlook nuovo, app Office.

Nel codice c'è una lista `$ProtectedServices` e una guardia: se per errore aggiungi un servizio protetto a quelli da disabilitare, lo script si ferma prima di fare qualsiasi cosa. A fine esecuzione verifica anche che Spooler, Netlogon, LanmanWorkstation, gpsvc e W32Time non siano disabilitati.

## Uso

Apri PowerShell **come amministratore**:

```powershell
# 1. Prova a vuoto: mostra cosa farebbe senza modificare nulla
.\Debloat-Windows.ps1 -WhatIf

# 2. Esecuzione reale
.\Debloat-Windows.ps1

# Opzioni
.\Debloat-Windows.ps1 -SkipRestorePoint
.\Debloat-Windows.ps1 -RemoveOneDrive      # OFF di default
```

Se la policy di esecuzione blocca lo script:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Debloat-Windows.ps1
```

## Consigli per l'uso in azienda

1. **Testa su un PC pilota** (idealmente già nel dominio) e verifica stampa, accesso a share di rete e login di un utente di dominio.
2. Su Pro `AllowTelemetry=0` non ha effetto: si usa `1` (Required). Lo `0` funziona solo su Enterprise/Education.
3. Le **GPO di dominio hanno la precedenza** sulle policy locali impostate dallo script. Se gestisci già queste impostazioni via GPO, non c'è conflitto.
4. Le app Appx rimosse si possono reinstallare dal Microsoft Store o con `winget`.
5. Per personalizzare, modifica le liste `$AppsToRemove`, `$ServicesToDisable` e `$ProtectedApps` in cima allo script.

## Distribuzione

Puoi lanciarlo da GPO (script di avvio), Intune/Endpoint Manager o in fase di imaging/deploy del PC prima del join al dominio.

## Disclaimer

Usalo a tuo rischio e prova sempre prima con `-WhatIf`. Rilasciato con licenza MIT.
