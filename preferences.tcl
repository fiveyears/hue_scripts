namespace eval hue::env {

    namespace export init vars reset help

    # ------------------------------------------------------------------
    # Configuration
    # ------------------------------------------------------------------
    variable MAX_BRIDGES 2
    variable DEFAULT_APPID "plug-switcher"
    variable scriptDir [file dirname [file normalize [info script]]]
    # ------------------------------------------------------------------
    # State variables
    # ------------------------------------------------------------------
    variable HUE_DIR
    variable PRODUCT
    variable DEVICENAME
    variable BUSYBOX ""
    variable bridge
    variable APPID
    variable CLIENTID
    variable CLIENTSECRET
    variable CLIENTBASE64
    variable config
    variable configPath
    variable tempFile
    variable ENVIRONMENT
    variable HOST
    variable all 0
    variable reset 0

    # config.hue.tcl
    variable user
    variable ip
    variable id
    variable resolveV1
    variable resolveV2
    variable bridgeNr

    # hue_remote_env
    variable ACCESS_TOKEN
    variable REFRESH_TOKEN
    variable EXPIRES_AT
    variable EXPIRES

    # ------------------------------------------------------------------
    # Platform detection
    # ------------------------------------------------------------------
    variable HAS_TCL86 [expr {$::tcl_version >= 8.6}]
    variable IS_MACOS 0
    catch {
        if {[string match "Darwin*" [exec uname -s]]} {
            set IS_MACOS 1
        }
    }

    # ------------------------------------------------------------------
    # Helpers
    # ------------------------------------------------------------------
    proc slurp {filename} {
        if {[file exists $filename]} {
            set f [open $filename r]
            set data [read $f]
            close $f
            return [string trim $data]
        }
        return ""
    }

    proc spit {filename data} {
        set f [open $filename w]
        puts $f $data
        close $f
    }

    proc ensureDir {path} {
        if {![file exists $path]} {
            file mkdir $path
        }
    }

    proc detectRaspMatic {} {
        if {[file exists "/VERSION"]} {
            set data [hue::env::slurp "/VERSION"]
            if {[regexp {PRODUCT=(.*)} $data -> val]} {
                return $val
            }
        }
        return ""
    }

    proc detectMacVersion {} {
        set version ""
        catch { set version [exec sw_vers -productVersion] }
        return "macos $version"
    }

    proc appExists {HUE_DIR appName} {
        set path [file join $HUE_DIR $appName]
        return [expr {[file exists $path] && [file isdirectory $path]}]
    }

    # ------------------------------------------------------------------
    # Base64 helper
    # ------------------------------------------------------------------
    if {$HAS_TCL86} {
        proc b64encode {str} {
            return [binary encode base64 $str]
        }
    } else {
        if {$IS_MACOS} {
            proc b64encode {str} {
                return [exec echo -n $str | base64 -b 0]
            }
        } else {
            proc b64encode {str} {
                return [exec echo -n $str | base64 -w 0]
            }
        }
    }

    # ------------------------------------------------------------------
    # app_env parser
    # ------------------------------------------------------------------
    proc parseAppEnv {APP_ENV} {
        variable CLIENTID
        variable CLIENTSECRET

        set CLIENTID ""
        set CLIENTSECRET ""

        set f [open $APP_ENV r]
        while {[gets $f line] >= 0} {
            if {[regexp {^([^#=]+)=(.*)$} $line -> key val]} {
                set key [string trim $key]
                set val [string trim $val]
                switch -- $key {
                    "CLIENTID"     { set CLIENTID $val }
                    "CLIENTSECRET" { set CLIENTSECRET $val }
                }
            }
        }
        close $f

        if {$CLIENTID eq "" || $CLIENTSECRET eq ""} {
            puts "Please fill in file '$APP_ENV'!"
            exit 1
        }
    }

    # ------------------------------------------------------------------
    # Help
    # ------------------------------------------------------------------
    proc help {} {
        variable MAX_BRIDGES

        puts ""
        puts "Hue environment helper (subcommands):"
        puts "  hue::env init  ?options?"
        puts "  hue::env vars"
        puts "  hue::env reset"
        puts "  hue::env help"
        puts ""
        puts "Options:"
        puts "  -a, --all            Set all=1"
        puts "  -r, --reset          Set reset=1"
        puts "  -h, --help           Show help"
        puts "  --bridge=N           Select bridge index"
        puts "  --appid=NAME         Select app directory under ./env"
        puts ""
    }

    # ------------------------------------------------------------------
    # Argument parser
    # ------------------------------------------------------------------
    proc parseArgs {argv} {
        variable MAX_BRIDGES
        variable DEFAULT_APPID
        variable HUE_DIR
        variable all
        variable reset
        variable bridge
        variable APPID

        set all 0
        set reset 0
        set foundBridge 0
        set foundApp    0

        foreach arg $argv {

            if {$arg in {"-h" "--help"}} {
                help
                exit 0
            }

            if {[regexp {^--bridge=([0-9]+)$} $arg -> N]} {
                if {$N >= 0 && $N < $MAX_BRIDGES} {
                    set bridge $N
                    set foundBridge 1
                } else {
                    puts "Invalid --bridge index: $N"
                }
                continue
            }

            if {[regexp {^--appid=(.+)$} $arg -> name]} {
                if {[appExists $HUE_DIR $name]} {
                    set APPID $name
                    set foundApp 1
                } else {
                    puts "--appid: app '$name' does not exist"
                }
                continue
            }

            if {$arg in {"-a" "--all"}} {
                set all 1
                continue
            }

            if {$arg in {"-r" "--reset"}} {
                set reset 1
                continue
            }

            # puts "Unknown parameter '$arg' ignored"
        }

        # ---- finalize bridge ----
        if {$foundBridge} {
            spit [file join $HUE_DIR ".bridge"] $bridge
        } else {
            set fbridge [slurp [file join $HUE_DIR ".bridge"]]
            if {
                $fbridge ne "" &&
                [string is integer -strict $fbridge] &&
                $fbridge >= 0 && $fbridge < $MAX_BRIDGES
            } then {
                set bridge $fbridge
            } else {
                set bridge 0
                spit [file join $HUE_DIR ".bridge"] $bridge
            }
        }

        # ---- finalize APPID ----
        if {$foundApp} {
            spit [file join $HUE_DIR ".appid"] $APPID
        } else {
            set fapp [slurp [file join $HUE_DIR ".appid"]]
            if {[appExists $HUE_DIR $fapp]} {
                set APPID $fapp
            } else {
                set APPID $DEFAULT_APPID
                spit [file join $HUE_DIR ".appid"] $APPID
            }
        }
    }

    # ------------------------------------------------------------------
    # init
    # ------------------------------------------------------------------
    proc init {args} {
        variable HUE_DIR
        variable PRODUCT
        variable DEVICENAME
        variable BUSYBOX
        variable bridge
        variable APPID
        variable CLIENTID
        variable CLIENTSECRET
        variable CLIENTBASE64
        variable config
        variable configPath
        variable tempFile
        variable ENVIRONMENT
        variable HOST

        variable user
        variable ip
        variable id
        variable resolveV1
        variable resolveV2
        variable bridgeNr

        variable ACCESS_TOKEN
        variable REFRESH_TOKEN
        variable EXPIRES_AT
        variable EXPIRES

        # Determine HUE_DIR
        variable scriptDir
        set HUE_DIR   [file join $scriptDir env]
        ensureDir $HUE_DIR

        # Detect system
        set PRODUCT [detectRaspMatic]
        if {$PRODUCT eq "raspmatic_rpi3"} {
            set DEVICENAME "Raspberry"
        } else {
            set PRODUCT [detectMacVersion]
            set DEVICENAME "Mac"
        }

        # BUSYBOX detection
        if {[file type /bin/ls] eq "link"} {
            set BUSYBOX [file readlink /bin/ls]
        } else {
            set BUSYBOX ""
        }

        # Parse arguments
        parseArgs $args

        # ------------------- Load app_env -------------------
        set APP_ENV [file join $HUE_DIR $APPID app_env]

        if {[file exists $APP_ENV]} {
            parseAppEnv $APP_ENV
            set CLIENTBASE64 [b64encode "$CLIENTID:$CLIENTSECRET"]
        } else {
            puts "Please fill in file '$APP_ENV'!"
            spit $APP_ENV "CLIENTID=\nCLIENTSECRET=\n"
            ensureDir [file join $HUE_DIR $APPID $bridge]
            exit 1
        }

        # ------------------- Load config.hue.tcl -------------------
        set config [file join $HUE_DIR $APPID $bridge "config.hue.tcl"]
        set configPath [file join $HUE_DIR $APPID]
        set tempFile [exec mktemp]

        ensureDir $configPath
        ensureDir [file join $configPath $bridge]

        if {![file exists $config]} {
            # Create default config
            set fh [open $config w]
            puts $fh {set user 0; set ip "0.0.0.0"; set id 0 ;# default values}
            close $fh

            set user 0
            set ip "0.0.0.0"
            set id 0
            set bridgeNr $bridge
            set resolveV1 ""
            set resolveV2 ""
        } else {
            namespace eval ::hue::env::conf {}

            namespace eval ::hue::env::conf "
                source [list $config]
            "

            foreach var {user ip id resolveV1 resolveV2 bridgeNr} {
                if {[info exists ::hue::env::conf::$var]} {
                    set $var [set ::hue::env::conf::$var]
                } else {
                    switch -- $var {
                        user      { set user 0 }
                        ip        { set ip "0.0.0.0" }
                        id        { set id 0 }
                        resolveV1 { set resolveV1 "" }
                        resolveV2 { set resolveV2 "" }
                        bridgeNr  { set bridgeNr $bridge }
                    }
                }
            }
        }

        # ------------------- Load hue_remote_env -------------------
        set REMOTE_ENV [file join $HUE_DIR $APPID $bridge "hue_remote_env"]

        set ACCESS_TOKEN ""
        set REFRESH_TOKEN ""
        set EXPIRES_AT ""
        set EXPIRES ""

        if {![file exists $REMOTE_ENV]} {
            set fh [open $REMOTE_ENV w]
            puts $fh "ACCESS_TOKEN="
            puts $fh "REFRESH_TOKEN="
            puts $fh "EXPIRES_AT="
            close $fh

        } else {
            set fh [open $REMOTE_ENV r]
            while {[gets $fh line] >= 0} {

                # key=value  (value may include comment)
                if {[regexp {^([^#=]+)=([^\#]*)} $line -> key val]} {
                    set key [string trim $key]
                    set val [string trim $val]

                    switch -- $key {
                        "ACCESS_TOKEN" {
                            set ACCESS_TOKEN $val
                        }
                        "REFRESH_TOKEN" {
                            set REFRESH_TOKEN $val
                        }
                        "EXPIRES_AT" {
                            # numeric timestamp
                            if {[regexp {([0-9]+)} $val -> ts]} {
                                set EXPIRES_AT $ts
                            }

                            # readable part
                            if {[regexp {\(([^)]+)\)} $line -> human]} {
                                set EXPIRES $human
                            }
                        }
                    }
                }
            }
            close $fh
        }

        # Set ENVIRONMENT path
        set ENVIRONMENT $REMOTE_ENV
        set HOST "https://api.meethue.com"

        # --------------------------------------------------------------
        # Export selected vars to global namespace (compatibility)
        # --------------------------------------------------------------
        set exportList {
            user
            ip
            id
            bridge
            all
            reset
            resolveV1
            resolveV2
            bridgeNr
            config
            configPath
            tempFile
            APPID
            ACCESS_TOKEN
            REFRESH_TOKEN
            EXPIRES_AT
            EXPIRES
            CLIENTID
            CLIENTSECRET
            CLIENTBASE64
            HUE_DIR
            PRODUCT
        }

        foreach var $exportList {
            if {[info exists ::hue::env::$var]} {
                set ::$var [set ::hue::env::$var]
            }
        }
    }
    # Call init automatically when this file is sourced
    init
    # ------------------------------------------------------------------
    # reset
    # ------------------------------------------------------------------
    proc reset {} {
        variable HUE_DIR

        if {![info exists HUE_DIR] || $HUE_DIR eq ""} {
            set scriptDir [file dirname [file normalize [info script]]]
            set HUE_DIR   [file join $scriptDir env]
        }

        foreach f {".bridge" ".appid"} {
            set p [file join $HUE_DIR $f]
            if {[file exists $p]} {
                file delete $p
            }
        }

        puts "hue::env reset: removed .bridge and .appid"
    }

    # ------------------------------------------------------------------
    # vars
    # ------------------------------------------------------------------
    proc vars {} {
        variable HUE_DIR
        variable PRODUCT
        variable DEVICENAME
        variable BUSYBOX
        variable bridge
        variable APPID
        variable CLIENTID
        variable CLIENTSECRET
        variable CLIENTBASE64
        variable config
        variable configPath
        variable tempFile
        variable ENVIRONMENT
        variable HOST
        variable all
        variable reset

        variable user
        variable ip
        variable id
        variable resolveV1
        variable resolveV2
        variable bridgeNr

        variable ACCESS_TOKEN
        variable REFRESH_TOKEN
        variable EXPIRES_AT
        variable EXPIRES

        return [dict create \
            HUE_DIR         $HUE_DIR \
            PRODUCT         $PRODUCT \
            DEVICENAME      $DEVICENAME \
            BUSYBOX         $BUSYBOX \
            bridge          $bridge \
            APPID           $APPID \
            CLIENTID        $CLIENTID \
            CLIENTSECRET    $CLIENTSECRET \
            CLIENTBASE64    $CLIENTBASE64 \
            config          $config \
            configPath      $configPath \
            tempFile        $tempFile \
            ENVIRONMENT     $ENVIRONMENT \
            HOST            $HOST \
            all             $all \
            reset           $reset \
            user            $user \
            ip              $ip \
            id              $id \
            resolveV1       $resolveV1 \
            resolveV2       $resolveV2 \
            bridgeNr        $bridgeNr \
            ACCESS_TOKEN    $ACCESS_TOKEN \
            REFRESH_TOKEN   $REFRESH_TOKEN \
            EXPIRES_AT      $EXPIRES_AT \
            EXPIRES         $EXPIRES \
        ]
    }

    # ------------------------------------------------------------------
    # Ensemble command
    # ------------------------------------------------------------------
    namespace ensemble create -command ::hue::env -map {
        init  init
        vars  vars
        reset reset
        help  help
    }
}