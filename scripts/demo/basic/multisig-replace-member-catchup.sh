#!/bin/bash
set -e

# Combines multisig-replace-member and multisig-catchup:
# - 2-of-3 group (member_1, member_2, member_3) creates registry and issues one credential
# - Rotate member_1 out, member_4 in
# - Member_4 catchup via export/import; assert member_4 has registry and credential

source "$(dirname "$0")/script-utils.sh"

suffix=$(head /dev/urandom | tr -dc a-z0-9 | head -c4)
delegator="delegator_${suffix}"
holder="holder_${suffix}"
member_1="member_1_${suffix}"
member_2="member_2_${suffix}"
member_3="member_3_${suffix}"
member_4="member_4_${suffix}"

group_witness_aid="BBilc4-L3tFUnfM_wJr4S4OJanAv_VmF_dJNN6vkf2Ha"
group_witness_url="http://127.0.0.1:5642/oobi/$group_witness_aid/controller"
delegator_witness_aid="BLskRTInXnMxWaGqcpSyMgo0nYbalW99cGZESrz3zapM"
delegator_witness_url="http://127.0.0.1:5643/oobi/$delegator_witness_aid/controller"
schema_said_qvi="EBfdlu8R27Fbx-ehrqwImnK-8Cm79sqbAQ4MmvEAYqao"
schema_said_le="ENPXp1vQzRF6JwIuS-mp2U8Uf1MoADoP_GqQ62VsDZWY"

config_dir="$(mktemp -d)/keri"
mkdir -p "$config_dir/keri/cf"

group_config_json="$config_dir/keri/cf/group_config.json"
delegator_config_json="$config_dir/keri/cf/delegator_config.json"

cat << EOF > "$group_config_json"
{
    "dt": "2026-03-10T00:00:00.000000+00:00",
    "iurls": [
        "$group_witness_url"
    ],
    "durls": [
        "http://weboftrust.github.io/oobi/$schema_said_qvi",
        "http://weboftrust.github.io/oobi/$schema_said_le"
    ]
}
EOF

# # TODO:
# # Investigate why delegator need to resolve delegate witness OOBI. 
# # We get an error at delegate confirm step when we don't resolve it.
cat << EOF > "$delegator_config_json"
{
    "dt": "2026-03-10T00:00:00.000000+00:00",
    "iurls": [
        "$delegator_witness_url",
        "$group_witness_url"
    ],
    "durls": [
        "http://weboftrust.github.io/oobi/$schema_said_qvi",
        "http://weboftrust.github.io/oobi/$schema_said_le"
    ]
}
EOF

exit_hook() {
    echo kli status --name "$member_1" --alias group
    echo kli status --name "$member_2" --alias group
    echo kli status --name "$member_3" --alias group
    echo kli status --name "$member_4" --alias group
}
trap exit_hook EXIT

if ! curl -s "$group_witness_url" > /dev/null; then
    echo "Witness URL is not reachable, remember to run: kli witness demo"
    exit 1
fi

kli init --name "$member_1" --config-dir "$config_dir" --config-file group_config --nopasscode
kli init --name "$member_2" --config-dir "$config_dir" --config-file group_config --nopasscode
kli init --name "$member_3" --config-dir "$config_dir" --config-file group_config --nopasscode
kli init --name "$member_4" --config-dir "$config_dir" --config-file group_config --nopasscode
kli init --name "$delegator" --config-dir "$config_dir" --config-file delegator_config --nopasscode
kli init --name "$holder" --config-dir "$config_dir" --config-file group_config --nopasscode

