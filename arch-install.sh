#! /bin/bash

# Global constants
readonly ERR_MSG="Invalid selection. Please try again."
readonly SUCCESS=0
readonly FAILURE=1
readonly PING_ONCE=1
readonly CMD_RETURN_STATUS="$?"

#===Functions================

# Intro function
arch_header () {
    # Clear the terminal
    clear

    printf "\n\n"
    echo -e "          \e[0;36m."
    echo -e "         \e[0;36m/ \ "
    echo -e "        \e[0;36m/   \      \e[1;37m               #     \e[1;36m| *"
    echo -e '       \e[0;36m/^.   \     \e[1;37m a##e #%" a#"e 6##%  \e[1;36m| | |-^-. |   | \ /'
    echo -e "      \e[0;36m/  .-.  \    \e[1;37m.oOo# #   #    #  #  \e[1;36m| | |   | |   |  X"
    echo -e '     \e[0;36m/  (   ) _\   \e[1;37m%OoO# #   %#e" #  #  \e[1;36m| | |   | ^._.| / \ \e[0;37mTM'
    echo -e "    \e[1;36m/ _.~   ~._^\ "
    echo -e "   \e[1;36m/.^         ^.\ \e[0;37mTM"
    printf "\n\n"


}

# Exit function
# $1: Option to force exit without user prompt
abort () {
    local input

    # Force exit
    if [ "$1" = "force" ]; then
        printf "\nExiting install script...\n\n"
        exit
    fi

    # Prompt the user
    read -r -p $'\n'"Script not complete. Confirm exit (y/N): " input
    if [ "${input}" = y ]; then
        printf "\nExiting install script...\n\n"
        exit
    fi 
}    

# Manual error checkingdqwd
# $1: Message to be displayed upon command completion
error_check () {
    if [ "${CMD_RETURN_STATUS}" = ${SUCCESS} ]; then
        # Previous command completed successfully
        # Print completion message
        echo -e "$1"
    else
        # Abort script due to error
        # Print error message
        printf "ERROR: Command returned failure\n"
        abort force
    fi
}

# Function to verify boot mode matches user selection
# $1: User's selected boot mode
check_boot () {
    local -r UEFI_DIR="/home/chrysis/Workspace"

    # UEFI vars detected
    if [ "$(ls -A ${UEFI_DIR})" ]; then
        #User selected BIOS mode with UEFI vars, abort
        if [ "$1" = "BIOS" ]; then
            printf "Invalid selection, UEFI boot detected.\n"
            printf "Please reboot ISO in legacy BIOS mode to continue.\n"
            abort force
        fi

    # UEFI vars not detected
    else
        # User selected UEFI mode without UEFI vars, abort
        if [ "$1" = "UEFI" ]; then
            printf "Invalid selection, BIOS boot detected.\n"
            printf "Please reboot ISO in UEFI mode to continue.\n"
            abort force
        fi
    fi
}

# Function to see results of a ping
# $1: Argument to call for a second and final ping test, aborting if failed 
ping_test () {
    # Ping Google

    # If ping succeeds
    if ! ping -c ${PING_ONCE} www.google.com &> /dev/null; then
        return ${SUCCESS}

    # If ping fails on second (last) attempt
    elif [ "$1" = "last time" ]; then
        # Abort script to allow user to manually connect
        printf "Still no internet connection detected. Please connect to network then restart.\n"
        abort force

    # If ping failes first true
    else
        return ${FAILURE}
    fi
}

