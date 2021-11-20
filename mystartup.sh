#!/bin/bash

#discover_message = 
#        "M-SEARCH * HTTP/1.1
#        HOST: 239.255.255.250:1982 
#        MAN: \"ssdp:discover\" 
#        ST: wifi_bulb"

#echo $(discover_message) > /dev/udp/239.255.255.250/1982
#And then catch the mono cast response.

RET_VAL=""
Z_ALARM_HOUR="00"
Z_ALARM_MIN="00"

#
## Color control values
#
RGB_STEPS=8
COLOR_CHANGE_TIME_MS=10000
COLOR_CHANGE_TIME_S=10
# Can take up to 10 steps with these settnngs but light is too white in the end.

# Define starting color
RGB_START=(215 55 5)
# Define color increase
RGB_STEP=(3 13 7)

#
## Intensity control values
#
STARTING_INTENSITY=1

#8 loop laps, should take ~9 minutes (560s) -> 70s per loop.
INT_INC_TIME_MS=70000
INT_INC_TIME_S=70


#IP settings
IP_Yeelight=192.168.0.105

##---------------------------------
# 	Debug function
#	Prints a debug message to terminal and log.txt
##---------------------------------
debug_echo() {
	echo "[$(date)]: $1" >> ~/Desktop/log.txt
	echo "[$(date)]: $1"
}

##---------------------------------
# 	Main light loop function
##---------------------------------
main_light_loop() {

	RGB_COUNTER=0
	let INT_STEP=80/$RGB_STEPS
	let INT=$STARTING_INTENSITY+$INT_STEP

        while [ $RGB_COUNTER -lt $RGB_STEPS ]; do
		let COLOR_R=${RGB_START[0]}+${RGB_STEP[0]}*RGB_COUNTER
		let COLOR_G=${RGB_START[1]}+${RGB_STEP[1]}*RGB_COUNTER
		let COLOR_B=${RGB_START[2]}+${RGB_STEP[2]}*RGB_COUNTER
		let COLOR=$COLOR_R*65536+$COLOR_G*256+$COLOR_B

		RET_VAL=$(echo -ne '{"id":1,"method":"set_rgb","params":['$COLOR',"smooth",'$COLOR_CHANGE_TIME_MS']}\r\n' | nc -w1 $IP_Yeelight 55443)

		debug_echo "Loop lap $RGB_COUNTER"

		sleep $COLOR_CHANGE_TIME_S
              	let RGB_COUNTER=RGB_COUNTER+1

		# Increase intensity also, do this stepwise.
                while true; do
			RET_VAL=$(echo -ne '{"id":1,"method":"set_bright","params":['$INT',"smooth",'$INT_INC_TIME_MS']}\r\n' | nc -w1 $IP_Yeelight 55443)

	                if ( echo "$RET_VAL" | grep -q "bright" )
	                then 
				debug_echo "Succeded setting intensity: $RET_VAL"
				let INT=$INT+$INT_STEP
	                        break
	                else
	                	debug_echo "Failed to set intensity:$RET_VAL"
				# Try again after some time.
				sleep 2;
	               	fi
	     	done

		# New intensity has been set. Sleep for some time.
		sleep $INT_INC_TIME_S
	done
}


##---------------------------------
# 	Start of program
##---------------------------------

# Remove previous log file
rm ~/Desktop/log.txt

debug_echo "Starting up Johan Yeelight clock script, /etc/init.d/mystartup.sh"

# Set up bulp's IP address.
IP_Yeelight_end=$(echo $IP_Yeelight | cut -d'.' -f 4)
IP_Yeelight_end=$(zenity --timeout 30 --scale --text "Select IP of bulp." --value=$IP_Yeelight_end --min-value="0" --max-value="255" --step="1")

if [ "$IP_Yeelight_end" != "" ]
then
	IP_Yeelight_beg=$(echo $IP_Yeelight | cut -d'.' -f 1-3)
	IP_Yeelight="$IP_Yeelight_beg.$IP_Yeelight_end"
	
	# Inform user about the Yeelight bulps IP address settings
	zenity --timeout 20 --info --text "Bulp IP set to $IP_Yeelight"
else 
	zenity --timeout 5 --info --text "Alarm not set. Exiting"
	exit 0
fi


# If day not Firday or Saturday skip all settings and set alarm to 05:50.
if  [ "$(date +%A)" != "fredag" ] && [ "$(date +%A)" != "lördag"  ] && [ "$(date +%H)" -lt "21" ]
then
	Z_ALARM_HOUR="05"
	Z_ALARM_MIN="50"
        debug_echo "Alarm set to: $Z_ALARM_HOUR:$Z_ALARM_MIN"
        zenity  --timeout 60 --info --text "Alarm automatically set to $Z_ALARM_HOUR:$Z_ALARM_MIN since time now is before 21:00."
