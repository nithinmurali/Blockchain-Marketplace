#!/bin/bash

# Exit on first error, print all commands.
set -ev

# don't rewrite paths for Windows Git Bash users
export MSYS_NO_PATHCONV=1

docker-compose -f docker-compose.yaml down

docker-compose -f docker-compose.yaml up -d

# wait for Hyperledger Fabric to start
# incase of errors when running later commands, issue export FABRIC_START_TIMEOUT=<larger number>
export FABRIC_START_TIMEOUT=30
#echo ${FABRIC_START_TIMEOUT}
sleep ${FABRIC_START_TIMEOUT}

# Create the channel
docker exec -e "CORE_PEER_ID=cli1" -e "CORE_PEER_LOCALMSPID=SellerMSP" -e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/seller.om.com/users/Admin@seller.om.com/msp" cli1 peer channel create -o orderer.om.com:7050 -c mychannel -f /etc/hyperledger/configtx/channel.tx

sleep 30

# # Join peers
docker exec -e "CORE_PEER_ID=cli1" -e "CORE_PEER_LOCALMSPID=SellerMSP" -e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/seller.om.com/users/Admin@seller.om.com/msp" -e "CORE_PEER_ADDRESS=peer0.seller.om.com:7051" cli1 peer channel join -b mychannel.block

docker exec -e "CORE_PEER_ID=cli1" -e "CORE_PEER_LOCALMSPID=BuyerMSP" -e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/buyer.om.com/users/Admin@buyer.om.com/msp" -e "CORE_PEER_ADDRESS=peer0.buyer.om.com:7051" cli1 peer channel join -b mychannel.block

docker exec -e "CORE_PEER_ID=cli1" -e "CORE_PEER_LOCALMSPID=MarketplaceMSP" -e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/marketplace.om.com/users/Admin@marketplace.om.com/msp" -e "CORE_PEER_ADDRESS=peer0.marketplace.om.com:7051" cli1 peer channel join -b mychannel.block

# docker exec -e "CORE_PEER_ID=cli1" -e "CORE_PEER_LOCALMSPID=MarketplaceMSP" -e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/marketplace.om.com/users/Admin@marketplace.om.com/msp" -e "CORE_PEER_ADDRESS=peer0.marketplace.om.com:7051" cli1 peer channel join -b mychannel.block

sleep 20

CODE_VERSION=1.0

# deploy the code
docker exec -e "CORE_PEER_ID=cli1" -e "CORE_PEER_LOCALMSPID=MarketplaceMSP" -e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/marketplace.om.com/users/Admin@marketplace.om.com/msp" -e "CORE_PEER_ADDRESS=peer0.marketplace.om.com:7051" cli1 peer  chaincode install -n veefin-network -v $CODE_VERSION -l golang -p github.com/OM

docker exec -e "CORE_PEER_ID=cli1" -e "CORE_PEER_LOCALMSPID=SellerMSP" -e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/seller.om.com/users/Admin@seller.om.com/msp" -e "CORE_PEER_ADDRESS=peer0.seller.om.com:7051" cli1 peer  chaincode install -n veefin-network -v $CODE_VERSION -l golang -p github.com/OM

docker exec -e "CORE_PEER_ID=cli1" -e "CORE_PEER_LOCALMSPID=BuyerMSP" -e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/buyer.om.com/users/Admin@buyer.om.com/msp" -e "CORE_PEER_ADDRESS=peer0.buyer.om.com:7051" cli1 peer  chaincode install -n veefin-network -v $CODE_VERSION -l golang -p github.com/OM

sleep 5

# instantiate the code
docker exec -e "CORE_PEER_ID=cli1" -e "CORE_PEER_LOCALMSPID=MarketplaceMSP" -e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/marketplace.om.com/users/Admin@marketplace.om.com/msp" -e "CORE_PEER_ADDRESS=peer0.marketplace.om.com:7051" cli1 peer  chaincode instantiate -o orderer.om.com:7050 -C mychannel -n veefin-network -l golang -v $CODE_VERSION -c '{"Args":[""]}' -P "OR ('SellerMSP.member', 'BuyerMSP.member')"

sleep 3

docker exec -e "CORE_PEER_LOCALMSPID=SellerMSP" -e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/seller.om.com/users/Admin@seller.om.com/msp" -e "CORE_PEER_ADDRESS=peer0.seller.om.com:7051" -e "CORE_PEER_ID=cli1" cli1 peer chaincode invoke -o orderer.om.com:7050 -C mychannel -n veefin-network -c '{"function":"createItem","Args":["ITEM0", "10", "100", "Submitted"]}'

docker exec -e "CORE_PEER_LOCALMSPID=SellerMSP" -e "CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/seller.om.com/users/Admin@seller.om.com/msp" -e "CORE_PEER_ADDRESS=peer0.seller.om.com:7051" -e "CORE_PEER_ID=cli1" cli1 peer chaincode invoke -o orderer.om.com:7050 -C mychannel -n veefin-network -c '{"function":"queryAllItems","Args":[""]}'
