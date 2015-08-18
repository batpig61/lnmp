#!/bin/bash
# Author:  yeho <lj2007331 AT gmail.com>
# BLOG:  https://blog.linuxeye.com
#
# Notes: OneinStack for CentOS/RadHat 5+ Debian 6+ and Ubuntu 12+
#
# Project home page:
#       http://oneinstack.com
#       https://github.com/lj2007331/oneinstack

export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
clear
printf "
#######################################################################
#       OneinStack for CentOS/RadHat 5+ Debian 6+ and Ubuntu 12+      #
#                     Setup the backup parameters                     #
#       For more information please visit http://oneinstack.com       #
#######################################################################
"

. ./include/color.sh
. ./include/check_db.sh

# Check if user is root
[ $(id -u) != "0" ] && { echo "${CFAILURE}Error: You must be root to run this script${CEND}"; exit 1; }

while : 
do
    echo
    echo 'Please select your backup destination:'
    echo -e "\t${CMSG}1${CEND}. Only Localhost"
    echo -e "\t${CMSG}2${CEND}. Only Remote host"
    echo -e "\t${CMSG}3${CEND}. Localhost and remote host"
    read -p "Please input a number:(Default 1 press Enter) " DESC_BK 
    [ -z "$DESC_BK" ] && DESC_BK=1
    if [ $DESC_BK != 1 -a $DESC_BK != 2 -a $DESC_BK != 3 ];then
        echo "${CWARNING}input error! Please only input number 1,2,3${CEND}"
    else
        break
    fi
done

[ "$DESC_BK" == '1' ] && { sed -i 's@^local_bankup_yn=.*@local_bankup_yn=y@' ./options.conf; sed -i 's@remote_bankup_yn=.*@remote_bankup_yn=n@' ./options.conf; }
[ "$DESC_BK" == '2' ] && { sed -i 's@^local_bankup_yn=.*@local_bankup_yn=n@' ./options.conf; sed -i 's@remote_bankup_yn=.*@remote_bankup_yn=y@' ./options.conf; }
[ "$DESC_BK" == '3' ] && { sed -i 's@^local_bankup_yn=.*@local_bankup_yn=y@' ./options.conf; sed -i 's@remote_bankup_yn=.*@remote_bankup_yn=y@' ./options.conf; }

. ./options.conf
. ./include/check_db.sh

while :
do
    echo
    echo "Please enter the directory for save the backup file: "
    read -p "(Default directory: $backup_dir): " NEW_backup_dir 
    [ -z "$NEW_backup_dir" ] && NEW_backup_dir="$backup_dir"
    if [ -z "`echo $NEW_backup_dir| grep '^/'`" ]; then
        echo "${CWARNING}input error! ${CEND}"
    else
        break
    fi
done
sed -i "s@^backup_dir=.*@backup_dir=$NEW_backup_dir@" ./options.conf

while :
do
    echo
    echo "Pleas enter a valid backup number of days: "
    read -p "(Default days: 5): " expired_days 
    [ -z "$expired_days" ] && expired_days=5
    [ -n "`echo $expired_days | sed -n "/^[0-9]\+$/p"`" ] && break || echo "${CWARNING}input error! Please only enter numbers! ${CEND}"
done
sed -i "s@^expired_days=.*@expired_days=$expired_days@" ./options.conf

databases=`$db_install_dir/bin/mysql -uroot -p$dbrootpwd -e "show databases\G" | grep Database | awk '{print $2}' | grep -Evw "(performance_schema|information_schema|mysql)"`
while :
do
    echo
    echo "Please enter one or more name for database, separate multiple database names with commas: "
    read -p "(Default database: `echo $databases | tr ' ' ','`) " db_name
    db_name=`echo $db_name | tr -d ' '`
    [ -z "$db_name" ] && db_name="`echo $databases | tr ' ' ','`"
    D_tmp=0
    echo $db_name
    for D in `echo $db_name | tr ',' ' '`
    do
        [ -z "`echo $databases | grep -w $D`" ] && { echo "${CWARNING}$D was not exist! ${CEND}" ; D_tmp=1; }
    done
    [ "$D_tmp" != '1' ] && break
done
sed -i "s@^db_name=.*@db_name=$db_name@" ./options.conf

websites=`ls $wwwroot_dir | grep -vw default`
while :
do
    echo
    echo "Please enter one or more name for website, separate multiple website names with commas: "
    read -p "(Default website: `echo $websites | tr ' ' ','`) " website_name 
    website_name=`echo $website_name | tr -d ' '`
    [ -z "$website_name" ] && website_name="`echo $websites | tr ' ' ','`"
    W_tmp=0
    echo $db_name
    for W in `echo $website_name | tr ',' ' '`
    do
        [ ! -e "$wwwroot_dir/$W" ] && { echo -e "\033[31m$wwwroot_dir/$W not exist! \033[0m" ; W_tmp=1; }
    done
    [ "$W_tmp" != '1' ] && break
done
echo $website_name
sed -i "s@^website_name=.*@website_name=$website_name@" ./options.conf

if [ "$remote_bankup_yn" == 'y' ];then
    > tools/iplist.txt
    while :
    do
        echo
        read -p "Please enter the remote host ip: " remote_ip
        [ -z "$remote_ip" -o "$remote_ip" == '127.0.0.1' ] && continue
        echo
        read -p "Please enter the remote host port(Default: 22) : " remote_port
        [ -z "$remote_port" ] && remote_port=22 
        echo
        read -p "Please enter the remote host user(Default: root) : " remote_user
        [ -z "$remote_user" ] && remote_user=root 
        echo
        read -p "Please enter the remote host password: " remote_password
        IPcode=$(echo "ibase=16;$(echo "$remote_ip" | xxd -ps -u)"|bc|tr -d '\\'|tr -d '\n')
        Portcode=$(echo "ibase=16;$(echo "$remote_port" | xxd -ps -u)"|bc|tr -d '\\'|tr -d '\n')
        PWcode=$(echo "ibase=16;$(echo "$remote_password" | xxd -ps -u)"|bc|tr -d '\\'|tr -d '\n')
        [ -e "~/.ssh/known_hosts" ] && grep $remote_ip ~/.ssh/known_hosts | sed -i "/$remote_ip/d" ~/.ssh/known_hosts
        ./tools/mssh.exp ${IPcode}P $remote_user ${PWcode}P ${Portcode}P true 10
        if [ $? -eq 0 ];then
            [ -z "`grep $remote_ip tools/iplist.txt`" ] && echo "$remote_ip $remote_port $remote_user $remote_password" >> tools/iplist.txt || echo "${CWARNING}$remote_ip has been added! ${CEND}" 
            while :
            do
                echo
                read -p "Do you want to add more host ? [y/n]: " more_host_yn 
                if [ "$more_host_yn" != 'y' -a "$more_host_yn" != 'n' ];then
                    echo "${CWARNING}input error! Please only input 'y' or 'n'${CEND}"
                else
                    break
                fi
            done
            [ "$more_host_yn" == 'n' ] && break
        fi
    done
fi
