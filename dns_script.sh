#!/bin/bash
LOGFILE="/var/log/dns_setup.log"
check_root() {

GROUP=$(id -gn) #gets the rpimary group form the user

if [[ "$GROUP" == "bind" || "$GROUP" == "root" ]]; then
    echo "You are in the allowed group, nice!"
else
    echo "This script must be run by the groups bind or root."
    exit 1 #exitssss
fi


if [[ "$EUID"  -ne 0 ]]; #if the EUID is not root #double brakets just safer/????? THEY SAY??/
then echo "Please run as root" | tee -a "$LOGFILE"
    exit 1 #exits


else
    if ! systemctl list-units --type=service --all | grep -E 'bind9|named' ; #looks at all the sercies ont ehsystme looking for named
        then echo "BIND9 package not found. Downloading now!!"
        sudo apt install bind9 -y #installs bind9
    else
        echo "Bind or Named service Found"
    fi
fi

}
input_domain() {
    read -p "Enter the domain you want configured: " domain  #takes user input  (-p) shows a message before
    domain=${domain:-example.com} #assigns empty vairable to the inputted domain
    echo "configuring: $domain"
    while true; do
        read -p "enter the IP for the domain (master): $domain: " IP_ADDR #takes IP input
        if [[ ! "$IP_ADDR" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then #if the Ip add is not equal tot eh regex match of 1 or more numbers after every period
            echo "not a valid IP formatting!!!" | tee -a "$LOGFILE" #puts it in the log file
        else
            echo "IP; $IP_ADDR"
            break #breaks da loop
        fi
    done
}
slave_master() {
    while true; do
        read -p "is this a master or slave type? " type
        type=${type,,} #takes the lowercase of input
        if [[ "$type" != 'master' && "$type" != 'slave' ]]; then
        echo "incorrext option/formatting" | tee -a "$LOGFILE"
        else
            echo "dns_type:$type"
            break
        fi
    done
    if [[ "$type" == 'slave' ]]; then
        while true; do
        read -p "enter the IP for the slave domain: $domain: " SLAV_IP #takes IP input
        if [[ ! "$SLAV_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then #if the Ip add is not equal tot eh regex match of 1 or more numbers after every period
            echo "not a valid IP formatting!!!" | tee -a "$LOGFILE"
        else
            echo "IP; $SLAV_IP"
            break #breaks da loop
        fi
    done
    fi
}
reverse_choice() {
    while true; do
        read -p "do you want to configure reverse zones (y/n)? "  rev_choice
        rev_choice=${rev_choice,,}
        if [[ "$rev_choice" != 'y' &&  "$rev_choice" != 'n' ]]; then
        echo "choice not applicable enter "y" or "n"" | tee -a "$LOGFILE"
        else
            echo "reverse zones= $rev_choice"
            break
        fi 
    done
}
path_check() {
    while true; do
        read -p "Enter the path for the zone file: "  ZONE_PATH
        ZONE_PATH=${ZONE_PATH:-/etc/bind/zones} #if the vaariable si not set or anything jsut chnage to /etc/bind/zones
        if [[ ! "$ZONE_PATH" =~ ^/[^/].*[^/]$ ]]; then #makes sres that the regex math starts with a "/"
        echo "we need FULL paths. try again..." | tee -a "$LOGFILE"
        else
            echo "ZONE PATH= "$ZONE_PATH""
            break
        fi 
    done
    if [[ ! -d "$ZONE_PATH" ]]; then
        echo ""$ZONE_PATH" does not exist. Making now..." | tee -a "$LOGFILE"
        mkdir -p "$ZONE_PATH" #MAKE THE PATH
        chmod 755 "$ZONE_PATH" #CHANGE THE PERMISSIONS
    fi
}
overwrite_file() {
     while true; do
        read -p "Do you want to overwrite the file? (y/n)? "  OVERWRITE #asks if the user whast teh append or overwrite the fonfig files
        OVERWRITE=${OVERWRITE,,}
        if [[ "$OVERWRITE" != 'y' &&  "$OVERWRITE" != 'n' ]]; then
        echo "choice not applicable enter "y" or "n"" | tee -a "$LOGFILE"
        else
            echo "overwrite = "$OVERWRITE""
            break
        fi 
    done
}

show_setup() {
    echo "DNS SETUP
    --------------------------------------------
    domain: $domain
    ip: $IP_ADDR
    type: $type
    slave ip: $SLAV_IP
    reverse zone: $rev_choice
    path: $ZONE_PATH
    overwrite config files: $OVERWRITE"
}
writing_config() {

ZONE_FILE=${ZONE_PATH}/db.${domain}

    if [[ "$OVERWRITE" == 'y' && "$rev_choice" == 'n' ]]; then
    echo "overwriting named.conf.local file" | tee -a "$LOGFILE"
    cat <<END > /etc/bind/named.conf.local #OVERWRITRES THE FILE UNTIL END
    #---Auto-DNS-CONFIG--
    zone "$domain" {
        type $type;
        $( if [[ "$type" == "slave" ]]; then 
            echo "file \"/var/cache/bind/db.$domain\";"
        else
            echo "file \"$ZONE_FILE\";"
        fi )
};
        $( [[ "$type" == "slave" ]] && echo "masters { "$domain"; };" )  # aaddress of the master server
    };

END
    elif [[ "$OVERWRITE" == 'y' && "$rev_choice" == 'y' ]]; then
        if [[ "$type" == "slave" ]]; then
            IFS='.' read -r A B C D <<< "$SLAV_IP" #splits IP add by the periods and assigns each section  to a vairbale
            REV_ZONE="${C}.${B}.${A}.in-addr.arpa"
        else
            IFS='.' read -r A B C D <<< "$IP_ADDR" #splits IP add by the periods and assigns each section  to a vairbale
            REV_ZONE="${C}.${B}.${A}.in-addr.arpa"
        fi

    REV_FILE="$ZONE_PATH/db.${REV_ZONE}"

    echo "overwriting named.conf.local file" | tee -a "$LOGFILE"
    cat <<END > /etc/bind/named.conf.local #OVERWRITRES THE FILE UNTIL END
    #---Auto-DNS-CONFIG--

    zone "$domain" {
        type $type;
        $( if [[ "$type" == "slave" ]]; then 
            echo "file \"/var/cache/bind/db.$domain\";"
            else
                echo "file \"$ZONE_FILE\";"
            fi )
        $( [[ "$type" == "slave" ]] && echo "masters { "$domain"; };" )  # aaddress of the master server
};

    zone "$REV_ZONE" {
        type $type;
        $( if [[ "$type" == "slave" ]]; then 
            echo "file \"/var/cache/bind/db.$REV_ZONE\";"
        else
            echo "file \"$REV_FILE\";"
        fi )
        $( [[ "$type" == "slave" ]] && echo "masters { "$domain"; };" )  # aaddress of the master server
};

END
    
    elif [[ "$OVERWRITE" == 'n' && "$rev_choice" == 'n' ]]; then
    echo "appending named.conf.local file" | tee -a "$LOGFILE"
    cat <<END >> /etc/bind/named.conf.local #APPENDS THE FILE UNTIL END
    #---Auto-DNS-CONFIG--
    zone "$domain" {
        type $type;
        $( if [[ "$type" == "slave" ]]; then 
            echo "file \"/var/cache/bind/db.$domain\";"
        else
            echo "file \"$ZONE_FILE\";"
        fi )

        $( [[ "$type" == "slave" ]] && echo "masters { "$domain"; };" )  # aaddress of the master server
};

END
    elif [[ "$OVERWRITE" == 'n' && "$rev_choice" == 'y' ]]; then
        if [[ "$type" == "slave" ]]; then
                    IFS='.' read -r A B C D <<< "$SLAV_IP" #splits IP add by the periods and assigns each section  to a vairbale
                    REV_ZONE="${C}.${B}.${A}.in-addr.arpa"
                else
                    IFS='.' read -r A B C D <<< "$IP_ADDR" #splits IP add by the periods and assigns each section  to a vairbale
                    REV_ZONE="${C}.${B}.${A}.in-addr.arpa"
        fi


    REV_FILE="$ZONE_PATH/db.${REV_ZONE}"

    echo "appending named.conf.local file"  | tee -a "$LOGFILE"
    cat <<END >> /etc/bind/named.conf.local #aPPENDS THE FILE UNTIL END
    #---Auto-DNS-CONFIG--

    zone "$domain" {
        type $type;
        $( if [[ "$type" == "slave" ]]; then 
            echo "file \"/var/cache/bind/db.$domain\";"
        else
            echo "file \"$ZONE_FILE\";"
        fi )

        $( [[ "$type" == "slave" ]] && echo "masters { "$domain"; };" )  # aaddress of the master server
};

    zone "$REV_ZONE" {
        type $type;
        $( if [[ "$type" == "slave" ]]; then 
            echo "file \"/var/cache/bind/db.$REV_ZONE\";"
        else
            echo "file \"$REV_FILE\";"
        fi )

        $( [[ "$type" == "slave" ]] && echo "masters { "$domain"; };" )  # aaddress of the master server
};

END
    fi 

}
writing_zones() {
    echo "named.conf.local files modified. Now making zone files...." | tee -a "$LOGFILE"
    # now making the zones files
 
   if [[ "$rev_choice" == 'n' && "$type" == "slave" ]]; then
   
    echo "Creating forward zone file: $ZONE_FILE"
    echo "making correct permissions"
    touch /var/cache/bind/db.$domain
    sudo chown root:bind /var/cache/bind/db.$domain
    sudo chmod 644 /var/cache/bind/db.$domain #chnag permisisons
    cat <<END > /var/cache/bind/db.$domain
\$TTL    86400
@       IN      SOA     ns1.$domain. admin.$domain. (
                  1      ; Serial
                  604800 ; Refresh
                  86400  ; Retry
                  2419200 ; Expire
                  86400 ) ; Minimum TTL

@          IN      NS      ns1.$domain.
ns1        IN      A       $SLAV_IP
END
    fi

if [[ "$rev_choice" == 'y' && "$type" == "slave" ]]; then
    
    echo "Creating reverse zone file: $REV_FILE"
    echo "making correct permissions"
    if [[! -f "/var/cache/bind/db.$REV_ZONE" ]]; then #if the revs=zone alreayd exists
    touch /var/cache/bind/db.$REV_ZONE
    sudo chown root:bind /var/cache/bind/db.$REV_ZONE
    sudo chmod 644 /var/cache/bind/db.$REV_ZONE
    cat <<END > /var/cache/bind/db.$REV_ZONE
\$TTL    86400
@       IN      SOA     ns1.$domain. admin.$domain. (
                  1      ; Serial
                  604800 ; Refresh
                  86400  ; Retry
                  2419200 ; Expire
                  86400 ) ; Minimum TTL

@       IN      NS      ns1.$domain.
${D}      IN      PTR     $domain.
END

    else
        cat <<END >> /var/cache/bind/db.$REV_ZONE
${D}    IN      PTR         $domain.
END
    fi

    echo "Creating forward zone file: $ZONE_FILE"
    echo "making correct permissions"
    touch /var/cache/bind/db.$domain
    sudo chown root:bind /var/cache/bind/db.$domain
    sudo chmod 664 /var/cache/bind/db.$domain
    cat <<END > /var/cache/bind/db.$domain
\$TTL    86400
@       IN      SOA     ns1.$domain. admin.$domain. (
                  1      ; Serial
                  604800 ; Refresh
                  86400  ; Retry
                  2419200 ; Expire
                  86400 ) ; Minimum TTL

@          IN      NS      ns1.$domain.
ns1        IN      A       $SLAV_IP
END
    

fi

if [[ "$rev_choice" == 'n' && "$type" == "master" ]]; then
   
    echo "Creating forward zone file: $ZONE_FILE"
    echo "making correct permissions"
    touch $ZONE_FILE
    sudo chown root:bind $ZONE_FILE
    sudo chmod 644 $ZONE_FILE
    cat <<END > "$ZONE_FILE"
\$TTL    86400
@       IN      SOA     ns1.$domain. admin.$domain. (
                  1      ; Serial
                  604800 ; Refresh
                  86400  ; Retry
                  2419200 ; Expire
                  86400 ) ; Minimum TTL

@          IN      NS      ns1.$domain.
ns1        IN      A       $IP_ADDR
END
fi

if [[ "$rev_choice" == 'y' && "$type" == "master" ]]; then
   
    echo "Creating reverse zone file: $REV_FILE"
    if [[! -f "$REV_FILE" ]]; then
    touch $REV_FILE
    echo "making correct permissions"
    sudo chown root:bind $REV_FILE
    sudo chmod 644 $REV_FILE
    cat <<END > "$REV_FILE"
\$TTL    86400
@       IN      SOA     ns1.$domain. admin.$domain. (
                  1      ; Serial
                  604800 ; Refresh
                  86400  ; Retry
                  2419200 ; Expire
                  86400 ) ; Minimum TTL

@       IN      NS      ns1.$domain.
${D}      IN      PTR     $domain.
END
    else
        cat <<END >> "$REV_FILE"
${D}    IN      PTR         $domain.
END
    fi
    echo "Creating forward zone file: $ZONE_FILE"
    touch $ZONE_FILE
    echo "making correct permissions"
    sudo chown root:bind $ZONE_FILE
    sudo chmod 644 $ZONE_FILE
    cat <<END > "$ZONE_FILE"
\$TTL    86400
@       IN      SOA     ns1.$domain. admin.$domain. (
                  1      ; Serial
                  604800 ; Refresh
                  86400  ; Retry
                  2419200 ; Expire
                  86400 ) ; Minimum TTL

@          IN      NS      ns1.$domain.
ns1        IN      A       $IP_ADDR
END
   
fi

}

change_IPv4() {
#this is to like edit to so that named only takes IPv4 addresses UGH
sudo tee /etc/systemd/system/named.service.d/override.conf > /dev/null << END #dev null gets rid of the output
[Service]
ExecStart=
ExecStart=/usr/sbin/named -f -u bind -4
END
#RESTART EVERYTHING 
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl restart named 
}

restart() {
sudo named-checkconf || { echo "named.conf has syntax errors"; exit 1; } | tee -a "$LOGFILE"
sudo systemctl restart bind9 || { echo "Failed to restart BIND9"; exit 1; } | tee -a "$LOGFILE"
echo "DNS BASE CONFIGS ARE COMPLETED!! please double check individual configurations/zones 
and such and network connections" | tee -a "$LOGFILE"

}

cronjob() {

CRONTAB_C=$(crontab -l 2>/dev/null) #opens the list sof crontabs and outputs to nothing


CRON_JOB='@yearly /usr/local/bin/dns_script.sh' #makes it a yearly script

# Check if it's already there, and add it if not
if ! echo "$CRONTAB_C" | grep -Fxq "$CRON_JOB"; then #grepping the conjob in their
    (echo "$CRONTAB_C"; echo "$CRON_JOB") | crontab - #if not their then echo it in
    echo "Cronjob added!."
else
    echo "cronjob already exists..."
fi
}








    


main() {
    check_root
    input_domain
    slave_master
    reverse_choice
    path_check
    overwrite_file
    show_setup
    writing_config
    writing_zones
    change_IPv4
    restart
    cronjob

}
main