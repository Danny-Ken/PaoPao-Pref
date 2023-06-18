#!/bin/sh
IPREX4='([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\.([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\.([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\.([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-5])'
touch /tmp/inrule.txt
if [ -f /pub/tlds.txt ]; then
    cat /pub/tlds.txt >>/data/inrule.txt
fi
if [ -f /pub/cn.txt ]; then
    cat /pub/cn.txt >>/tmp/inrule.txt
fi
cat /data/inrule.txt >>/tmp/inrule.txt

paopao-pref -inrule /tmp/inrule.txt -outrule /tmp/force_nocn_list.txt
if [ "$SYSDNS" = "no" ]; then
    touch /tmp/delay.txt
    while read dnsserver; do
        sed "s/{ser1}/$dnsserver/g" test_cn.yaml | sed "s/#dns_check//g" >/tmp/test_cn.yaml
        mosdns start -d /tmp -c test_cn.yaml >/dev/null 2>&1 &
        sleep 1
        delay=$(paopao-pref -server 127.0.0.1 -delay) && echo "$delay"",""$dnsserver" >>/tmp/delay.txt && echo "$dnsserver"": ""$delay"" ms"
        killall mosdns
    done <dns_list.txt
    cat /tmp/delay.txt
    sort -n /tmp/delay.txt | cut -d "," -f2 | head -3 >/tmp/dns_list.txt
    cat /tmp/dns_list.txt
else
    cat /etc/resolv.conf | grep -Eo "$IPREX4" >/tmp/dns_list.txt
fi
ser_num=$(cat /tmp/dns_list.txt | wc -l)
if [ "$ser_num" = "0" ]; then
    echo "no dns available."
    exit
fi
ser1=$(head -1 /tmp/dns_list.txt)
ser2=$(head -2 /tmp/dns_list.txt | tail -1)
ser3=$(tail -1 /tmp/dns_list.txt)
cp test_cn.yaml /tmp/gen_mark.yaml
if [ "$ser_num" -gt 0 ]; then
    sed -i "s/#gen_mark//g" /tmp/gen_mark.yaml
    sed -i "s/{ser1}/$ser1/g" /tmp/gen_mark.yaml
fi

if [ "$ser_num" -gt 1 ]; then
    sed -i "s/#ser_num2//g" /tmp/gen_mark.yaml
    sed -i "s/{ser2}/$ser2/g" /tmp/gen_mark.yaml
fi

if [ "$ser_num" -gt 2 ]; then
    sed -i "s/#ser_num3//g" /tmp/gen_mark.yaml
    sed -i "s/{ser3}/$ser3/g" /tmp/gen_mark.yaml
fi

mosdns start -d /tmp -c gen_mark.yaml &
sleep 1

touch domains_ok.txt
ps
cat /tmp/force_nocn_list.txt >>/domains.txt
paopao-pref -inrule /domains.txt -outrule /data/domains.txt
echo "Start pref..."
paopao-pref -server 127.0.0.1 >/data/pref.log
cat /data/inrule.txt >>/data/domains_ok.txt
paopao-pref -inrule /data/domains_ok.txt -outrule /data/global_mark.dat
if [ "$TEST" = "debug" ]; then
    cp /data/global_mark.dat /pub/raw.dat
    cp /data/pref.log /pub/
fi
xz -9 -e global_mark.dat
datsha=$(sha512sum global_mark.dat.xz | cut -d" " -f1)
echo -n $datsha >sha.txt
shasize=$(wc -c <sha.txt)
dd if=/dev/zero of=sha.txt bs=1 count=$((1024 - shasize)) seek=$shasize conv=notrunc
cat global_mark.dat.xz sha.txt >global_mark.dat
sha256sum global_mark.dat | cut -d" " -f1 >/pub/global_mark.dat.sha256sum
mv global_mark.dat /pub
