#! /bin/sh

VERSION=''
DEPLOY_NUMBER=''
ADDRTYPE="--testing"
FEE_CONSTANT=10
FEE_CERTIFICATE=0
FEE_COEFFICIENT=0
FAUCET_AMOUNT=50000000000

#########################
# Handy Tooling         #
#########################

# Reset
Color_Off='\033[0m'       # Text Reset

# Regular Colors
Black='\033[0;30m'        # Black
Red='\033[0;31m'          # Red
Green='\033[0;32m'        # Green
Yellow='\033[0;33m'       # Yellow
Blue='\033[0;34m'         # Blue
Purple='\033[0;35m'       # Purple
Cyan='\033[0;36m'         # Cyan
White='\033[0;37m'        # White

# Bold
BBlack='\033[1;30m'       # Black
BRed='\033[1;31m'         # Red
BGreen='\033[1;32m'       # Green
BYellow='\033[1;33m'      # Yellow
BBlue='\033[1;34m'        # Blue
BPurple='\033[1;35m'      # Purple
BCyan='\033[1;36m'        # Cyan
BWhite='\033[1;37m'       # White

# High Intensity
IBlack='\033[0;90m'       # Black
IRed='\033[0;91m'         # Red
IGreen='\033[0;92m'       # Green
IYellow='\033[0;93m'      # Yellow
IBlue='\033[0;94m'        # Blue
IPurple='\033[0;95m'      # Purple
ICyan='\033[0;96m'        # Cyan
IWhite='\033[0;97m'       # White

# Bold High Intensity
BIBlack='\033[1;90m'      # Black
BIRed='\033[1;91m'        # Red
BIGreen='\033[1;92m'      # Green
BIYellow='\033[1;93m'     # Yellow
BIBlue='\033[1;94m'       # Blue
BIPurple='\033[1;95m'     # Purple
BICyan='\033[1;96m'       # Cyan
BIWhite='\033[1;97m'      # White

error() {
  echo "${IRed}${*}${Color_Off}"
}

usage() {
  cat << EOF
usage: $0 -v <NODE-VERSION> -n <DEPLOYMENT-NUMBER>

  -v <NODE-VERSION>    The node version to run
  -n <DEPLOY-NUMBER>   The deployment number
EOF
}

while getopts 'v:n:h' c
do
  case $c in
    v) VERSION="${OPTARG}" ;;
    n) DEPLOY_NUMBER="${OPTARG}" ;;
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

if [ "${VERSION}x" = "x" ]; then
  error "missing \`-v' option for the version to deploy"
  exit 1
fi

if [ "${DEPLOY_NUMBER}x" = "x" ]; then
  error "missing \`-n' option for the testnet number to deploy under version \`${VERSION}'"
  exit 1
fi

WGET=$(which wget)
if [ ${?} -ne 0 ]; then
  error "cannot find \`wget'"
  exit 1
fi


