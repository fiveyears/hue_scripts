namespace eval ::hue::groups {
  set loaded 1
  set lastLoad 1765872264
  catch {unset nameByIndex}; array set nameByIndex {17 Balcony 18 Garden 1 Sleep 200 {Guestbath TV} 19 Guestbath 2 spots 201 Elia 3 TV 202 {TV room} 4 newstrips 6 Hall 7 {Living Room} 8 PC-Switches 9 Elia 10 Béla 12 Bathroom 13 Kitchen}
  catch {unset typeByIndex}; array set typeByIndex {17 Room 18 Room 1 Room 200 Entertainment 19 Room 2 LightGroup 201 Entertainment 3 Room 202 Entertainment 4 LightGroup 6 Room 7 Room 8 Zone 9 Room 10 Room 12 Room 13 Room}
  catch {unset lightsByIndex}; array set lightsByIndex {17 {29 19} 18 {} 1 {7 5 4 8} 200 {20 22 28 21 26 25 27} 19 {32 31 30 28 27 26 25 24 23 22 21 20} 2 {27 20 22 28 21 26 25 32} 201 {11 13} 3 {10 18 1 6} 202 {6 1 10} 4 {23 24} 6 {2 3 9} 7 14 8 18 9 {13 15 11} 10 12 12 {} 13 {}}
  catch {unset indexByName}; array set indexByName {Garden 18 Sleep 1 Hall 6 PC-Switches 8 Béla 10 Bathroom 12 {Living Room} 7 Guestbath 19 Balcony 17 {Guestbath TV} 200 spots 2 TV 3 Elia 9 Kitchen 13 {TV room} 202 newstrips 4}
  catch {unset lightsByName}; array set lightsByName {Garden {} Sleep {7 5 4 8} Hall {2 3 9} PC-Switches 18 Béla 12 Bathroom {} {Living Room} 14 Guestbath {32 31 30 28 27 26 25 24 23 22 21 20} Balcony {29 19} {Guestbath TV} {20 22 28 21 26 25 27} spots {27 20 22 28 21 26 25 32} TV {10 18 1 6} Elia {13 15 11} Kitchen {} {TV room} {6 1 10} newstrips {23 24}}
}
