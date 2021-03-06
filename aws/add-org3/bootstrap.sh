#!/bin/bash

##############################################################
# Variables
##############################################################
if [ -z ${TEST_CHAINCODE_NAME} ]; then
  echo "TEST_CHAINCODE_NAME is required."
  exit 1;
fi

if [ -z ${TEST_CHANNEL_NAME} ]; then
  echo "TEST_CHANNEL_NAME is required."
  exit 1;
fi

if [ -z "${ORG_NAME}" ]; then
  echo "ORG_NAME is required."
  exit 1;
fi

if [ -z "${ORG_DOMAIN}" ]; then
  echo "ORG_DOMAIN is required."
  exit 1;
fi

if [ -z "${HOST_ORG_DOMAIN}" ]; then
  echo "HOST_ORG_DOMAIN is required."
  exit 1;
fi

if [ -z "${ORDERER_ORG_DOMAIN}" ]; then
  echo "ORDERER_ORG_DOMAIN is required."
  exit 1;
fi

FABRIC_RESOURCES_DIR="${PWD}/bootstrap/resources/hyperledger"
CLI_RESOURCES_DIR="${PWD}/cli-tools"
NGINX_RESOURCES_DIR="${PWD}/bootstrap/resources/nginx"
CRYPTO_CONFIG_FILE="crypto.yaml"
ORDERER_TLS_CA_CERT_FILE="tlsca.ordererorg-cert.pem"
ORDERER_ORG_DNS_NAME_FILE="public-load-balancer-dns-name.org1"
FABRIC_CFG_FILE="configtx.yaml"
CHANNEL_ARTIFACT="channel-artifact.json"
INTERVAL=1
DOCKER_NETWORK="hyperledger"
ORDERER_ORG_HOSTNAME="orderer0"
OUTPUT_CRYPTO_DIR="crypto"
ORDERER_TLS_CA_CERT_DIR="ordererOrganizations/ordererorg/msp/tlscacerts/"
CA_MSP_DIR="${OUTPUT_CRYPTO_DIR}/peerOrganizations/${ORG_DOMAIN}/ca/"

export FABRIC_CFG_PATH=${PWD}

##############################################################
# Preprocessing : Create resource files
##############################################################
# CREATE CRYPTO CONFIG FILE
rm -rf ${CRYPTO_CONFIG_FILE}
cat << EOF >> ${CRYPTO_CONFIG_FILE}
---
PeerOrgs:
  - Name: ${ORG_NAME}
    Domain: ${ORG_DOMAIN}
    EnableNodeOUs: true
    Template:
      Count: 2
    Users:
      Count: 1
EOF

# CREATE FABRIC CFG FILE
rm -rf ${FABRIC_CFG_FILE}
cat << EOF >> ${FABRIC_CFG_FILE}
---
Organizations:
  - &${ORG_NAME}
    Name: ${ORG_NAME}
    ID: ${ORG_NAME}MSP
    MSPDir: ${FABRIC_RESOURCES_DIR}/${OUTPUT_CRYPTO_DIR}/peerOrganizations/${ORG_DOMAIN}/msp
    AnchorPeers:
      - Host: peer0.${ORG_DOMAIN}
        Port: 7051
EOF

##############################################################
# Check resource files exist
##############################################################
[ -e ./${CRYPTO_CONFIG_FILE} ] && echo "${CRYPTO_CONFIG_FILE}: OK" || { echo "${CRYPTO_CONFIG_FILE} could not found."; exit 1; }
#[ -e ./${FABRIC_RESOURCES_DIR}/.env ] && echo ".env: OK" || { echo ".env  could not found."; exit 1; }
[ -e ./${FABRIC_CFG_FILE} ] && echo "${FABRIC_CFG_FILE}: OK" || { echo "${FABRIC_CFG_FILE} could not found."; exit 1; }
[ -e ./${ORDERER_TLS_CA_CERT_FILE} ] && echo "${ORDERER_TLS_CA_CERT_FILE}: OK" || { echo "${ORDERER_TLS_CA_CERT_FILE} could not found."; exit 1; }
[ -e ./${ORDERER_ORG_DNS_NAME_FILE} ] && echo "${ORDERER_ORG_DNS_NAME_FILE}: OK" || { echo "${ORDERER_ORG_DNS_NAME_FILE} could not found."; exit 1; }

##############################################################
# Create crypto materials
##############################################################
if [ -e ${FABRIC_RESOURCES_DIR}/${OUTPUT_CRYPTO_DIR} ]; then
  rm -rf ${FABRIC_RESOURCES_DIR}/${OUTPUT_CRYPTO_DIR}
  rm -rf ${CLI_RESOURCES_DIR}/${OUTPUT_CRYPTO_DIR}
