#!/bin/bash

# import functions
source test-function.sh

GATEWAY_IP="127.0.0.1"
GATEWAY_ADDR="127.0.0.1:57999"
GATEWAY_ADDR_FOR_ORDERER1="127.0.0.1:57050"
GATEWAY_ADDR_FOR_PEER1="127.0.0.1:57051"
GATEWAY_ADDR_FOR_PEER2="127.0.0.1:58051"


###############################################################
# HEALTH CHECK
###############################################################

try "org1_gw health check"
out=$(curl $GATEWAY_ADDR/health --silent --stderr - | awk '{print $1}')
assert "OK" "$out"

###############################################################
# IP:PORT로 접속 테스트
###############################################################

try "-> org1_gw"
out=$(get_conn $GATEWAY_ADDR)
assert "$GATEWAY_ADDR" "$out"

###############################################################
# CN(Common Name) 확인 테스트
###############################################################

try "-> org3 g/w -> peer0.org3.example.com"
out=$(get_cn "peer0.org3.example.com:57051" "$GATEWAY_IP")
assert "CN=peer0.org3.example.com" "$out"
###############################################################

echo
echo "PASS: $tests_run tests run"

# for org1, ordererorg
# curl --resolve peer0.org1.example.com:7051:192.168.201.5 https://peer0.org1.example.com:7051 -k -s -v --stderr - | grep -a "CN=$CN"
# curl --resolve orderer0.ordererorg:7050:192.168.201.5 https://orderer0.ordererorg:7050 -k -s -v --stderr - | grep -a "CN=$CN"