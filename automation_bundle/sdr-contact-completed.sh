#!/bin/bash

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

echo UDP statistics
netstat -s -u

echo Uploading GS Agent logs, syslog, and Blink logs to S3

S3BUCKET="s3://`cat /usr/share/blink-config/etc/s3-bucket-name.txt`"
S3FOLDER="Logs/`date "+%Y-%m-%d/%H-%M-%S"`"

aws s3 cp /var/log/syslog "${S3BUCKET}/${S3FOLDER}/"
aws s3 cp --recursive /var/log/aws/groundstation "${S3BUCKET}/${S3FOLDER}/"
aws s3 cp --recursive /var/log/blink-dsp "${S3BUCKET}/${S3FOLDER}/"
aws s3 cp --recursive /var/log/blink "${S3BUCKET}/${S3FOLDER}/"

echo Calling SDR-specific script to finish the contact

/usr/share/blink-config/bin/stop.sh
