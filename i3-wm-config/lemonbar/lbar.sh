#!/bin/bash

# Colours
. ~/.config/lemonbar/lbar_colours

# Icons
INet=""
ICpuTemp=""
ICpuLoad=""
IVolM=""
IVolL=""
IVolH=""
IBattery0=""
IBattery1=""
IBattery2=""
IBattery3=""
IBattery4=""
IDate=""
ITime=""
ILock=""
IWorkspaceDivider="|"

# Separators
SEP=" "
SEP2="  "
SEP4="    "
SEP6="      "

# Refresh rate
refresh=0.5

# Names of all the screen outputs being used
Screens=$(xrandr | grep -o "^.* connected" | sed "s/ connected//")

bar() {

    Battery() {
        # If this system has a battery
        if [[ -d /sys/class/power_supply/BAT0 ]] || [[ -d /sys/class/power_supply/BAT1 ]]; then
            # Can be 'Full', 'Discharging', 'Unknown' or 'Charging'.
            STATUS=$(cat /sys/class/power_supply/BAT0/status || cat /sys/class/power_supply/BAT1/status)
            BATTERY=$(cat /sys/class/power_supply/BAT0/capacity || cat /sys/class/power_supply/BAT1/capacity) 
            if [[ $STATUS == "Unknown" ]] || [[ $STATUS == "Charging" ]] || [[ $STATUS == "Full" ]]; then
                stat=""
            else
                # Change icon and colour depending on battery status
                if [[ $BATTERY -lt 20 ]]; then stat=$IBattery0
                elif [[ $BATTERY -lt 40 ]]; then stat=$IBattery1
                elif [[ $BATTERY -lt 60 ]]; then stat=$IBattery2
                elif [[ $BATTERY -lt 80 ]]; then stat=$IBattery3
                else stat=$IBattery4
                fi

                if [ $BATTERY -lt 15 ]; then
                    BATbg="$red"
                elif [ $BATTERY -lt 30 ]; then
                    BATbg="$yellow"
                fi
            fi

            BATTERY+="%"
            # If our battery background has changed, print it with the changed background
            if [ -n "$BATbg" ]; then
                echo "%{F$white}%{B$BATbg}$stat$SEP$BATTERY%{B$bg}%{F-}"
            else
                echo %{F$gray}$stat$SEP$BATTERY%{F-}
            fi
        else echo ""; fi
    } 

    CpuTemp() {
        # Get the the highest temp of any core
        CPUTEMP=$(sensors | grep "Physical id" | grep -o "[0-9]\+\.[0-9]\+" | head -n 1 | sed "s/\..*$//")

        # Icon turns red if above 65C
        if [[ $CPUTEMP -gt 65 ]]; then
            CPUTEMP+="C"
            # Opens xfce-4 terminal with the top command executed on click
            echo "%{F$gray}%{B$red}%{A:"xfce4-terminal -e top -T Top \&":}$ICpuTemp$SEP$CPUTEMP%{A}%{B$bg}%{F-}"
        else
            CPUTEMP+="C"
            echo %{F$gray}%{A:"xfce4-terminal -e top -T Top &":}$ICpuTemp$SEP$CPUTEMP%{A}%{F-}
        fi
    }

    Date() {
        DATE=$(date "+%A %m/%d/%Y")
        # Launches google cal in chrome when clicked
        echo %{F$gray}%{A:"google-chrome-stable google.com/calendar &":}$IDate$SEP$DATE%{A}%{F-}
    }

    NetUp() {	
        # Pings the default gateway. If it is successful then we are connected. Benefits
        # to pinging the default gateway rather than google.com, etc. is that this doesn't
        # rely on those websites being up and as such, will always be accurate
        defGate=$(ip r | grep default | cut -d ' ' -f 3)
        if [[ ${#defGate} -ge 7 ]]; then
            NetUp=$(ping -q -w 1 -c 1 $defGate > /dev/null && echo c || echo u)
            # If some network interface is up
            if [[ $NetUp == "c" ]]; then
                # Opens wicd-client when clicked
                echo %{F$gray}%{A:"wicd-client &":}$INet%{A}%{F-}
            else
                # Icon background is red if network is down
                echo "%{F$gray}%{B$red}%{A:"wicd-client \&":}$INet%{A}%{B$bg}%{F-}"
            fi
        else
            # Icon background is red if network is down
            echo "%{F$gray}%{B$red}%{A:"wicd-client \&":}$INet%{A}%{B$bg}%{F-}"
        fi
    }

    Time() {
        TIME=$(date "+%H:%M %Z")
        echo %{F$gray}$ITime$SEP$TIME%{F-}
    }

    Volume() {
        # Check the volume level using the perl script
        VOL=$($HOME/.config/lemonbar/check_volume.pl 1)
        # Set icons appropriately
        # Muted
        if [[ $VOL == M* ]]; then 
            Icon=$IVolM
            VOL+="%)"
        else
            if [[ $VOL -lt 40 ]]; then Icon=$IVolL # Low volume
            else Icon=$IVolH; fi # High volume
            VOL+="%"
        fi

        # If we actually retrieved a valid volume value
        if [[ ${#VOL} -ge 1 ]]; then
            # Clicking on the volume icon launches an audio control interface
            echo %{F$gray}%{A:"pavucontrol &":}$Icon$SEP$VOL%{A}%{F-}
        fi
    }

    # Extremely messy and inefficient, need to clean this up
    Workspaces() {
        # This command returns all the workspaces in use in a JSON format
        WORKSPACES="$(i3-msg -t get_workspaces)"
        COUNTER=0
        OUTPUT=""

        # Loop through all the chars in the JSON object
        for((i=0; i<${#WORKSPACES}; i++))    
        do
            # The current char
            ch=${WORKSPACES:i:1}

            # Every 11 colons will contain our workspace number.
            # When we find it, we store it in a temporary var (CURRENTWS), and only add it to our output after we find the next workspace
            #   Here is a quick trace to help clear things up:
            #   1) Find workspace [1]           CURRENTWS: 1                 OUTPUT: (null)
            #   2) Find that it is inactive     CURRENTWS: 1                 OUTPUT: (null) 
            #   3) Find workspace [2]           CURRENTWS: 2                 OUTPUT: 1
            #   4) Find that it is active       CURRENTWS: 2 WINDOWTITLE     OUTPUT: 1
            #   5) Find workspace [3]           CURRENTWS: 3                 OUTPUT: 1, 2 WINDOWTITLE

            if [ $ch == ":" ]; then
                COUNTER=$[$COUNTER +1]
                if [ $COUNTER -eq 1 ]; then
                    j=$[$i +1]
                    if [ -n "$CURRENTWS" ]; then
                        OUTPUT="$OUTPUT$IWorkspaceDivider$CURRENTWS%{A}"
                    fi

                    # Need to add two chars if the workspace is two digits
                    if [ ${WORKSPACES:i+2:1} != "," ]; then
                        # We are able to click on each workspace number to switch to it!
                        #  e.g. The command "i3-msg workspace 3" switches to workspace 3
                        CURRENTWS="%{A:i3-msg workspace ${WORKSPACES:i+1:1}${WORKSPACES:i+2:1}:}  ${WORKSPACES:i+1:1}${WORKSPACES:i+2:1}  "
                    else
                        CURRENTWS="%{A:i3-msg workspace ${WORKSPACES:i+1:1}:}  ${WORKSPACES:i+1:1}  "
                    fi
                fi
                # Reset our counter when it hits 11
                if [ $COUNTER -eq 11 ]; then
                    COUNTER=0
                fi
                # Check if the current workspace is active in the JSON object
            elif [ $ch == "d" ] && [ ${WORKSPACES:i+3:1} == "t" ]; then
                # If so, get the name of the active window
                id=$(xprop -root | awk '/_NET_ACTIVE_WINDOW\(WINDOW\)/{print $NF}')
                ACTIVEW=$(xprop -id $id | awk '/_NET_WM_NAME/{$1=$2="";print}' | cut -d'"' -f2)
                # Cut off the window title if it's >42 characters long
                if [ ${#ACTIVEW} -gt 42 ]; then
                    ACTIVEW="$(echo $ACTIVEW | cut -c 1-40)..."
                fi
                # Add a space to separate the title from the window number
                if [ ${#ACTIVEW} -gt 0 ]; then
                    ACTIVEW=" $ACTIVEW"
                fi
                # Remove all spaces from the workspace number
                CURRENTWS="$(echo -e "${CURRENTWS}" | tr -d '[[:space:]]')"
                # Update the workspace with a different bg colour + title of active window
                CURRENTWS="%{B#607D8B} [ $CURRENTWS ]$ACTIVEW %{B$bg}"
            fi
        done

        # If our current workspace var still contains something
        #  - Happens when we reach the end of the loop before adding the last element (which happens at the beginning of the loop)
        if [ -n "$CURRENTWS" ]; then
            OUTPUT="$OUTPUT$IWorkspaceDivider$CURRENTWS%{A}"
        fi

        echo "%{F$gray}$OUTPUT$IWorkspaceDivider%{F-}"
    }

    barleft="$SEP$(Workspaces)"
    barcenter="$(Time)"
    barright="$(CpuTemp)$SEP2$(NetUp)$SEP2$(Volume)$SEP2$(Battery)$SEP2$(Date)$SEP2"

    finalbarout=""

    tmp=0
    for screen in $(echo "$Screens"); do
        finalbarout+="%{S${tmp}}%{l}$barleft%{c}$barcenter%{r}$barright"
        let tmp=$tmp+1
    done

    echo "${finalbarout}"
}


screennum=$(echo "$Screens" | wc -l)
if [[ $screenum -eq 1 ]]; then
    let OH=1
    let OF=-1
else
    let OH=2
    let OF=-2
fi

while true; do
    echo "$(bar)"
    sleep $refresh;
done | lemonbar -g x33 -a 22 -u 2 -o $OH -f "Roboto-13" -o $OF -f "FontAwesome-11" -B $bg -F $fg | bash &