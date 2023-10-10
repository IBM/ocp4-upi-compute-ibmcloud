#!/usr/bin/env bash

################################################################
# Copyright 2023 - IBM Corporation. All rights reserved
# SPDX-License-Identifier: Apache-2.0
################################################################

# Upload RHCOS to ibmcloud cos and starts an import

API_KEY="${1}"
SERVICE_INSTANCE_ID="${2}"
REGION="${3}"
RESOURCE_GROUP="${4}"
NAME_PREFIX="${5}"

if [ -z "$(command -v ibmcloud)" ]
then
  echo "ibmcloud CLI doesn't exist, installing"
  curl -fsSL https://clis.cloud.ibm.com/install/linux | sh
fi

ibmcloud login --apikey "${API_KEY}" -r "${REGION}" -g "${RESOURCE_GROUP}"
ibmcloud plugin install -f cloud-internet-services vpc-infrastructure cloud-object-storage power-iaas is

# Download the RHCOS qcow2
TARGET_DIR=".openshift/image-local"
mkdir -p ${TARGET_DIR}
DOWNLOAD_URL=$(openshift-install coreos print-stream-json | jq -r '.architectures.x86_64.artifacts.ibmcloud.formats."qcow2.gz".disk.location')
TARGET_GZ_FILE=$(echo "${DOWNLOAD_URL}" | sed 's|/| |g' | awk '{print $NF}')
TARGET_FILE=$(echo "${TARGET_GZ_FILE}" | sed 's|.gz||g')

if [ "${TARGET_FILE}" == "" ]
then
  echo "Downloading from URL - ${DOWNLOAD_URL}"
  cd "${TARGET_DIR}" \
    && curl -o "${TARGET_GZ_FILE}" -L "${DOWNLOAD_URL}" \
    && gunzip ${TARGET_GZ_FILE} && cd -
fi

# Create a bucket
ibmcloud cos bucket-create --bucket "${NAME_PREFIX}-bucket" \
    --ibm-service-instance-id "${SERVICE_INSTANCE_ID}" --class smart --region "${REGION}" --json

# Upload the file
TARGET_KEY=$(echo ${TARGET_FILE} | sed 's|[._]|-|g')
#ibmcloud cos --bucket "${NAME_PREFIX}-bucket" \
#  --region "${REGION}" --key "${TARGET_KEY}" --file "${TARGET_DIR}/${TARGET_FILE}"
ibmcloud cos object-put --bucket "${NAME_PREFIX}-bucket" --key "${TARGET_FILE}" --body "${TARGET_DIR}/${TARGET_FILE}"
