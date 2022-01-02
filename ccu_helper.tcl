set regafail 0
# state is better then variable, because it changes the timestamp!!
if {[catch {load tclrega.so} error]} {
  set regafail 1
}
proc testRega { } {
  global regafail
  return $regafail
}

proc remoteRegascript { script } {
  #set script [string map {\" \\\"} $script]
  set script [string map {\[ \\\[} $script]
  set script [string map {\] \\\]} $script]
  #set script [string map {; \\;} $script]
  set script "load tclrega.so;array set values \[rega_script {$script}];puts \[array get values\];"
  #puts $script
  return [exec echo $script | ssh ccu tclsh]
  #puts [exec echo 'load tclrega.so;array set values \[rega_script {var k = dom.GetObject ("Kueche Schalter Kuehlschrank").State();}\] ;puts \[array get values\]' | ssh ccu tclsh]
}

proc runP {progName} {
 set regascript {
    var o = dom.GetObject('$progName');
      Name = '$progName';
      DPInfo = o.DPInfo();
      ValueSubType = o.ValueSubType();
      ValueType = o.ValueType();
      ValueMin = o.ValueMin();
      ValueMax = o.ValueMax();
      ValueName0 = o.ValueName0();
      ValueName1 = o.ValueName1();
      ValueUnit = o.ValueUnit();
      Variable = o.Variable();
      VarType = o.VarType();
      State = o.State();
      ValueList = o.ValueList();
      Protokoll = o.DPArchive();
      Channel = o.Channel();
      Variable = o.Variable();
      State = o.State();
      ts = o.Timestamp();
   }
  array set result [remoteRegascript [subst $regascript]]
  parray result
}
proc runProg {progName} {
  set regascript {
    var o = dom.GetObject('$progName');
    if (o) {
      o.ProgramExecute();
    } else {
      Write('Prog not found!');
    }
  }
  array set result [remoteRegascript [subst $regascript]]
  unset result(o)
  unset result(httpUserAgent)
  unset result(sessionId)
  # return [array get result]
  return $result(STDOUT)
}

proc infoVariable {name } {
  global regafail
  if { $regafail } {
    return  [list error "Rega not loaded! This may not be a ccu or raspimatic."]
  }
  set rega_script  "var o = dom.GetObject ('$name');"
  append rega_script {
  if ( o ) {
      Name = '$name';
      DPInfo = o.DPInfo();
      ValueSubType = o.ValueSubType();
      ValueType = o.ValueType();
      ValueMin = o.ValueMin();
      ValueMax = o.ValueMax();
      ValueName0 = o.ValueName0();
      ValueName1 = o.ValueName1();
      ValueUnit = o.ValueUnit();
      Variable = o.Variable();
      VarType = o.VarType();
      State = o.State();
      ValueList = o.ValueList();
      Protokoll = o.DPArchive();
      Channel = o.Channel();
      Variable = o.Variable();
      State = o.State();
      ts = o.Timestamp();
  } else {
    err_text = "Objekt nicht gefunden!";
  }
}
  array set result [rega_script [subst $rega_script] ]
  unset result(STDOUT)
  unset result(o)
  unset result(httpUserAgent)
  unset result(sessionId)
  return [array get result]
}

proc deleteVariablen {pre} {
  global regafail
  if { $regafail } {
    return  [list error "Rega not loaded! This may not be a ccu or raspimatic."]
  }
  deleteVariable "${pre}_alert"
  deleteVariable "${pre}_colormode"
  deleteVariable "${pre}_effect"
  deleteVariable "${pre}_modelid"
  deleteVariable "${pre}_name"
  deleteVariable "${pre}_type"
  deleteVariable "${pre}_xy"
  deleteVariable "${pre}_swversion"
  deleteVariable "${pre}_uniqueid"
  deleteVariable "${pre}_bri"
  deleteVariable "${pre}_sat"
  deleteVariable "${pre}_hue"
  deleteVariable "${pre}_ct"
  deleteVariable "${pre}_on"
  deleteVariable "${pre}_pointsymbol_1"
  deleteVariable "${pre}_pointsymbol_2"
  deleteVariable "${pre}_pointsymbol_3"
  deleteVariable "${pre}_pointsymbol_4"
  deleteVariable "${pre}_pointsymbol_5"
  deleteVariable "${pre}_pointsymbol_6"
  deleteVariable "${pre}_pointsymbol_7"
  deleteVariable "${pre}_pointsymbol_8"
  deleteVariable "${pre}_reachable"

}

proc deleteVariable {name } {
  global regafail
  if { $regafail } {
     return  [list error "Rega not loaded! This may not be a ccu or raspimatic."]
  }
  set rega_script  "var o = dom.GetObject ('$name');"
  append rega_script {
  object  o_SysVars = dom.GetObject (ID_SYSTEM_VARIABLES);
  if ( o ) {
    rem = o_SysVars.Remove(o);
    del = dom.DeleteObject(o);
  } else {
    err_text = "Objekt '$name' nicht gefunden!";
  }
}
  array set result [rega_script [subst $rega_script]] 
  unset result(STDOUT)
  unset result(o)
  unset result(o_SysVars)
  unset result(httpUserAgent)
  unset result(sessionId)
  return [array get result]
}