fi
cryptogen generate --config=${CRYPTO_CONFIG_FILE} --output=${FABRIC_RESOURCES_DIR}/${OUTPUT_CRYPTO_DIR}
cp -avR ${FABRIC_RESOURCES_DIR}/${OUTPUT_CRYPTO_DIR} ${CLI_RESOURCES_DIR}
sleep ${INTERVAL}

#############################################################
# COPY Orderer TLS CERT
##############################################################
mkdir -p ${FABRIC_RESOURCES_DIR}/${OUTPUT_CRYPTO_DIR}/${ORDERER_TLS_CA_CERT_DIR}
cp ${ORDERER_TLS_CA_CERT_FILE} ${FABRIC_RESOURCES_DIR}/${OUTPUT_CRYPTO_DIR}/${ORDERER_TLS_CA_CERT_DIR}
mkdir -p ${CLI_RESOURCES_DIR}/${OUTPUT_CRYPTO_DIR}/${ORDERER_TLS_CA_CERT_DIR}
cp ${ORDERER_TLS_CA_CERT_FILE} ${CLI_RESOURCES_DIR}/${OUTPUT_CRYPTO_DIR}/${ORDERER_TLS_CA_CERT_DIR}
sleep ${INTERVAL}

##############################################################
# Create .env for fabric
##############################################################
server_keyfile=$(tree ${CA_MSP_DIR} | grep "sk" | awk '{print $2}')
rm -rf ${FABRIC_RESOURCES_DIR}/.env
cat << EOF >> ${FABRIC_RESOURCES_DIR}/.env
TEST_CHANNEL_NAME=${TEST_CHANNEL_NAME}
TEST_CHAINCODE_NAME=${TEST_CHAINCODE_NAME}
ORDERER_ORG_HOSTNAME=${ORDERER_ORG_HOSTNAME}
ORDERER_ORG_DOMAIN=${ORDERER_ORG_DOMAIN}
HOST_ORG_DOMAIN=${HOST_ORG_DOMAIN}
ORG_NAME=${ORG_NAME}
ORG_DOMAIN=${ORG_DOMAIN}
DOCKER_NETWORK=${DOCKER_NETWORK}
FABRIC_CA_SERVER_CA_KEYFILE=${server_keyfile}

EOF
sleep ${INTERVAL}

##############################################################
# Create .env for nginx
##############################################################
rm -rf ${NGINX_RESOURCES_DIR}/.env
cat << EOF >> ${NGINX_RESOURCES_DIR}/.env
ORDERER_ORG_HOSTNAME=${ORDERER_ORG_HOSTNAME}
ORDERER_ORG_DOMAIN=${ORDERER_ORG_DOMAIN}
HOST_ORG_DOMAIN=${HOST_ORG_DOMAIN}
HOST_ORG_GW_IP=$(cat "./public-load-balancer-dns-name.org1")
ORG_NAME=${ORG_NAME}
ORG_DOMAIN=${ORG_DOMAIN}
DOCKER_NETWORK=${DOCKER_NETWORK}

EOF
sleep ${INTERVAL}

#############################################################
# Prepare artifacts dir
##############################################################
if [ -e ./artifacts ]; then
  rm -rf ./artifacts
fi
mkdir ./artifacts

##############################################################
# Create Org3 channel config
##############################################################
configtxgen -printOrg ${ORG_NAME} > ./artifacts/${CHANNEL_ARTIFACT}
sleep ${INTERVAL}

#############################################################
# Bootstrap network
##############################################################
pushd bootstrap

terraform init
terraform apply -auto-approve
# replace route-table of private-subnet
sed -i.bak 's/public/private/g' n-private-subnet.tf
terraform apply -auto-approve

echo "aws_lb.public-load-balancer.dns_name" | terraform console > ../artifacts/public-load-balancer-dns-name.org3

popd

rm -rf ${CLI_RESOURCES_DIR}/.env
cat << EOF >> ${CLI_RESOURCES_DIR}/.env
TEST_CHANNEL_NAME=${TEST_CHANNEL_NAME}
TEST_CHAINCODE_NAME=${TEST_CHAINCODE_NAME}
ORDERER_ORG_HOSTNAME=${ORDERER_ORG_HOSTNAME}
ORDERER_ORG_DOMAIN=${ORDERER_ORG_DOMAIN}
ORG_NAME=${ORG_NAME}
ORG_DOMAIN=${ORG_DOMAIN}
DOCKER_NETWORK=${DOCKER_NETWORK}

MY_ORG_NLB_PUBLIC_IP=$(cat "./artifacts/public-load-balancer-dns-name.org3" | xargs arp | awk '{print substr($2, 2, length($2)-2)}')
ORDERER_ORG_NLB_PUBLIC_IP=$(cat "./public-load-balancer-dns-name.org1" | xargs arp | awk '{print substr($2, 2, length($2)-2)}')
EOF
