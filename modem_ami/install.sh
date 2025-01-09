#!/bin/bash

# Copyright 2023 Amphinicy Technologies
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions
# and limitations under the License.
#
# This script applies custom configuration to Blink AMI for wideband Suomi NPP reception
# (offset by 113MHz, central freq. 7925, 350 MHz bandwidth)
#

TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)

BLINK_ADMIN_PASSWORD=$INSTANCE_ID

tmpDir=/tmp/blink-tmp

function backup_file {
    if [ -f "${1}" ]; then
    mv "${1}" "${1}.bak"
    echo -e "Backup created for ${1}"
    fi
}

systemctl stop blink-dsp.service
systemctl stop blink-snmp.service

mkdir ${tmpDir}
tar -xvf modem_ami.tar.gz -C ${tmpDir}

backup_file /etc/blink/dsp/CCSDS_VITA_Suomi_BW350.xml
cp ${tmpDir}/modem_ami/dsp/CCSDS_VITA_Suomi_BW350.xml /etc/blink/dsp/
chown blink-dsp:blink-dsp /etc/blink/dsp/CCSDS_VITA_Suomi_BW350.xml

backup_file /etc/blink/dsp/controller.conf
cp ${tmpDir}/modem_ami/dsp/controller.conf /etc/blink/dsp/
chown blink-dsp:blink-dsp /etc/blink/dsp/controller.conf

backup_file /usr/share/blink-dsp/bin/blink-dsp-start
cp ${tmpDir}/modem_ami/dsp/blink-dsp-start /usr/share/blink-dsp/bin/
chmod +x /usr/share/blink-dsp/bin/blink-dsp-start
chown blink-dsp:blink-dsp /usr/share/blink-dsp/bin/blink-dsp-start

backup_file /etc/blink/dsp/license
cp ${tmpDir}/modem_ami/fep/license /etc/blink/dsp/
chown blink-dsp:blink-dsp /etc/blink/dsp/license

backup_file /etc/blink/fep-rx/license
cp ${tmpDir}/modem_ami/fep/* /etc/blink/fep-rx/
chown blink:blink /etc/blink/fep-rx/license

backup_file /usr/share/blink/bin/blink-start
cp ${tmpDir}/modem_ami/fep/blink-start /usr/share/blink/bin/
chmod +x /usr/share/blink/bin/blink-start
chown blink:blink /usr/share/blink/bin/blink-start

backup_file /usr/share/blink-config/bin/stop.sh
cp ${tmpDir}/modem_ami/config_service/stop.sh /usr/share/blink-config/bin/
chmod +x /usr/share/blink-config/bin/stop.sh
chown blink:blink /usr/share/blink-config/bin/stop.sh
mkdir /usr/share/blink-config/etc/
chown blink:blink /usr/share/blink-config/etc/


systemctl start blink-snmp.service
sleep 5

systemctl start blink-dsp.service
sleep 2


echo -e "\nFetching auth token ..."
bearerToken=$(curl -o ${tmpDir}/headers.txt -X POST https://localhost/mnc/rest/security/login -u "blink-admin:${BLINK_ADMIN_PASSWORD}" -H "Content-Type: application/json" -H "Content-Length: 0" -k --head && cat ${tmpDir}/headers.txt | awk '/Authorization/ {printf $3}')
echo -e "\nbearerToken fetched: ${bearerToken}"

echo -e "\nStarting virtual instrument update ..."
curl -H "Authorization: Bearer ${bearerToken}" -H "Content-Type: application/json" -k --location --request PUT 'https://localhost/mnc/rest/instrument-manager/virtual-instruments/blink-modem' \
-d @"${tmpDir}/modem_ami/mnc/VIRTUAL_INSTRUMENTS/virtual_instruments.json"
sleep 1

echo -e "\nStopping TX adapters ..."
curl -H "Authorization: Bearer ${bearerToken}" -H "Content-Type: text/plain" -k --location --request PUT 'https://localhost/mnc/rest/instrument-manager/instruments/mode?instrumentNames=BlinkDSPTX,BlinkFEPTX' \
--data-raw "STOPPED"
echo -e "\nTX adapters stopped."
sleep 1

echo -e "\nLogging out ..."
curl -H "Authorization: Bearer ${bearerToken}" -H "Content-Type: application/json" -k --location --request POST "https://localhost/mnc/rest/security/logout"
sleep 1

systemctl stop blink-dsp-tx.service
systemctl stop blink-snmp-tx.service
systemctl disable blink-dsp-tx.service
systemctl disable blink-snmp-tx.service

echo -e "Changing MNC docker container's CPU affinities"
docker update --cpuset-cpus 11-23,26-47,59-71,74-94 mnc_nginx
docker update --cpuset-cpus 11-23,26-47,59-71,74-94 mnc_standalone
docker update --cpuset-cpus 11-23,26-47,59-71,74-94 mncdocker-timescaledb-1
docker update --cpuset-cpus 11-23,26-47,59-71,74-94 mnc_postgres

systemctl restart blink-config.service
sleep 2

echo -e "Blink modem configuration pack installation complete."
