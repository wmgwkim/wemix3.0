#!/bin/bash

main () {
echo "#############################################################################"
echo "[1] 의존성 패키지 설치"
sudo apt-get update
sudo apt-get install -y build-essential
echo "#############################################################################"


echo "#############################################################################"
echo "[2] 데이터 디럭터리 생성"
mkdir -p /data/wemix/logs /data/wemix/keystore /data/wemix/geth
grep -qxF 'export GWEMIX_HOME=/data/wemix' ~/.profile || echo 'export GWEMIX_HOME=/data/wemix' >> ~/.profile
. ~/.profile
echo "#############################################################################"


echo "#############################################################################"
echo "[3] go 설치"
mkdir /data/lang
wget https://go.dev/dl/go1.19.3.linux-amd64.tar.gz -P /data/lang
tar -xzf /data/lang/go1.19.3.linux-amd64.tar.gz -C /data/lang
grep -qxF 'export PATH=$PATH:/data/lang/go/bin' ~/.profile || echo 'export PATH=$PATH:/data/lang/go/bin' >> ~/.profile
. ~/.profile
go version
echo "#############################################################################"

echo "#############################################################################"
echo "[4] snappy lib 설치"
# snappy lib 설치
sudo apt install -y libsnappy-dev libjemalloc-dev
sudo ln -sf /usr/lib/x86_64-linux-gnu/libjemalloc.so.2 /usr/lib/x86_64-linux-gnu/libjemalloc.so.1
echo "#############################################################################"

echo "#############################################################################"
echo "[5] wemix3.0 (gwemix) 세팅"

git clone https://github.com/wemixarchive/go-wemix.git /data/go-wemix
sleep 5

# 컴파일
cd /data/go-wemix ; make

# gwemix 파일 이동
cp /data/go-wemix/build/gwemix.tar.gz /data/wemix/
tar -xzf /data/wemix/gwemix.tar.gz -C /data/wemix/

sudo ln -s /data/wemix /opt/wemix
rm /data/wemix/wemix

grep -qxF 'export PATH=$PATH:$GWEMIX_HOME/bin' ~/.profile || echo 'export PATH=$PATH:$GWEMIX_HOME/bin' >> ~/.profile
. ~/.profile

echo "#############################################################################"


echo "#############################################################################"
echo "[6] account, genesis 파일 생성"

gwemix wemix new-nodekey --out /data/wemix/geth/nodekey
sleep 2

echo "password" > /data/wemix/conf/account_passwd1
sleep 2

WALLET_ADD_TMP=$(gwemix account import --password /data/wemix/conf/account_passwd1 /data/wemix/geth/nodekey | grep -i Address | awk -F "{" '{print $2}' | tr -d "}")
echo "Address: {$WALLET_ADD_TMP}"
sleep 2

mv /root/.wemix/keystore/*$WALLET_ADD_TMP /data/wemix/keystore/account_key1

# account 정보 저장
NODEKEY=$(cat /data/wemix/geth/nodekey)
WALLET_ADD=$(cat /data/wemix/keystore/account_key1 | awk -F "," '{print $1}' | awk -F "\"" '{print $4}')
NODE_ID=$(gwemix wemix nodeid /data/wemix/geth/nodekey | grep -i "idv5" | awk -F ": " '{print $2}')

echo "[`date`]" >> /data/wemix/conf/account_info
echo "nodekey (/data/wemix/geth/nodekey)    : $NODEKEY" >> /data/wemix/conf/account_info
echo " |-wallet address                     : 0x$WALLET_ADD" >> /data/wemix/conf/account_info
echo " |-node idv5                          : 0x$NODE_ID" >> /data/wemix/conf/account_info
echo "" >> /data/wemix/conf/account_info

echo "# cat /data/wemix/conf/account_info"
cat /data/wemix/conf/account_info
echo ""



# config 파일 작성

WALLET_ADD="0x"$(cat /data/wemix/keystore/account_key1 | awk -F "," '{print $1}' | awk -F "\"" '{print $4}')
NODE_ID="0x"$(gwemix wemix nodeid /data/wemix/geth/nodekey | grep -i "idv5" | awk -F ": " '{print $2}')
PRIVATE_IP=$(ip -4 a show eth0 | grep -i inet | awk '{print $2}' | tr -d "/24")


cat <<EOF > /data/wemix/config.json
{
  "extraData": "The beginning of Wemix3.0 testnet on July 1st, 2022",
  "staker": "$WALLET_ADD",
  "ecosystem": "$WALLET_ADD",
  "maintenance": "$WALLET_ADD",
  "members": [
    {
      "addr": "$WALLET_ADD",
      "stake": 1500000000000000000000000,
      "name": "wemix1",
      "id": "$NODE_ID",
      "ip": "$PRIVATE_IP",
      "port": 8589,
      "bootnode": true
    }
  ],
  "accounts": [
    {
      "addr": "$WALLET_ADD",
      "balance": 200000000000000000000000000000
    }
  ]
}
EOF

echo "# cat /data/wemix/config.json"
cat /data/wemix/config.json
echo ""

# genesis 파일 생성
echo "# gwemix.sh init wemix /data/wemix/config.json"
gwemix.sh init wemix /data/wemix/config.json
echo ""

echo "# cat /data/wemix/genesis.json"
cat /data/wemix/genesis.json
echo ""
echo "#############################################################################"
echo "#############################################################################"
echo "[7] rc 파일 생성"
echo ""

cat << EOF > /data/wemix/.rc
PORT=8588
DISCOVER=1 # 1 for enable discovery mode, 0 for disable discovery mode
SYNC_MODE=full
GWEMIX_OPTS="--txpool.nolocals --snapshot=false --maxpeers=100"
EOF

echo "# cat /data/wemix/.rc"
cat /data/wemix/.rc

echo "#############################################################################"
echo "#############################################################################"
echo "DONE! "
}


main | tee /root/install.log
