#!/bin/bash
set -e

source "$(dirname "$0")/script-utils.sh"

suffix=$(head /dev/urandom | tr -dc a-z0-9 | head -c4)

multisig_1="multisig_1_${suffix}"
multisig_2="multisig_2_${suffix}"

kli init --name "$multisig_1" --nopasscode
kli init --name "$multisig_2" --nopasscode

multisig_witness_aid="BBilc4-L3tFUnfM_wJr4S4OJanAv_VmF_dJNN6vkf2Ha"
multisig_witness_url="http://127.0.0.1:5642/oobi/$multisig_witness_aid/controller"
schema_oobi_url="https://weboftrust.github.io/oobi/EBfdlu8R27Fbx-ehrqwImnK-8Cm79sqbAQ4MmvEAYqao"

kli oobi resolve --name "$multisig_1" --oobi "$schema_oobi_url"
kli oobi resolve --name "$multisig_2" --oobi "$schema_oobi_url"
kli oobi resolve --name "$multisig_1" --oobi "$multisig_witness_url"
kli oobi resolve --name "$multisig_2" --oobi "$multisig_witness_url"

kli incept --name "$multisig_1" --alias member --icount 1 --ncount 1 --isith 1 --nsith 1 --transferable --toad 1 --wit "$multisig_witness_aid"
kli incept --name "$multisig_2" --alias member --icount 1 --ncount 1 --isith 1 --nsith 1 --transferable --toad 1 --wit "$multisig_witness_aid"
kli ends add --name "$multisig_1" --alias member --eid "$multisig_witness_aid" --role mailbox
kli ends add --name "$multisig_2" --alias member --eid "$multisig_witness_aid" --role mailbox

multisig_1_oobi=$(kli oobi generate --name "$multisig_1" --alias member --role witness | tail -n 1)
multisig_2_oobi=$(kli oobi generate --name "$multisig_2" --alias member --role witness | tail -n 1)
multisig_1_aid=$(kli aid --name "$multisig_1" --alias member)
multisig_2_aid=$(kli aid --name "$multisig_2" --alias member)

kli oobi resolve --name "$multisig_1" --oobi-alias multisig_2 --oobi "${multisig_2_oobi}"
kli oobi resolve --name "$multisig_2" --oobi-alias multisig_1 --oobi "${multisig_1_oobi}"

multisig_json=$(mktemp)
cat << EOF > "$multisig_json"
{
    "transferable": true,
    "toad": 1,
    "wits": ["$multisig_witness_aid"],
    "aids": ["$multisig_1_aid", "$multisig_2_aid"],
    "isith": "1",
    "nsith": "1"
}
EOF

kli multisig incept --name "$multisig_1" --alias member --group multisig --file "$multisig_json"

kli multisig join --name "$multisig_2" --group multisig --auto

multisig_aid=$(kli aid --name "$multisig_1" --alias multisig)
multisig_2_aid=$(kli aid --name "$multisig_2" --alias multisig)

echo "multisig_aid: $multisig_aid"
echo "multisig_2_aid: $multisig_2_aid"

nonce=$(kli nonce)
kli vc registry incept --name "$multisig_1" --alias multisig --nonce "$nonce" --usage "Issue vLEIs"

timestamp=$(kli time)
kli vc create \
    --name "$multisig_1" \
    --alias multisig \
    --registry-name multisig \
    --schema EBfdlu8R27Fbx-ehrqwImnK-8Cm79sqbAQ4MmvEAYqao \
    --recipient "$multisig_aid" \
    --data "{\"LEI\": \"5493001KJTIIGC8Y1R17\"}" \
    --time "${timestamp}"

kli multisig export --name "$multisig_1" --alias multisig | kli multisig import --name "$multisig_2" --alias multisig --auto

# Verify that there are two credentials in the vc list --said
said_count=$(kli vc list --name "$multisig_2" --alias multisig --said | wc -l)
if [ "$said_count" -ne 2 ]; then
    echo "Expected 2 credentials, got $said_count"
    exit 1
fi