proc setVariable {name {info ""} {type int} {ValueMin 0} {ValueMax 65000} {ValueUnit ""} {Channel 65535} \
    {ValueName0 ""} {ValueName1 ""} {Protokoll "false"} \
    {ValueList ""} {Variable ""} {State ""} } {
  global regafail
  if { $regafail } {
     return  [list error "Rega not loaded! This may not be a ccu or raspimatic."]
  }
  set rega_script  "var o = dom.GetObject ('$name');"
  array set result [rega_script [subst $rega_script]]
  if {$result(o) == "null"}  {
   createVariable $name $info $type $ValueMin $ValueMax $ValueUnit $Channel $ValueName0 $ValueName1 $Protokoll $ValueList $Variable $State
  } {
    switch -glob  $type {
        lo* -
        ala* -
        enu* -
        int* {
            if { $State != "" } {
                append rega_script "o.State($State);\n"
            } elseif {$Variable != ""} {
                append rega_script "o.Variable($Variable);\n"
            }
       }
        default {
            if { $State != "" } {
                append rega_script "o.State('$State');\n"
            } elseif {$Variable != ""} {
                append rega_script "o.Variable('$Variable');\n"
            }
        }
    }
  }
  array set result [rega_script [subst $rega_script]] 
  unset result(STDOUT)
  unset result(o)
  #unset result(o_SysVars)
  unset result(httpUserAgent)
  unset result(sessionId)
  return [array get result]
}

proc createVariable {name {info ""} {type int} {ValueMin 0} {ValueMax 65000} {ValueUnit ""} {Channel 65535} \
    {ValueName0 ""} {ValueName1 ""} {Protokoll "false"} \
    {ValueList ""} {Variable ""} {State ""} } {
  global regafail
  if { $regafail } {
     return  [list error "Rega not loaded! This may not be a ccu or raspimatic."]
  }
  set rega_script  "var o = dom.GetObject ('$name');"
  append rega_script {
      object  o_SysVars = dom.GetObject (ID_SYSTEM_VARIABLES);
      if (! o ) {
        object o = dom.CreateObject (OT_VARDP);
        o.Name ('$name');
        o_SysVars.Add (o.ID());
      }
  }
    append rega_script "o.DPInfo('$info');\n"
    append rega_script "o.Channel($Channel);\n"
    append rega_script "o.ValueUnit('$ValueUnit');\n"
    append rega_script "o.DPArchive($Protokoll);\n"

    switch -glob  $type {
        lo* {
            append rega_script "o.ValueType(ivtBinary);\n"
            append rega_script "o.ValueSubType(istBool);\n"
            append rega_script "o.ValueName0('$ValueName0');\n"
            append rega_script "o.ValueName1('$ValueName1');\n"
            if { $State != "" } {
                append rega_script "o.State($State);\n"
            } elseif {$Variable != ""} {
                append rega_script "o.Variable($Variable);\n"
            }
       }
        ala* {
            append rega_script "o.ValueType(ivtBinary);\n"
            append rega_script "o.ValueSubType(istAlarm);\n"
            append rega_script "o.ValueName0('$ValueName0');\n"
            append rega_script "o.ValueName1('$ValueName1');\n"
            if { $State != "" } {
                append rega_script "o.State($State);\n"
            } elseif {$Variable != ""} {
                append rega_script "o.Variable($Variable);\n"
            }
        }
        enu* {
            append rega_script "o.ValueType(ivtInteger);\n"
            append rega_script "o.ValueSubType(istEnum);\n"
            append rega_script "o.ValueList('$ValueList');\n"
            if { $State != "" } {
                append rega_script "o.State($State);\n"
            } elseif {$Variable != ""} {
                append rega_script "o.Variable($Variable);\n"
            }
        }
        str* {
            append rega_script "o.ValueType(ivtString);\n"
            append rega_script "o.ValueSubType(istChar8859);\n"
            if { $State != "" } {
                append rega_script "o.State('$State');\n"
            } elseif {$Variable != ""} {
                append rega_script "o.Variable('$Variable');\n"
            }
       }
        default {
            append rega_script "o.ValueType(ivtFloat);\n"
            append rega_script "o.ValueSubType(istGeneric);\n"
            append rega_script "o.ValueMin($ValueMin);\n"
            append rega_script "o.ValueMax($ValueMax);\n"
            if { $State != "" } {
                append rega_script "o.State($State);\n"
            } elseif {$Variable != ""} {
                append rega_script "o.Variable($Variable);\n"
            }
        }
    }
  array set result [rega_script [subst $rega_script]] 
  unset result(STDOUT)
  unset result(o_SysVars)
  unset result(o)
  unset result(httpUserAgent)
  unset result(sessionId)
  return [array get result]
}

