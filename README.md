## homematic-hue tcl 0.17

* neuer json-scanner in C
* Ergänzung neuer Funktionalität
* Fehlerbehebung

Da tcl 8.2 im Funktionsumfang deutlich hinterher hinkt, habe ich die fehlenden Funktionen wie regep -all und lset umgeschrieben. Bei tcl \>= 8.5 (z. B. macOS high sierra) werden die eingebauten Funktionen genommen, bei der CCU (tcl Version 8.2)  habe ich ursprünglich die Funktionen nachgebaut. Da ich aber weitere Funktionen implementieren wollte, habe ich eine Tcl-Library in C geschrieben  und diese dann kompiliert. Es liegen zwei Versionen vor **libTools.dylib** für den Mac und **libTools.so** für den Raspi. 
Getestet wurde alles auf einem Mac sowie auf der Raspimatic, da ich keine CCU2 mehr nutze.

## homematic-hue

Steuern von Philips Hue Lights mit tcl und der Homematic CCU2

Es funktioniert ohne CUXD und curl, sondern einfach per Socket.

## Neue Funktionen

### setLightRgb.tcl

Schaltet die Lampe bei Bedarf an, setzt die Farbe auf den RGB-Wert, optional kann noch die Brillianz und die Sättigung angegeben werden.

    > ./setLightRgb.tcl Lampennummer/Name rgb [bri] [sat]
    > ./setLightRgb.tcl S1 red
    > ./setLightRgb.tcl 7 0000FF 254 200
Die Funktion nimmt sowohl die Lightnumber als auch den Namen. RGB kann als Hex-Zahl (#121212, 121212, 0x121212) oder als Farbname angegeben werden, Brillianz und Sättigung optional 0 ... 254. Es liegt eine Html-Datei [Table of Colors](./Table\ of\ Colors.html) mit den verwendeten Farbnamen bei. Intern habe ich die Color-Umrechnung nachgebaut mit Gamma-Korrektur zu einem x,y-Paar und es werden auch nur die x,y-Werte gesetzt, die im Gamut der Lampe enthalten sind.

### LightState ... tcl

Diese Funktionen speichern einen aktuellen Zustand einer Lampe in einem String auf der Festplatte bei nicht-raspi-Systemen (.state2_(Name).txt, bei der Raspi (und CCU2) in einer Systemvariable "stateNr" also z. B. state1. Wenn z. B. die Haustüre länger als 5 Minuten offen steht, wird bei mir eine Flurlampe rot-geschaltet, geht die Tür wieder zu, dann wird der alte Zustand wieder hergestellt.

#### LightStateSave.tcl

Speichert den Zustand einer Lampe.

	> LightStateSave.tcl S1
	> LightStateSave.tcl 6

#### LightStateRead.tcl

Liest den Zustand einer Lampe und setzt die Lampe.

	> LightStateRead.tcl S1
	> LightStateRead.tcl 6

#### LightStateDelete.tcl

Löscht den gespeicherten Zustand einer Lampe (0 löscht alle gespeicherten Zustände)

	> LightStateDelete.tcl S1
	> LightStateDelete.tcl 6
	> LightStateDelete.tcl 0

### getLightAttributesAndState.tcl und getAllLights.tcl 

Beide Funktionen haben jetzt eine lange und kurze (standard) Ausgabe. Die lange kann mit dem zusätzlichen Parameter **l** erreicht werden. In der kurzen Version erscheint jetzt auch der RGB-Wert der Lampe hexadezimal, in der langen Version auch das Gamut (A, B oder C). Statt Lampennummer kann auch der Name verwendet werden.

	> getLightAttributesAndState.tcl S1
	> getLightAttributesAndState.tcl 6 l
	> getAllLights.tcl
	> getAllLights.tcl l

## Installation

Kopieren des Ordnerinhaltes per ssh auf die CCU/Raspimatic. Ich habe es kopiert nach /usr/local/scripts/hue, aber der Ordner ist letztendlich egal. Die includes sind nicht hardkodiert, sondern liegen im gleichen Ordner.

	> scp -r local_dir/hue ccu:/usr/local/scripts
	> ssh ccu
	> cd /usr/local/scripts/hue

### config.tcl

In die config.tcl kommt die IP der bridge sowie der angelegte User-Name. Neu ist die Anzahl der Lampen!
Die API der Hue-Lights ist [super dokumentiert][1].

	set ip "192.168.1.17"
	set user "newdeveloper"
	set lightcount 12

### Systemanforderungen

Alle Scripts funktionieren auf einem Mac, auf einen Linux-Rechner oder der CCU2 (Windows mit tcl?), da hier bereits tcl installiert ist.

## CCU2/Raspimatic

**Die Scripts, die mit ccu\_ anfangen, laufen nur auf der CCU, da hier Systemvariablen angelegt werden.**

### ccu\_helper.tcl

Hier sind die Funktionen zum Anlegen und Löschen von Systemvariablen drin.

### ccu\_read\_hue.tcl

Liest die Lampen aus.

*   Parameter 1 (Default 1) ... Nummer der Lampe
*   Parameter 2 (Default hue) ... prefix der Systemvariable

ccu\_read\_hue.tcl 0 löscht die im Script angegebenen Systemvariablen der Lampen (hier 1 bis 12)
Ohne Parameter lautet die Lampennummer 1 und der prefix hue, die Variablen heißen also **hue1\_** 

	> ./ccu_read_hue.tcl 0 ;# löscht alle hue1_, hue2_ und ... und hue12_Variablen, wer mehr Lampen hat, muss diese noch eintragen
	> ./ccu_read_hue.tcl 2 ;# liest Lampe 2 aus und kreiert die hue2_Variablen

## Hue-Api
**Die Namen der Funktionen sind an die Hue-Api angelehnt**
### hue.inc.tcl
Helperfunktionen für die Hue lamps (ohne curl, mit socket)

# 1. Lights

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

# 2. Groups

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

# 4. Scenes

### 4.1. getAllScenes.tcl

	 > ./getAllScenes.tcl
Rückgabe ist ein scenes-array, Index ist die Scene-ID, Inhalt eine Liste mit Namen der Scene, der eingeschlossenen Lampen sowie ob die Scene active ist.

# 5. Capabilities

### 5.1. getCapabilities.tcl

	 > ./getCapabilities.tcl
© fiveyears 2017

[1]:	http://www.developers.meethue.com/philips-hue-api