kli incept --name "$delegator" --alias delegator --icount 1 --ncount 1 --isith 1 --nsith 1 --transferable --toad 1 --wit "$delegator_witness_aid"
kli incept --name "$holder" --alias holder --icount 1 --ncount 1 --isith 1 --nsith 1 --transferable --toad 1 --wit "$group_witness_aid"
kli incept --name "$member_1" --alias member --icount 1 --ncount 1 --isith 1 --nsith 1 --transferable --toad 1 --wit "$group_witness_aid"
kli incept --name "$member_2" --alias member --icount 1 --ncount 1 --isith 1 --nsith 1 --transferable --toad 1 --wit "$group_witness_aid"
kli incept --name "$member_3" --alias member --icount 1 --ncount 1 --isith 1 --nsith 1 --transferable --toad 1 --wit "$group_witness_aid"
kli incept --name "$member_4" --alias member --icount 1 --ncount 1 --isith 1 --nsith 1 --transferable --toad 1 --wit "$group_witness_aid"
kli ends add --name "$holder" --alias holder --eid "$group_witness_aid" --role mailbox
kli ends add --name "$delegator" --alias delegator --eid "$delegator_witness_aid" --role mailbox
kli ends add --name "$member_1" --alias member --eid "$group_witness_aid" --role mailbox
kli ends add --name "$member_2" --alias member --eid "$group_witness_aid" --role mailbox
kli ends add --name "$member_3" --alias member --eid "$group_witness_aid" --role mailbox
kli ends add --name "$member_4" --alias member --eid "$group_witness_aid" --role mailbox

delegator_oobi=$(kli oobi generate --name "$delegator" --alias delegator --role witness | tail -n 1)
holder_oobi=$(kli oobi generate --name "$holder" --alias holder --role witness | tail -n 1)
member_1_oobi=$(kli oobi generate --name "$member_1" --alias member --role witness | tail -n 1)
member_2_oobi=$(kli oobi generate --name "$member_2" --alias member --role witness | tail -n 1)
member_3_oobi=$(kli oobi generate --name "$member_3" --alias member --role witness | tail -n 1)
member_4_oobi=$(kli oobi generate --name "$member_4" --alias member --role witness | tail -n 1)
delegator_aid=$(kli aid --name "$delegator" --alias delegator)
holder_aid=$(kli aid --name "$holder" --alias holder)
member_1_aid=$(kli aid --name "$member_1" --alias member)
member_2_aid=$(kli aid --name "$member_2" --alias member)
member_3_aid=$(kli aid --name "$member_3" --alias member)
member_4_aid=$(kli aid --name "$member_4" --alias member)

kli oobi resolve --name "$member_1" --oobi-alias member_2 --oobi "${member_2_oobi}"
kli oobi resolve --name "$member_1" --oobi-alias member_3 --oobi "${member_3_oobi}"
kli oobi resolve --name "$member_1" --oobi-alias member_4 --oobi "${member_4_oobi}"
kli oobi resolve --name "$member_1" --oobi-alias delegator --oobi "${delegator_oobi}"

kli oobi resolve --name "$member_2" --oobi-alias member_1 --oobi "${member_1_oobi}"
kli oobi resolve --name "$member_2" --oobi-alias member_3 --oobi "${member_3_oobi}"
kli oobi resolve --name "$member_2" --oobi-alias member_4 --oobi "${member_4_oobi}"
kli oobi resolve --name "$member_2" --oobi-alias delegator --oobi "${delegator_oobi}"

kli oobi resolve --name "$member_3" --oobi-alias member_1 --oobi "${member_1_oobi}"
kli oobi resolve --name "$member_3" --oobi-alias member_2 --oobi "${member_2_oobi}"
kli oobi resolve --name "$member_3" --oobi-alias member_4 --oobi "${member_4_oobi}"
kli oobi resolve --name "$member_3" --oobi-alias delegator --oobi "${delegator_oobi}"

group_json=$(mktemp)
cat << EOF > "$group_json"
{
    "transferable": true,
    "toad": 1,
    "wits": ["$group_witness_aid"],
    "aids": ["$member_1_aid", "$member_2_aid", "$member_3_aid"],
    "isith": "2",
    "nsith": "2",
    "delpre": "$delegator_aid"
}
EOF

kli multisig incept --name "$member_1" --alias member --group group --file "$group_json" &
PID_LIST="$!"
kli multisig incept --name "$member_2" --alias member --group group --file "$group_json" &
PID_LIST+=" $!"
kli delegate confirm --name "$delegator" --alias delegator -Y &
PID_LIST+=" $!"
wait $PID_LIST

kli multisig join --name "$member_3" --group group --auto

