#!\bin\bash

if [ "$EUID"  -ne 0 ]; #if the EUID is not root
then echo "Please run as root"
    exit 1 #exits
else
    if ! systemctl list-units --type=service --all | grep 'bind*|named*' ; #looks at all the sercies ont ehsystme looking for named
        then echo "BIND9 package not found. Downloading now!!"
        sudo apt-install bind9 -y #installs bind9
    else
        echo "Bind or Name service Found"

    read -p "Enter the domain you want configured: " domain  #takes user input  (-p) shows a message before
    domain=${domain:-example.com}
    echo "configuring: $domain"
    fi

fi