# Function to verify an internet connection, either wireless or lan
check_network () {
    local options opt net_dev wpa_ssid wpa_psk

    # Ping Google to test for a connection
    # Escape function if connection detected
    if ping_test; then
        printf "Internet connection detected\n\n"
        return ${SUCCESS}
    fi

    # Else try and make a connection
    printf "No internet connection detected.\n\n"

    # Prompt for wireless/lan
    PS3="Enter you network device: "
    options=("Ethernet (LAN)" "Wireless (WLAN)")
    select opt in "${options[@]}"; do
        case $opt in
            "Ethernet (LAN)")
                printf "\nEthernet connection selected\n"

                # Get ethernet device
                printf "Getting ethernet device......"
                net_dev="$(find /sys/class/net | grep -i '/e')"
                net_dev="${net_dev:15}" # Parse out directories from string
                error_check "done\nCurrent network device is '${net_dev}'"

                # If no ethernet device detected, go back to menu
                if [ "${net_dev}" = "" ]; then
                    printf "No ethernet device detected, please try again.\n\n"
                    continue
                fi

                # Attempt to turn ethernet device on
                printf "Turning on ethernet device......"
                ip link set "${net_dev}" up
                error_check "done\n"

                # Attempt to get IP via DHCP
                printf "Attempting to retrieve IP address......\n"
                killall dhcpcd
                wait
                dhcpcd "${net_dev}"
                error_check "Retrieved IP address via DHCP: Success\n"

                break;;

            "Wireless (WLAN)")
                printf "\nWireless connection selected\n"

                # Get wireless device
                printf "Getting wireless device......"
                net_dev="$(find /sys/class/net | grep -i '/w')"
                net_dev="${net_dev:15}" # Parse out directories from string
                error_check "done\nCurrent network device is '${net_dev}'"

                # If no wireless device detected, go back to menu
                if [ "${net_dev}" = "" ]; then
                    printf "No wireless device detected, please try again.\n\n"
                    continue
                fi

                # Attempt to turn wireless device on
                printf "Turning on wireless device '%s'......" "${net_dev}"
                ip link set "${net_dev}" up
                error_check "done\n"

                # Scan for wireless access points
                printf "Scanning for wifi access points......"
                iw dev "${net_dev}" scan | less
                error_check "done\n"

                # Prompt user for wifi SSID and passphrase
                read -r -p "Enter your wifi SSID: " wpa_ssid
                read -r -p "Enter your wpa/wpa2 passphrase: " wpa_psk

                # Attempt to connect to wireless access point
                printf "Attempting to connect to '%s'......" "${wpa_ssid}"
                wpa_supplicant -B -i "${net_dev}" -c <(wpa_passphrase "${wpa_ssid}" "${wpa_psk}")
                error_check "done\n"

                # Attempt to get IP via DHCP
                printf "Attempting to retrieve IP address......\n"
                killall dhcpcd
                wait
                dhcpcd "${net_dev}"
                error_check "Retrieved IP address via DHCP: Success\n"

                break;;

            *) # Invalid input
                printf "\n%s\n\n" "${ERR_MSG}"
                continue;;
        esac
    done

    # Test internet connection again
    # Abort if still not connected to allow user to connect manually
    ping_test "last time"
    printf "Internet connection detected\n\n"
}

disk_partitioner () {
    local options opt boot="$1"

    # Disk prompt
    PS3="Select an install type: "
    options=("Linux boot only" "Dual-boot with Windows (same drive)" "Dual-boot with Windows (separate drive")
    select opt in "{options[@]}"; do
        case $opt in
            "Linux boot only")
                break;;
            "Dual-boot with Windows (same drive)")
                break;;
            "Dual-boot with Windows (separate drive)")
                break;;
            *) # Invalid input
                printf "\n%s\n\n" "${ERR_MSG}"
                continue;;
        esac
    done

}

#===Main Program=============

main () {
    # Variable declarations
    local options opt boot_mode

    # Print the header
    arch_header

    # Menu prompt
    # Get boot mode for install
    PS3="Select an install type: "
    options=("UEFI" "BIOS" "Quit")
    select opt in "${options[@]}"; do
        case $opt in
            "UEFI")
                boot_mode="UEFI"
                printf "\nUEFI install selected\n\n"
                break;;
            "BIOS")
                boot_mode="BIOS"
                printf "\nBIOS install selected\n\n"
                break;;
            "Quit")
                abort;; 
            *) # Invalid input
                printf "\n%s\n\n" "${ERR_MSG}"
                continue;;
        esac
    done

    # Check for a valid boot given the user's selection
    check_boot ${boot_mode}

    # Check for a working internet connection
    check_network

    # Update the system clock
    printf "Setting the system clock......"
    timedatectl set-ntp true
    error_check "done\n"

    # Partition the disks
    disk_partitioner ${boot_mode}

    # Temp ending
    printf "\nlol u made it\n"
}

# Execute main function
main "$@"

