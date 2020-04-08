#!/bin/bash

source environment-assertions.sh

if [[ ! ("$#" == 4) ]]; then
    echo "Usage: $0 /path/to/fatd TOKEN_ID TOKEN_SYMBOL SUPPLY"
    exit 1
fi

PATH_FATD_ROOT=$1
PATH_FAT_CLI=$PATH_FATD_ROOT/fat-cli
FACTOM_CLI="factom-cli"

assertFilePresent $PATH_FAT_CLI "FAT cli"
assertCommandAvailable $FACTOM_CLI

SUPPLY=$4
TOKEN_ID=$2
TOKEN_SYMBOL=$3

TMP_DIRECTORY=$(mktemp -d)

SERVER_IDENTITY_FOLDER="./serveridentity"
mkdir $SERVER_IDENTITY_FOLDER -p

echo "-------------------Loading EC addresses-------------------"
ESADR_FILE=./entry_credit_address.sh
if test -f "$ESADR_FILE"; then
    source ${ESADR_FILE}
else
    echo "Please run start-factomd-factomwalletd-fatd.sh before this script"
    exit 1
fi

echo "------------------Factoid addresses------------------"
# Create two Factoid addresses to which we'll transfer FAT-0 tokens.
fctaddress1=$($FACTOM_CLI newfctaddress)
skfctaddress1=$($FACTOM_CLI exportaddresses | grep $fctaddress1 | awk '{print $1}')
fctaddress2=$($FACTOM_CLI newfctaddress)
skfctaddress2=$($FACTOM_CLI exportaddresses | grep $fctaddress2 | awk '{print $1}')
echo "Newly created factoid address 1: "$fctaddress1
echo "                             sk: "$skfctaddress1
echo "Newly created factoid address 2: "$fctaddress2
echo "                             sk: "$skfctaddress2

echo "------------------Addresses and their balances------------------"
$FACTOM_CLI listaddresses
echo " "

createServerIdentity=false
if ! test -f $SERVER_IDENTITY_FOLDER"/serveridentityoutput.txt"; then
    createServerIdentity=true
fi

if [ "$createServerIdentity" == true ]; then
    echo "------------------Creating server identity------------------"
    ./create-server-identity.sh $SERVER_IDENTITY_FOLDER $pkecaddress
    echo " "
fi

echo "Next step: Register identity on Factom"
read -p "Press enter to continue"
echo "------------------Register identity on Factom------------------"
echo "Executing addchain line from 'fullidentity.sh'..."
identityCommand=$(grep -i "Identity Chain" $SERVER_IDENTITY_FOLDER"/fullidentity.sh")
identityOutput=$(eval $identityCommand)
identityChainId=$(echo $identityOutput | perl -nle'print $& while m{(?<=ChainID: ).*(?= Entryhash:)}g')
echo "Identity chain ID: "$identityChainId

if [ "$createServerIdentity" == true ]; then
    echo "Executing addentry line from 'fullidentity.sh'..."
    identityRegisterCommand=$(grep -i "Register Factom Identity" $SERVER_IDENTITY_FOLDER"/fullidentity.sh")

    # Replace the fixed example identity chain ID that is output in the script with our newly created chain ID.
    replaceCommand=${identityRegisterCommand/888888001750ede0eff4b05f0c3f557890b256450cabbb84cada937f9c258327/$identityChainId}
    createEntryOutput=$(eval $replaceCommand)

    echo "Waiting on registration"
    # Wait for a long while to be sure that the identity was registered and we can use it to issue tokens.
    t=1
    while [[ $t -le 30 ]]; do #660
       if [[ $((t%3)) -eq 0 ]]; then echo -ne ".  \r"; fi
       if [[ $((t%3)) -eq 1 ]]; then echo -ne ".. \r"; fi
       if [[ $((t%3)) -eq 2 ]]; then echo -ne "...\r"; fi
       ((t++))
       sleep 1
    done
    echo " "
fi

level1SkLine=$(grep 'Level 1:' $SERVER_IDENTITY_FOLDER"/serveridentityoutput.txt")
sk1value=$(echo $level1SkLine | cut -d " " -f3)
echo "Level 1 sk1 value: "$sk1value

level2SkLine=$(grep 'Root Chain:' $SERVER_IDENTITY_FOLDER"/serveridentityoutput.txt")
identity=$(echo "$level2SkLine" | cut -d ":" -f2)
echo "Root chain ID for identity: "$identity

echo "------------------Create token chain------------------"
createTokenTrxResult=$($PATH_FAT_CLI issue --identity $identity --tokenid $TOKEN_ID --ecadr $pkecaddress --sk1 $sk1value --symbol $TOKEN_SYMBOL --type "FAT-0" --supply $SUPPLY)
echo " "
tokenChainId=$(echo $createTokenTrxResult | perl -nle'print $& while m{(?<=Chain ID: ).*?(?=\sEntry Hash:)}g')
echo "Token creation chain ID: "$tokenChainId
issueFirstTrxId=$(echo $createTokenTrxResult | perl -nle'print $& while m{(?<=Tx ID: ).*?(?=\sToken Initialization)}g')
echo "Token creation Tx ID: "$issueFirstTrxId
issueTrxId=$(echo $createTokenTrxResult | perl -nle'print $& while m{(?<=Token Initialization Entry Submitted Entry Hash:\s.{64}\sFactom Tx ID:\s).{64}}g')
echo "Token Initialization Tx ID: "$issueTrxId