cat << EOF
        ---_ ......._-_--.
       (|\ /      / /| \  \               _  ___  ____  __  __ _   _ _   _  ____    _    _   _ ____  ____
       /  /     .'  -=-'   '.            | |/ _ \|  _ \|  \/  | | | | \ | |/ ___|  / \  | \ | |  _ \|  _ \\
      /  /    .'             )        _  | | | | | |_) | |\/| | | | |  \| | |  _  / _ \ |  \| | | | | |_) |
    _/  /   .'        _.)   /        | |_| | |_| |  _ <| |  | | |_| | |\  | |_| |/ ___ \| |\  | |_| |  _ <
   /   o  o       _.-' /  .'          \___/ \___/|_| \_\_|  |_|\___/|_| \_|\____/_/   \_\_| \_|____/|_| \_\\
   \          _.-'    / .'#|
    \______.-'//    .'.' \#|         Deploying new testnet
     \|  \ | //   .'.' _ |#|
      '   \|//  .'.'_._._|#|
       .  .// .'.' | _._ \#|
       \'-|\_/ /    \ _._ \#\\
        '/'\__/      \ _._ \#\\
       /^|            \ _-_ \#
      '  '             \ _-_ \\
                        \_

 🐍version:    ${VERSION}
   deployment: ${DEPLOY_NUMBER}
EOF

WORKING_DIRECTORY="${PWD}/${VERSION}/${DEPLOY_NUMBER}"

###############################################################################
#       PREPARE WORKING ENVIRONMENT                                           #
###############################################################################

if [ -d ${WORKING_DIRECTORY} ]; then
  error "deployment ${DEPLOY_NUMBER} already exist for ephemeral testnet ${VERSION}"
  exit 1
else
  mkdir -p ${WORKING_DIRECTORY}
fi

pushd ${WORKING_DIRECTORY}

###############################################################################
#       INSTALL APPROPRIATE VERSION OF JCLI                                   #
###############################################################################

TRIPPLE=''
ARCH=x86_64
case $(uname | tr -d '\n') in
  "Darwin") TRIPPLE="${ARCH}-apple-darwin";;
  "Linux") TRIPPLE="${ARCH}-unknown-linux-musl";;
  *)
    error "unsupported system? $(uname)"
    exit 1
esac

INSTALLER="jormungandr-${VERSION}-${TRIPPLE}.tar.gz"

${WGET} https://github.com/input-output-hk/jormungandr/releases/download/${VERSION}/${INSTALLER}
if [ ${?} -ne 0 ]; then
  error "cannot download jormungandr's installer \`${INSTALLER}'"
  exit 1
fi

tar xf ${INSTALLER}
rm ${INSTALLER}

CLI=${WORKING_DIRECTORY}/jcli
JORMUNGANDR=${WORKING_DIRECTORY}/jormungandr

###############################################################################
#      SETUP INITIAL STAKE POOL AND FAUCETS                                   #
###############################################################################

TMPDIR=${PWD}/tmp
mkdir -p ${TMPDIR}

FAUCET_SK=$($CLI key generate --type=Ed25519)
FAUCET_PK=$(echo ${FAUCET_SK} | $CLI key to-public)
FAUCET_ADDR=$($CLI address account ${ADDRTYPE} ${FAUCET_PK})

LEADER_SK=$($CLI key generate --type=Ed25519)
LEADER_PK=$(echo ${LEADER_SK} | $CLI key to-public)

# stake pool
POOL_VRF_SK=$($CLI key generate --type=Curve25519_2HashDH)
POOL_KES_SK=$($CLI key generate --type=SumEd25519_12)

POOL_VRF_PK=$(echo ${POOL_VRF_SK} | $CLI key to-public)
POOL_KES_PK=$(echo ${POOL_KES_SK} | $CLI key to-public)

# note we use the faucet as the owner to this pool
STAKE_KEY=${FAUCET_SK}
STAKE_KEY_PUB=${FAUCET_PK}

echo ${STAKE_KEY} > ${TMPDIR}/stake_key.sk
echo ${LEADER_SK} > ${TMPDIR}/leader_key.sk
echo ${POOL_VRF_SK} > ${TMPDIR}/stake_pool.vrf.sk
echo ${POOL_KES_SK} > ${TMPDIR}/stake_pool.kes.sk

$CLI certificate new stake-pool-registration \
    --management-threshold 1 \
    --start-validity 0 \
    --owner ${LEADER_PK} \
    --kes-key ${POOL_KES_PK} \
    --vrf-key ${POOL_VRF_PK} \
    --serial 1010101010 > ${TMPDIR}/stake_pool.cert

cat ${TMPDIR}/stake_pool.cert | $CLI certificate sign ${TMPDIR}/stake_key.sk > ${TMPDIR}/stake_pool.signcert

STAKE_POOL_ID=$(cat ${TMPDIR}/stake_pool.signcert | $CLI certificate get-stake-pool-id)
STAKE_POOL_CERT=$(cat ${TMPDIR}/stake_pool.signcert)