# Registry and credential before rotation (member_1 and member_2 sign for 2-of-3)
group_oobi=$(kli oobi generate --name "$member_1" --alias group --role witness | tail -n 1)
group_aid=$(kli aid --name "$member_1" --alias group)
nonce=$(kli nonce)
timestamp=$(kli time)

kli vc registry incept --name "$member_1" --alias group --registry-name group --nonce "$nonce" --usage "Issue vLEIs" &
PID_LIST="$!"
kli vc registry incept --name "$member_2" --alias group --registry-name group --nonce "$nonce" --usage "Issue vLEIs" &
PID_LIST+=" $!"
wait $PID_LIST

kli vc registry incept \
    --name "$delegator" \
    --alias delegator \
    --registry-name delegator \
    --usage "Issue vLEIs"

kli vc create \
    --name "$delegator" \
    --alias delegator \
    --registry-name delegator \
    --schema "$schema_said_qvi" \
    --recipient "$group_aid" \
    --data "{\"LEI\": \"5493001KJTIIGC8Y1R17\"}"

qvi_said=$(kli vc list --name "$delegator" --alias delegator --issued --said)

kli ipex grant --name "$delegator" --alias delegator --said "$qvi_said" --recipient "$group_aid"

# Poll until both members see the same grant (mailbox delivery can be async)
grant_said_1=""
grant_said_2=""
for _ in 1 2 3 4 5 6 7 8 9 10; do
  grant_said_1=$(kli ipex list --name "$member_1" --alias group --poll --said | tail -n 1)
  grant_said_2=$(kli ipex list --name "$member_2" --alias group --poll --said | tail -n 1)
  if [[ -n "$grant_said_1" && -n "$grant_said_2" && "$grant_said_1" == "$grant_said_2" ]]; then
    break
  fi
  sleep 1
done
if [[ "$grant_said_1" != "$grant_said_2" ]]; then
    echo "Grant saids are not the same (after retries)"
    echo "grant_said_1: $grant_said_1"
    echo "grant_said_2: $grant_said_2"
    exit 1
fi

timestamp=$(kli time)
kli ipex admit --name "$member_1" --alias group --said "$grant_said_1" --time "${timestamp}" &
PID_LIST="$!"
kli ipex admit --name "$member_2" --alias group --said "$grant_said_2" --time "${timestamp}" &
PID_LIST+=" $!"
wait $PID_LIST

kli vc list --name "$member_1" --alias group

echo "-----------------------------------------"
echo "-----Finished issuing QVI credential-----"
echo "-----------------------------------------"

kli oobi resolve --name "$holder" --oobi-alias issuer --oobi "$group_oobi"
kli oobi resolve --name "$member_1" --oobi-alias holder --oobi "$holder_oobi"
kli oobi resolve --name "$member_2" --oobi-alias holder --oobi "$holder_oobi"

edges_json=$(mktemp)
cat << EOF > "$edges_json"
{
    "d": "",
    "qvi": {
        "n": "$qvi_said",
        "s": "$schema_said_qvi"
    }
}
EOF

rules_json=$(mktemp)
cat << EOF > "$rules_json"
{
    "d": "",
    "usageDisclaimer": {
        "l": "Usage of a valid, unexpired, and non-revoked vLEI Credential, as defined in the associated Ecosystem Governance Framework, does not assert that the Legal Entity is trustworthy, honest, reputable in its business dealings, safe to do business with, or compliant with any laws or that an implied or expressly intended purpose will be fulfilled."
    },
    "issuanceDisclaimer": {
        "l": "All information in a valid, unexpired, and non-revoked vLEI Credential, as defined in the associated Ecosystem Governance Framework, is accurate as of the date the validation process was complete. The vLEI Credential has been issued to the legal entity or person named in the vLEI Credential as the subject; and the qualified vLEI Issuer exercised reasonable care to perform the validation process set forth in the vLEI Ecosystem Governance Framework."
    }
}
EOF

kli saidify --file "$edges_json"
kli saidify --file "$rules_json"

kli vc create \
    --name "$member_1" \
    --alias group \
    --registry-name group \
    --schema "$schema_said_le" \
    --recipient "$holder_aid" \
    --data "{\"LEI\": \"5493001KJTIIGC8Y1R17\"}" \
    --edges @$edges_json \
    --rules @$rules_json \
    --time "${timestamp}" &
