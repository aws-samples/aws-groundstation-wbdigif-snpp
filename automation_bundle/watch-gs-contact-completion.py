#!/usr/bin/python3

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

# The script detects completion of AWS Grond Station contact (detected via `Contact` EC2 tag),
# and invokes SDR-specific contact completion script.
# The SDR-specific completion script may flush SDR buffers, stop the modem, and upload the decoded
# data and session report to S3.

import os
import time
import boto3
import logging
from ec2_metadata import ec2_metadata

sdr_script_path = '/home/ubuntu/sdr-contact-completed.sh'

logging.basicConfig(format='%(asctime)s %(message)s', level=logging.INFO)

ec2_resource = boto3.resource('ec2',region_name=ec2_metadata.region)

while(True):
    logging.info('Checking Contact status')
    ec2_instance = ec2_resource.Instance(ec2_metadata.instance_id)
    tags = ec2_instance.tags

    for tag in tags:
        if tag['Key'] == 'Contact':
            logging.info('Contact status: %s' % tag['Value'])
        if tag['Key'] == 'Contact' and tag['Value'] == 'COMPLETED':
            logging.info('Setting the Contact status to SDR_COMPLETION')
            ec2_instance.create_tags(
                Resources=[ec2_metadata.instance_id],
                Tags=[{
                    'Key': 'Contact',
                    'Value': 'SDR_COMPLETION'
                }]
            )

            logging.info('Invoking SDR-specific contact completion script')
            os.system(sdr_script_path)
            logging.info('Finished SDR-specific contact completion script')
            break

    time.sleep(10)
