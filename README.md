## homematic-hue tcl 0.17

* neuer json-scanner
* Ergänzung neuer Funktionalität
* Fehlerbehebung

Da tcl 8.2 im Funktionsumfang deutlich hinterherhinkt, habe ich die fehlenden Funktionen wie regep -all und lset umgeschrieben. Bei tcl >= 8.5 (z. B. macOS high sierra) werden die eingebauten Funktionen genommen, bei der CCU (tcl Version 8.2) habe ich die Funktionen nachgebaut.
Getestet wurde alles auf einem Mac sowie auf der Raspimatic, da ich keine CCU2 mehr nutze.

## homematic-hue

Steuern von Philips Hue Lights mit tcl und der Homematic CCU2

Es funktioniert ohne CUXD und curl, sondern einfach per Socket.

### Installation

Kopieren des Ordnerinhaltes per ssh auf die CCU/Raspimatic. Ich habe es kopiert nach /usr/local/scripts/hue, aber der Ordner ist letztendlich egal. Die includes sind nicht hardkodiert, sondern liegen im gleichen Ordner.

    > scp -r local_dir/hue ccu:/usr/local/scripts
    > ssh ccu
    > cd /usr/local/scripts/hue

### config.tcl

In die config.tcl kommt die IP der bridge sowie der angelegte User-Name.
Die API der Hue-Lights ist [super dokumentiert](http://www.developers.meethue.com/philips-hue-api).

    set ip "192.168.1.17"
    set user "newdeveloper"

### Systemanforderungen

Alle Scripts funktionieren auf einem Mac, auf einen Linux-Rechner oder der CCU2 (Windows mit tcl?), da hier bereits tcl installiert ist.

## CCU2/Raspimatic

**Die Scripts, die mit ccu_ anfangen, laufen nur auf der CCU, da hier Systemvariablen angelegt werden.**

### ccu_helper.tcl

Hier sind die Funktionen zum Anlegen und Löschen von Systemvariablen drin.

### ccu\_read_hue.tcl

Liest die Lampen aus.

*   Parameter 1 (Default 1) ... Nummer der Lampe
*   Parameter 2 (Default hue) ... prefix der Systemvariable

ccu_read_hue.tcl 0 löscht die im Script angegebenen Systemvariablen der Lampen (hier 1 bis 12)
Ohne Parameter lautet die Lampennummer 1 und der prefix hue, die Variablen heißen also **hue1_** 
             
    > ./ccu_read_hue.tcl 0 ;# löscht alle hue1_, hue2_ und ... und hue12_Variablen, wer mehr Lampen hat, muss diese noch eintragen
    > ./ccu_read_hue.tcl 2 ;# liest Lampe 2 aus und kreiert die hue2_Variablen

## Hue-Api
**Die Namen der Funktionen sind an die Hue-Api angelehnt**
### hue.inc.tcl
Helperfunktionen für die Hue lamps (ohne curl, mit socket)

#1. Lights

### 1.1. getAllLights.tcl
Liest Info für alle Lampen aus.

    > ./setAllLights.tcl

Rückgabe ist ein Array **light(nr,attribut) = value**
### 1.2. getNewLights.tcl
Gibt den letzten Scan für neue Lampen und wenn gefunden die Nummern und Namen der neuen Lampen aus.

    > ./setNewLights.tcl


### 1.3. searchForNewLights.tcl
Startet einen Scan für neue Lampen.

    > ./searchForNewLights.tcl

Rückgabe (wenn erfolgreich): **[{"success":{"/lights":"Searching for new devices"}}]**


### 1.4. getLightAttributesAndState.tcl

Liest die Info für die Lampe mit der Nummer nr aus, Rückgabe ist ein Array mit den Infos

    > ./getLightAttributesAndState.tcl LampenNr

### 1.5. setLightAttributes.tcl

Ändert den Namen der Lampe. Die Lampennummer und der neue Namen müssen angegeben werden, gibt es den Namen schon, fügt die CCU eine laufende Nummer an

    > ./setLightAttributes.tcl LampenNr "Neuer Name"

### 1.6. setLightState.tcl

Die Lampennummer muss angegeben werden, alle anderen Parameter sind optional

     > ./setLightState.tcl LampenNr [on ... true-false] \
      [bri ... 0 - 255] [hue ... 0 - 65535] [sat ... 0 - 255] \
      [transitiontime ... x * 100 ms] [effect ... none, colorloop] \
      [alert ... none, select, lselect] [ct ... 153 - 500] [xy as list in  CIE color space]\
      [bri_inc -254 - 254] [sat_inc -254 - 254] \
      [hue_inc -65534  - 65534 ] [ct_inc -65534 - 65534] \
      [xy_inc as list in  CIE color space] 

Jetzt kann mann auch mit 

     ./setLightState.tcl LampenNr on|off
     
die Lampen ein- bzw. ausschalten. on|off funtioniert immer als letzter Parameter.

#2. Groups#

### 2.1. getAllGroups.tcl
Liest Infos für alle Gruppen aus.

    > ./getAllGroups.tcl

Rückgabe ist ein Array **group(nr,attribut) = value**
### 2.2. createGroup.tcl
Kreiert neue Gruppe mit Namen und Lampenliste

    > ./createGroup.tcl "Namen der Gruppe" 1,3,8

Rückgabe ist eine Success oder eine Error-Meldung

### 2.3. getGroupAttributes.tcl
Liest Infos für die Gruppe mit der Gruppennumme GroupNr raus.

    > ./getGroupAttributes.tcl GoupNr

Rückgabe ist ein Array **group(attribut) = value**
### 2.4. setGroupAttributes.tcl

Ändert den Namen der der Gruppe mit GroupNr oder die Lampenzuordnung. Es kann der Namen der Gruppe, die Lampenzuordnung oder beides geändert werden. Vor dem neuen Namen namen setzen, vor den Lampen lights. Die Reihenfolge ist egal.

    > ./setGroupAttributes.tcl GroupNr [namen "Neuer Name"] [lights 1,3,5]

### 2.5. setGroupState.tcl

Alle Parameter außer der GruppenNr sind optional, das gleiche wie bei setLightState.tcl, nur für angelegte Gruppen, die Gruppe 0 sind alle Lampen, zusätzlicher Parameter: [scene id einer Szene als String]

     > ./setGroupState.tcl GruppenNr [on ... true-false] [bri ... 0 - 255] [hue ... 0 - 65535] [sat ... 0 - 255] [transitiontime ... x * 100 ms] [effect ... none, colorloop] [alert ... none, select, lselect] [ct ... 153 - 500] [xy as list in  CIE color space] [scene scene-ID]

#4. Scenes#

### 4.1. getAllScenes.tcl

     > ./getAllScenes.tcl
     
Rückgabe ist ein scenes-array, Index ist die Scene-ID, Inhalt eine Liste mit Namen der Scene, der eingeschlossenen Lampen sowie ob die Scene active ist.

#5. Capabilities

### 5.1. getCapabilities.tcl

     > ./getCapabilities.tcl
     
© fiveyears 2017