PID_LIST="$!"
kli vc create \
    --name "$member_2" \
    --alias group \
    --registry-name group \
    --schema "$schema_said_le" \
    --recipient "$holder_aid" \
    --data "{\"LEI\": \"5493001KJTIIGC8Y1R17\"}" \
    --edges @$edges_json \
    --rules @$rules_json \
    --time "${timestamp}" &
PID_LIST+=" $!"
wait $PID_LIST

le_said_1=$(kli vc list --name "$member_1" --alias group --said --issued)
le_said_2=$(kli vc list --name "$member_2" --alias group --said --issued)
if [[ "$le_said_1" != "$le_said_2" ]]; then
    echo "LE saids are not the same"
    echo "le_said_1: $le_said_1"
    echo "le_said_2: $le_said_2"
    exit 1
fi

timestamp=$(kli time)
kli ipex grant --name "$member_1" --alias group --said "$le_said_1" --recipient "$holder_aid" --time "${timestamp}" &
PID_LIST="$!"
kli ipex grant --name "$member_2" --alias group --said "$le_said_2" --recipient "$holder_aid" --time "${timestamp}" &
PID_LIST+=" $!"
wait $PID_LIST

grant_said_holder=$(kli ipex list --name "$holder" --alias holder --poll --said | tail -n 1)
kli ipex admit --name "$holder" --alias holder --said "$grant_said_holder"
kli vc list --name "$holder" --alias holder

echo "-----------------------------------------"
echo "-----Finished issuing LE credential-----"
echo "-----------------------------------------"

# Ensure all group members have updated state before rotation
kli local watch --name "$member_1"
kli local watch --name "$member_2"
kli multisig export --name "$member_2" --alias group | kli multisig import --name "$member_3" --alias group --auto
kli local watch --name "$member_3"
# kli multisig join --name "$member_3" --group group --auto
# kli multisig update --name "$member_3" --alias group --wit "$group_witness_aid" --sn 2

# Rotation: member_1 out, member_4 in

kli rotate --name "$member_2" --alias member
kli rotate --name "$member_3" --alias member

kli query --name "$member_2" --alias member --prefix "$member_3_aid"
kli query --name "$member_3" --alias member --prefix "$member_2_aid"

kli oobi resolve --name "$member_4" --oobi-alias member_1 --oobi "$member_1_oobi"
kli oobi resolve --name "$member_4" --oobi-alias member_2 --oobi "$member_2_oobi"
kli oobi resolve --name "$member_4" --oobi-alias member_3 --oobi "$member_3_oobi"

kli multisig rotate --name "$member_2" --alias group --smids "$member_2_aid" --smids "$member_3_aid" --smids "$member_4_aid" --isith "2" --nsith "2" --rmids "$member_2_aid" --rmids "$member_3_aid" --rmids "$member_4_aid" &
PID_LIST="$!"
kli multisig rotate --name "$member_3" --alias group --smids "$member_2_aid" --smids "$member_3_aid" --smids "$member_4_aid" --isith "2" --nsith "2" --rmids "$member_2_aid" --rmids "$member_3_aid" --rmids "$member_4_aid" &
PID_LIST+=" $!"
kli delegate confirm --name "$delegator" --alias delegator -Y &
PID_LIST+=" $!"

echo "Waiting for multisig rotate to complete"
wait $PID_LIST

kli oobi resolve --name "$member_4" --oobi-alias group --oobi "$group_oobi"
kli multisig join --name "$member_4" --group group --auto
kli local watch --name "$member_1"

# Catchup: export from member_2, import into member_4
kli multisig export --name "$member_2" --alias group | kli multisig import --name "$member_4" --alias group --auto

# Assert member_4 has the named registry and the credential
registry_count=$(kli vc registry list --name "$member_4" --alias group | wc -l)
if [ "$registry_count" -ne 1 ]; then
    echo "Expected 1 registry on member_4, got $registry_count"
    exit 1
fi

said_count=$(kli vc list --name "$member_4" --alias group --said | wc -l)
if [ "$said_count" -ne 1 ]; then
    echo "Expected 1 credential on member_4, got $said_count"
    exit 1
fi
