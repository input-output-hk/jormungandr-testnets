#! /bin/bash

set -ex

OUTPUT_ADDRESS=""
OUTPUT_VALUE=""
REST_URL="http://localhost:8080/api"
TEST_DIR=""
ADDRTYPE="--testing"
FEE_CONSTANT=10
FEE_CERTIFICATE=0
FEE_COEFFICIENT=0

usage() {
  cat << EOF
usage: $0 -a <OUTPUT-ADDRESS> -v <OUTPUT-VALUE>

  -a <OUTPUT-ADDRESS>    The address to send initial funds to
  -v <OUTPUT-VALUE>      The value to send
  -u <NODE-URL>          The node URL to send the transation
  -p <TEST-DIR>          Where the secrets and the block0 are in
EOF
}

while getopts 'a:v:u:p:h' c
do
  case $c in
    a) OUTPUT_ADDRESS="${OPTARG}" ;;
    v) OUTPUT_VALUE="${OPTARG}" ;;
    u) REST_URL="${OPTARG}" ;;
    p) TEST_DIR="${OPTARG}" ;;
    h)
        usage
        exit 0
        ;;
    *)
        usage
        exit 1
        ;;
  esac
done

if [ "${OUTPUT_ADDRESS}x" = "x" ]; then
  echo "missing \`-a' option for the address to send funds to"
  exit 1
fi

if [ "${OUTPUT_VALUE}x" = "x" ]; then
  echo "missing \`-v' option for the value to send"
  exit 1
fi

if [ "${TEST_DIR}x" = "x" ]; then
  echo "missing \`-p' option for the path to the deployment data"
  exit 1
fi

CLI=${TEST_DIR}/jcli

STAGING_FILE="${TEST_DIR}/staging.$$.transaction"

FAUCET_SK=$(cat ${TEST_DIR}/faucet_key.sk | tr -d '\n')
FAUCET_PK=$(echo ${FAUCET_SK} | ${CLI} key to-public)
FAUCET_ADDR=$($CLI address account ${ADDRTYPE} ${FAUCET_PK})

# TODO we should do this in one call to increase the atomicity, but otherwise
FAUCET_COUNTER=$( $CLI rest v0 account get "${FAUCET_ADDR}" -h "${REST_URL}" | grep '^counter:' | sed -e 's/counter: //' )

# the faucet account is going to pay for the fee ... so calculate how much
ACCOUNT_AMOUNT=$((${OUTPUT_VALUE} + ${FEE_CONSTANT}))

BLOCK0_HASH=$($CLI genesis hash --input ${TEST_DIR}/block-0.bin)

# Create the transaction
# FROM: FAUCET for AMOUNT+FEES
# TO: OUTPUT ADDRESS for AMOUNT
$CLI transaction new --staging ${STAGING_FILE}
$CLI transaction add-account "${FAUCET_ADDR}" "${ACCOUNT_AMOUNT}" --staging "${STAGING_FILE}"
$CLI transaction add-output "${OUTPUT_ADDRESS}" "${OUTPUT_VALUE}" --staging "${STAGING_FILE}"
$CLI transaction finalize --staging ${STAGING_FILE}

TRANSACTION_ID=$($CLI transaction id --staging ${STAGING_FILE})

# Create the witness for the 1 input (add-account) and add it
WITNESS_SECRET_FILE="${TEST_DIR}/witness.secret.$$"
WITNESS_OUTPUT_FILE="${TEST_DIR}/witness.out.$$"

echo "${FAUCET_SK}" > ${WITNESS_SECRET_FILE}

$CLI transaction make-witness ${TRANSACTION_ID} \
    --genesis-block-hash ${BLOCK0_HASH} \
    --type "account" --account-spending-counter "${FAUCET_COUNTER}" \
    ${WITNESS_OUTPUT_FILE} ${WITNESS_SECRET_FILE}
$CLI transaction add-witness ${WITNESS_OUTPUT_FILE} --staging "${STAGING_FILE}"

rm ${WITNESS_SECRET_FILE} ${WITNESS_OUTPUT_FILE}

# Finalize the transaction and send it
$CLI transaction seal --staging "${STAGING_FILE}"
$CLI transaction to-message --staging "${STAGING_FILE}" | $CLI rest v0 message post -h "${REST_URL}"

rm ${STAGING_FILE}
