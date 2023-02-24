#!/bin/bash

if [ $(dpkg-query -W -f='${Status}' jq 2>/dev/null | grep -c "ok installed") -eq 0 ];
then
  sudo apt update
  sudo apt install -y jq
fi

read -r -p "Enter MY NODE IP (Default is localhost) : " IP
if [ ! -n "$IP" ]; then 
  IP="localhost"
fi

read -r -p "Enter SUI NETWORK (Default is devnet) : " SUI


if [ ! -n "$SUI" ]; then 
  SUI="https://fullnode.devnet.sui.io:443"
fi

echo '-------------------------------------'
echo $(date)    
echo "MYNODE: " $IP
echo "NETWORK: " $SUI
echo
TIMEOUT=10

check_port() {
  RESULT=$(echo quit | timeout --signal=9 $TIMEOUT telnet $IP $1 | grep "Escape character is" | wc -l)
  if [ $RESULT -eq "1" ]; then
    echo -e "PORT $1 :  \e[32mONLINE!\e[0m "
  else
    echo -e "PORT $1 : \e[31mUnavailable!  Please check your ports \e[0m"
    exit 0
  fi
}

check_port 9000
check_port 9184
printf "\n"

SUISTART=$(curl --location --request POST $SUI \
--header 'Content-Type: application/json' \
--data-raw '{ "jsonrpc":"2.0", "method":"sui_getTotalTransactionNumber","id":1}' 2>/dev/null | jq .result)

NODESTART=$(curl --location --request POST $IP:9000 \
--header 'Content-Type: application/json' \
--data-raw '{ "jsonrpc":"2.0", "method":"sui_getTotalTransactionNumber","id":1}' 2>/dev/null | jq .result)

echo "LASTEST: " $SUISTART " || MYNODE: "  $NODESTART " || SLOW: " $(($SUISTART - $NODESTART))

if [ $(($SUISTART - $NODESTART)) -lt 10 ]; then
  echo -e "--------\e[32mGOOD NODE!\e[0m---------"
fi
printf "\n"
for I in {1..10}; do
  sleep 1
  BAR="$(yes . | head -n ${I} | tr -d '\n')"
  printf "\rIN PROGRESS [%3d/100] %s" $((I * 10)) ${BAR}
done

printf "\n\n"

SUIEND=$(curl --location --request POST $SUI \
--header 'Content-Type: application/json' \
--data-raw '{ "jsonrpc":"2.0", "method":"sui_getTotalTransactionNumber","id":1}' 2>/dev/null | jq .result)

NODEEND=$(curl --location --request POST $IP:9000 \
--header 'Content-Type: application/json' \
--data-raw '{ "jsonrpc":"2.0", "method":"sui_getTotalTransactionNumber","id":1}' 2>/dev/null | jq .result)

SUITPS=$((($SUIEND-$SUISTART)/10))
MYTPS=$((($NODEEND-$NODESTART)/10))

echo 'SUI TPS: '$SUITPS
echo 'NODE TPS: '$MYTPS
echo '-------------------------------------'

echo 'Contacts If you have any errors: https://github.com/vup2p'