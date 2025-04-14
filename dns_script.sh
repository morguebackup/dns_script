#!/bin/bash

if [[ "$EUID"  -ne 0 ]]; #if the EUID is not root #double brakets just safer/????? THEY SAY??/
then echo "Please run as root"
    exit 1 #exits
else
    if ! systemctl list-units --type=service --all | grep 'bind9|named' ; #looks at all the sercies ont ehsystme looking for named
        then echo "BIND9 package not found. Downloading now!!"
        sudo apt install bind9 -y #installs bind9
    else
        echo "Bind or Named service Found"
    fi

    read -p "Enter the domain you want configured: " domain  #takes user input  (-p) shows a message before
    domain=${domain:-example.com} #assigns empty vairable to the inputted domain
    echo "configuring: $domain"
    while true; do
        read -p "enter the IP for the domain: $domain: " IP_ADDR #takes IP input
        if [[ ! "$IP_ADDR" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then #if the Ip add is not equal tot eh regex match of 1 or more numbers after every period
            
            echo "not a valid IP formatting!!!"
        else
            echo "IP; $IP_ADDR"
            break #breaks da loop
        fi
    done

    while true; do
        read -p "is this a master or slave type?" type
        type=${type,,} #takes the lowercase of input
        if [[ "$type" != 'master' && "$type" != 'slave' ]]; then
        echo "incorrext option/formatting"
        else
            echo "dns_type:$type"
            break
        fi
    done

    while true; do
        read -p "do you want to configure reverse zones (y/n)? "  rev_choice
        rev_choice=${rev_choice,,}
        if [[ "$rev_choice" != 'y' &&  "$rev_choice" != 'n' ]]; then
        echo "choice not applicable enter "y" or "n""
        else
            echo "reverse zones= $rev_choice"
            break
        fi 
    done

    while true; do
        read -p "Enter the path for the zone file: "  ZONE_PATH
        ZONE_PATH=${ZONE_PATH:-/etc/bind/zones} #if the vaariable si not set or anything jsut chnage to /etc/bind/zones
        if [[ ! "$ZONE_PATH" =~ ^/ ]]; then
        echo "we need FULL paths. try again..."
        else
            echo "ZONE PATH= "$ZONE_PATH""
            break
        fi 
    done
    if [[ ! -d "$ZONE_PATH" ]]; then
        echo ""$ZONE_PATH" does not exist. Making now"
        mkdir -p "$ZONE_PATH"
    fi

     while true; do
        read -p "Do you want to overwrite the file? (y/n)? "  OVERWRITE
        OVERWRITE=${OVERWRITE,,}
        if [[ "$OVERWRITE" != 'y' &&  "$OVERWRITE" != 'n' ]]; then
        echo "choice not applicable enter "y" or "n""
        else
            echo "overwrite = "$OVERWRITE""
            break
        fi 
    done
    echo "DNS SETUP
    --------------------------------------------
    domain: $domain
    ip: $IP_ADDR
    type: $type
    reverse zone: $rev_choice
    path: $ZONE_PATH
    overwrite config files: $OVERWRITE"







    

fi