else

	# Set up alarm time
	Z_ALARM_HOUR=$(zenity --list --radiolist --width=70 --height=200 --text \
		"Select time for alarm (hours):" \
	        --hide-header --column "Select" --column "Hour" \
		TRUE "$(date +%H)" \
		FALSE "05" \
	    FALSE "06" \
	    FALSE "07" \
	    FALSE "08" \
	    FALSE "09" \
	    FALSE "10" \
	    FALSE "11" \
	    FALSE "12" \
	    FALSE "13" \
	    FALSE "14" \
	    FALSE "15" \
	    FALSE "16" \
	    FALSE "17" \
	    FALSE "18" \
	    FALSE "19" \
	    FALSE "20" \
	    FALSE "21" \
	    FALSE "22" \
	    FALSE "23" \
		FALSE "00" \
		FALSE "01" \
		FALSE "02" \
		FALSE "03" \
		FALSE "04")

	if  [ "$Z_ALARM_HOUR" != "" ]
	then
		Z_ALARM_MIN=$(zenity --list --radiolist --width=70 --height=300 --text \
	        "Select time for alarm (minutes):" \
	        --hide-header --column "Select" --column "Minutes" \
		TRUE "$(date +%M)" \
		FALSE "00" \
		FALSE "05" \
	    FALSE "10" \
		FALSE "15" \
		FALSE "20" \
	    FALSE "25" \
		FALSE "30" \
		FALSE "35" \
		FALSE "40" \
		FALSE "45" \
		FALSE "50" \
		FALSE "55" \
		)

		if [ "$Z_ALARM_MIN" != "" ]
		then
			zenity --timeout 10 --info --text "Alarm set to $Z_ALARM_HOUR:$Z_ALARM_MIN."
			debug_echo "Alarm set to: $Z_ALARM_HOUR:$Z_ALARM_MIN"
		else 
			zenity --timeout 5 --info --text "Alarm not set. Exiting"
			debug_echo "Alarm not set, exiting"
		fi
	else 
		debug_echo "Alarm not set, exiting"
		zenity --timeout 60 --info --text "Alarm not set. Exiting"
	fi
fi

##---------------------------------
# 	Main control loop
##---------------------------------
while [[ "$Z_ALARM_HOUR" != ""  && "$Z_ALARM_MIN" != "" ]]; do

	# Log message to terminal only
	echo "Timestamp: $(date)"

	#Start alarm
	if [ $(date +%H) = $Z_ALARM_HOUR ] && [ $(date +%M) = $Z_ALARM_MIN ]
	then
		debug_echo "Alarm got off"

		# Ramping up bulb
		while true; do
			# Await the correct return value: '{"method":"props","params":{"power":"on"}}'
                        RET_VAL=$(echo -ne '{"id":1,"method":"set_power","params":["on","smooth",80000]}\r\n' | nc -w1 $IP_Yeelight 55443)
                        debug_echo "RET_VAL=$RET_VAL"

			#if ( echo "$RET_VAL" | grep -q "on" )
			if ( echo "$RET_VAL" | grep -q '{"method":"props","params":{"power":"on"}}' )
			then
				debug_echo "Turning on bulb"
				break
			else
				debug_echo "Failed turning on bulb, RET_VAL=$RET_VAL"
			fi

			# Wait before trying to turn on bulb again.
			sleep 2
                done

		# Set intensity to minimal 1%.
		while true; do
			RET_VAL=$(echo -ne '{"id":1,"method":"set_bright","params":['$STARTING_INTENSITY',"sudden",0]}\r\n' | nc -w1 $IP_Yeelight 55443)
			if ( echo "$RET_VAL" | grep -q "bright" )
                        then 
                                debug_echo "Set intensity: $RET_VAL"
                                break
                        else
                                debug_echo "Failed to set intensity:$RET_VAL"
				# Maybe because the intensity is the same.
				RET_VAL=$(echo -ne '{"id":1,"method":"get_prop","params":["bright"]}\r\n' | nc -w1 $IP_Yeelight 55443)
				debug_echo "Reading intensity: $RET_VAL"

				if ( echo "$RET_VAL" | grep -q '"1"')
				then
					debug_echo "Intensity already set to " $STARTING_INTENSITY
					break
				fi
                        fi
                        sleep 1
		done

		# Start the main light loop and kill it at zenity input or timeout
		main_light_loop &
		PID_MLL=$!

                zenity --timeout 900 --info --width 200 --height 200 --text "Alarm sounding for 15 minutes. Press ok to stop."

		debug_echo "Killing $PID_MLL"

		kill $PID_MLL

                #Turn of bulb slowly after at most 15 minutes.
                echo -ne '{"id":1,"method":"set_power","params":["off","smooth",5000]}\r\n' | nc -w1 $IP_Yeelight 55443

		debug_echo "Alarm loop done"
		sleep 1
		exit 0
	else 
		# Print only to terminal
		echo "Alarm not going off yet"
	fi

	sleep 20
done

tmp_time = $(eval "date +\"%T\"")
ebug_echo "Alarm loop failed at: $tmp_time"


