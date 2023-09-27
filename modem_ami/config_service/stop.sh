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
# This is called to stop the modem processing after contact is done and
# upload contact report to S3 bucket. Do not modify.


# INITIALISE
S3_BUCKET_NAME=$(cat /usr/share/blink-config/etc/s3-bucket-name.txt)
BLINK_LAST_REPORT=$(blink-snmp-get report.file.path)
BLINK_REPORT_UPLOADED=""

# FUNCTIONS
function stop {
        echo -e "running false;\n";
}

function upload_and_notify() {
  TIME=$(date '+%Y/%m/%d %H:%M:%S')
  DATE=$(date '+%Y-%m-%d')

  REPORT_FILE_PATH=$1

  REPORT_FILE_NAME=$(echo $REPORT_FILE_PATH | rev | cut -d"/" -f1  | rev)

  aws s3 cp $REPORT_FILE_PATH s3://$S3_BUCKET_NAME/Blink/$DATE/$REPORT_FILE_NAME
  sleep 5 # wait for S3 upload consistency
}

BLINK_STATUS=$(blink-snmp-get processing.status)

stop | nc localhost 1669 -w 1

sleep 10
STOP=$(blink-snmp-set stop.acq)

while [[ "$BLINK_STATUS" != "STOPPED" ]]
do
  sleep 1
  BLINK_STATUS=$(blink-snmp-get processing.status)
done

BLINK_LAST_REPORT=$(blink-snmp-get report.file.path)
LEN=$(expr length "$BLINK_LAST_REPORT")

if [[ "$LEN" -gt 0 && "$BLINK_REPORT_UPLOADED" != "$BLINK_LAST_REPORT" ]]; then
  upload_and_notify "/var/blink/out/$BLINK_LAST_REPORT"
  BLINK_REPORT_UPLOADED=$BLINK_LAST_REPORT
fi

sleep 5

# Call shutdown script provided by AWS

source /home/ubuntu/stop-instance.sh