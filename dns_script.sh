#!/bin/bash

if [[ "$EUID"  -ne 0 ]]; #if the EUID is not root #double brakets just safer/????? THEY SAY??/
then echo "Please run as root"
    exit 1 #exits
else
    if ! systemctl list-units --type=service --all | grep -E 'bind9|named' ; #looks at all the sercies ont ehsystme looking for named
        then echo "BIND9 package not found. Downloading now!!"
        sudo apt install bind9 -y #installs bind9
    else
        echo "Bind or Named service Found"
    fi

    read -p "Enter the domain you want configured: " domain  #takes user input  (-p) shows a message before
    domain=${domain:-example.com} #assigns empty vairable to the inputted domain
    echo "configuring: $domain"
    while true; do
        read -p "enter the IP for the domain (master): $domain: " IP_ADDR #takes IP input
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
    if [[ "$type" != 'slave' ]]; then
        while true; do
        read -p "enter the IP for the slave domain: $domain: " SLAV_IP #takes IP input
        if [[ ! "$SLAV_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then #if the Ip add is not equal tot eh regex match of 1 or more numbers after every period
            echo "not a valid IP formatting!!!"
        else
            echo "IP; $SLAV_IP"
            break #breaks da loop
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
        if [[ ! "$ZONE_PATH" =~ ^/[^/].*[^/]$ ]]; then #makes sres that the regex math starts with a "/"
        echo "we need FULL paths. try again..."
        else
            echo "ZONE PATH= "$ZONE_PATH""
            break
        fi 
    done
    if [[ ! -d "$ZONE_PATH" ]]; then
        echo ""$ZONE_PATH" does not exist. Making now..."
        mkdir -p "$ZONE_PATH"
    fi

     while true; do
        read -p "Do you want to overwrite the file? (y/n)? "  OVERWRITE #asks if the user whast teh append or overwrite the fonfig files
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
    slave ip: $SLAV_IP
    reverse zone: $rev_choice
    path: $ZONE_PATH
    overwrite config files: $OVERWRITE"

ZONE_FILE=${ZONE_PATH}db.${domain}

    if [[ "$OVERWRITE" == 'y' && "$rev_choice" == 'n' ]]; then
    echo "overwriting named.conf.local file"
    cat <<END > /etc/bind/named.conf.local #OVERWRITRES THE FILE UNTIL END
    ---Auto-DNS-CONFIG--
    zone "$domain" {
        type $type;
        $( if [[ "$type" == "slave" ]]; then 
            echo "file /var/cache/bind/db.$domain;"
        else
            echo "file $ZONE_FILE;"
        fi )
};
        $( [[ "$type" == "slave" ]] && echo "masters { "$domain"; };" )  # aaddress of the master server
    };

END
    elif [[ "$OVERWRITE" == 'y' && "$rev_choice" == 'y' ]]; then
        if [[ "$type" == "slave" ]]
            IFS='.' read -r A B C D <<< "$SLAV_IP" #splits IP add by the periods and assigns each section  to a vairbale
            REV_ZONE="${C}.${B}.${A}.in-addr.arpa"
        else
            IFS='.' read -r A B C D <<< "$IP_ADDR" #splits IP add by the periods and assigns each section  to a vairbale
            REV_ZONE="${C}.${B}.${A}.in-addr.arpa"
        fi

    REV_FILE="$ZONE_PATH/db.${REV_ZONE}"

    echo "overwriting named.conf.local file"
    cat <<END > /etc/bind/named.conf.local #OVERWRITRES THE FILE UNTIL END
    ---Auto-DNS-CONFIG--

    zone "$domain" {
        type $type;
        $( if [[ "$type" == "slave" ]]; then 
            echo "file /var/cache/bind/db.$domain;"
        else
            echo "file $ZONE_FILE;"
        fi )
};
        $( [[ "$type" == "slave" ]] && echo "masters { "$domain"; };" )  # aaddress of the master server
    };

    zone "$REV_ZONE" {
        type $type;
        $( if [[ "$type" == "slave" ]]; then 
            echo "file /var/cache/bind/db.$REV_ZONE;"
        else
            echo "file $REV_FILE;"
        fi )
};
        $( [[ "$type" == "slave" ]] && echo "masters { "$domain"; };" )  # aaddress of the master server
    };

END
    
    elif [[ "$OVERWRITE" == 'n' && "$rev_choice" == 'n' ]]; then
    echo "overwriting named.conf.local file"
    cat <<END >> /etc/bind/named.conf.local #APPENDS THE FILE UNTIL END
    ---Auto-DNS-CONFIG--
    zone "$domain" {
        type $type;
        $( if [[ "$type" == "slave" ]]; then 
            echo "file /var/cache/bind/db.$domain;"
        else
            echo "file $ZONE_FILE;"
        fi )
};
        $( [[ "$type" == "slave" ]] && echo "masters { "$domain"; };" )  # aaddress of the master server
    };

END
    elif [[ "$OVERWRITE" == 'n' && "$rev_choice" == 'y' ]]; then
        if [[ "$type" == "slave" ]]
                    IFS='.' read -r A B C D <<< "$SLAV_IP" #splits IP add by the periods and assigns each section  to a vairbale
                    REV_ZONE="${C}.${B}.${A}.in-addr.arpa"
                else
                    IFS='.' read -r A B C D <<< "$IP_ADDR" #splits IP add by the periods and assigns each section  to a vairbale
                    REV_ZONE="${C}.${B}.${A}.in-addr.arpa"


    REV_FILE="$ZONE_PATH/db.${REV_ZONE}"

    echo "overwriting named.conf.local file"
    cat <<END >> /etc/bind/named.conf.local #aPPENDS THE FILE UNTIL END
    ---Auto-DNS-CONFIG--

    zone "$domain" {
        type $type;
        $( if [[ "$type" == "slave" ]]; then 
            echo "file /var/cache/bind/db.$domain;"
        else
            echo "file $ZONE_FILE;"
        fi )
};
        $( [[ "$type" == "slave" ]] && echo "masters { "$domain"; };" )  # aaddress of the master server
    };

    zone "$REV_ZONE" {
        type $type;
        $( if [[ "$type" == "slave" ]]; then 
            echo "file /var/cache/bind/db.$REV_ZONE;"
        else
            echo "file $REV_FILE;"
        fi )
};
        $( [[ "$type" == "slave" ]] && echo "masters { "$domain"; };" )  # aaddress of the master server
    };

END
   fi 
   echo "named.conf.local files modified. Now making zone files...."
    
 
   if [[ "$rev_choice" == 'n' && "$type" == "slave" ]]; then
   
    echo "Creating forward zone file: $ZONE_FILE"
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
    # Reverse Zone File
    echo "Creating reverse zone file: $REV_FILE"
    echo "making correct permissions"
    sudo chown named:named /var/cache/bind/db.$REV_ZONE
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
    echo "Creating forward zone file: $ZONE_FILE"
    echo "making correct permissions"
    sudo chown named:named /var/cache/bind/db.$domain
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
    sudo chown named:named $ZONE_FILE
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

if [[ "$rev_choice" == 'y' && "$type" == "slave" ]]; then
    # Reverse Zone File
    echo "Creating reverse zone file: $REV_FILE"
    echo "making correct permissions"
    sudo chown named:named $REV_FILE
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
    echo "Creating forward zone file: $ZONE_FILE"
    echo "making correct permissions"
    sudo chown named:named $ZONE_FILE
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












    

fi