echo "Waiting on confirmation"
t=0
while [[ ! "$($FACTOM_CLI status $issueFirstTrxId)" =~ .*"DBlockConfirmed"*. ]]; do
  if [[ $((t%3)) -eq 0 ]]; then echo -ne ".  \r"; fi
  if [[ $((t%3)) -eq 1 ]]; then echo -ne ".. \r"; fi
  if [[ $((t%3)) -eq 2 ]]; then echo -ne "...\r"; fi
  ((t++))
  sleep 1
done

$FACTOM_CLI status $issueFirstTrxId

t=0
while [[ ! "$($FACTOM_CLI status $issueTrxId)" =~ .*"DBlockConfirmed"*. ]]; do
   if [[ $((t%3)) -eq 0 ]]; then echo -ne ".  \r"; fi
   if [[ $((t%3)) -eq 1 ]]; then echo -ne ".. \r"; fi
   if [[ $((t%3)) -eq 2 ]]; then echo -ne "...\r"; fi
   ((t++))
   sleep 1
done

$FACTOM_CLI status $issueTrxId
echo " "

echo "Waiting for FATD to catch up"
t=1
    while [[ $t -le 20 ]]; do
       if [[ $((t%3)) -eq 0 ]]; then echo -ne ".  \r"; fi
       if [[ $((t%3)) -eq 1 ]]; then echo -ne ".. \r"; fi
       if [[ $((t%3)) -eq 2 ]]; then echo -ne "...\r"; fi
       ((t++))
       sleep 1
    done
    echo " "

echo "Next step: Perform token transaction"
read -p "Press enter to continue"
echo "------------------FAT0 token transaction------------------"
# For verification purposes, make a token transaction to the two Factoid addresses we created earlier.
tokenTransactionResult=$($PATH_FAT_CLI transact fat0 --identity $identity --tokenid $TOKEN_ID --ecadr $pkecaddress --sk1 $sk1value --output $fctaddress2:15 --output $fctaddress1:10)
echo $tokenTransactionResult
tokenTransactionId=$(echo $tokenTransactionResult | perl -nle'print $& while m{(?<=Tx ID:\s).*}g')
echo "Transaction ID: "$tokenTransactionId

t=0
while [[ ! "$($FACTOM_CLI status $tokenTransactionId)" =~ .*"DBlockConfirmed"*. ]]; do
   if [[ $((t%3)) -eq 0 ]]; then echo -ne ".  \r"; fi
   if [[ $((t%3)) -eq 1 ]]; then echo -ne ".. \r"; fi
   if [[ $((t%3)) -eq 2 ]]; then echo -ne "...\r"; fi
   ((t++))
   sleep 1
done

$FACTOM_CLI status $tokenTransactionId

echo "Waiting an additional 10 seconds to let FATD catch up with the now confirmed transactions"
t=1
while [[ $t -le 10 ]]; do
  if [[ $((t%3)) -eq 0 ]]; then echo -ne ".  \r"; fi
  if [[ $((t%3)) -eq 1 ]]; then echo -ne ".. \r"; fi
  if [[ $((t%3)) -eq 2 ]]; then echo -ne "...\r"; fi
  ((t++))
  sleep 1
  done
echo " "

echo "------------------Query balances------------------"

echo "Balance on FA address 1: "
$PATH_FAT_CLI get balance --identity $identity --tokenid $TOKEN_ID $fctaddress1

echo "Balance on FA address 2: "
$PATH_FAT_CLI get balance --identity $identity --tokenid $TOKEN_ID $fctaddress2

echo ""
echo "------------------Token created!------------------"
echo ""
echo "Token ID: "$TOKEN_ID
echo "Token Symbol: "$TOKEN_SYMBOL
echo "Token Chain ID: "$tokenChainId
echo "Issuer Root Chain ID: "$identityChainId
echo "Identity sk1: "$sk1value

### Create JSON for created token
COINFILE=${TOKEN_ID}".json"
echo -e "{" >> ${COINFILE}
echo -e "    \"tokenId\": \"$TOKEN_ID\"," >> ${COINFILE}
echo -e "    \"tokenChainId\": \"$tokenChainId\"," >> ${COINFILE}
echo -e "    \"issuerRootChainId\": \"$identityChainId\"," >> ${COINFILE}
echo -e "    \"coinbaseAddressPublic\": \"FA1zT4aFpEvcnPqPCigB3fvGu4Q4mTXY22iiuV69DqE1pNhdF2MC\"," >> ${COINFILE}
echo -e "    \"identityLevel1SecretAddress\": \"$sk1value\"" >> ${COINFILE}
echo -e "}" >> ${COINFILE}