$CLI certificate new stake-delegation \
    ${STAKE_POOL_ID} \
    ${FAUCET_PK} > ${TMPDIR}/stake_delegation1.cert
cat ${TMPDIR}/stake_delegation1.cert | $CLI certificate sign ${TMPDIR}/stake_key.sk > ${TMPDIR}/stake_delegation1.signcert
STAKE_DELEGATION_CERT1=$(cat ${TMPDIR}/stake_delegation1.signcert)

echo "${FAUCET_SK}" > ${WORKING_DIRECTORY}/faucet_key.sk

cat << EOF > ${WORKING_DIRECTORY}/pool-secret.yaml
genesis:
  sig_key: ${POOL_KES_SK}
  vrf_key: ${POOL_VRF_SK}
  node_id: ${STAKE_POOL_ID}
bft:
  signing_key: ${LEADER_SK}
EOF

###############################################################################
#      PREPARE AND ALLOW USER TO UPDATE GENESIS.YAML                          #
###############################################################################

cat << EOF > ${WORKING_DIRECTORY}/genesis.yaml
# This is the default generated blockchain genesis
# update the 'blockchain_configuration' to try new settings

blockchain_configuration:
  block0_date: $(date +%s)
  discrimination: test
  slots_per_epoch: 4320
  slot_duration: 20s
  consensus_genesis_praos_active_slot_coeff: 0.1
  consensus_leader_ids:
    - ${LEADER_PK}
  linear_fees:
    constant: ${FEE_CONSTANT}
    coefficient: ${FEE_COEFFICIENT}
    certificate: ${FEE_CERTIFICATE}
  block0_consensus: genesis_praos
  kes_update_speed: 12h
initial:
  - fund:
      - address: ${FAUCET_ADDR}
        value: ${FAUCET_AMOUNT}
  - cert: ${STAKE_POOL_CERT}
  - cert: ${STAKE_DELEGATION_CERT1}
EOF

${EDITOR} genesis.yaml

$CLI genesis encode --input ${WORKING_DIRECTORY}/genesis.yaml --output ${WORKING_DIRECTORY}/block-0.bin
if [ $? -ne 0 ]; then
    error "error: building the genesis block"
    exit 1
fi

BLOCK0_HASH=$($CLI genesis hash --input ${WORKING_DIRECTORY}/block-0.bin)

rm -r ${TMPDIR}

cat << EOF > README.md
# Nightly testnet

This Nightly Testnet was triggered to test ${VERSION} and is deployment ${DEPLOYMENT_NUMBER}.

## How to connect to this ephemeral testnet

1. download [${VERSION}](https://github.com/input-output-hk/jormungandr/releases/${VERSION}) or later;
2. prepare your [node configuration file](https://input-output-hk.github.io/jormungandr/quickstart/02_passive_node.html#the-node-configuration)
   (it is possible there have been changes in the documentation since this release);
3. start jormungandr with the node's configuration file and the appropriate \`genesis-block-hash\`

### Genesis Block Hash

This is the hash that you need to use when signing transactions or to start the node

\`${BLOCK0_HASH}\`

### start suggestion

\`\`\`js
jormungandr \\
    --genesis-block-hash ${BLOCK0_HASH} \\
    --trusted-peer <ADD TRUSTED PEER ADDRESS HERE>
\`\`\`

### Example configuration file

If you want to add REST API monitoring, use:

\`\`\`yaml
rest:
  listen: "127.0.0.1:8080"
\`\`\`

# Info

Jormungandr ${VERSION}

* full version: \`$(${JORMUNGANDR} --full-version)\`
* md5: \`$(md5 -q ${JORMUNGANDR})\`

jcli ${VERSION}

* full version: \`$(${CLI} --full-version)\`
* md5: \`$(md5 -q ${CLI})\`

EOF

git add README.md
git add block-0.bin
git add genesis.yaml

popd
