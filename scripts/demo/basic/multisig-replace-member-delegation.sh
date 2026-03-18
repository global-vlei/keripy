#!/bin/bash
set -e

# Test script for replacing a multisig member (with two-level delegation, no registries/credentials)
# Delegation chain: root -> delegator -> group
# The initial multisig group:
#   (member_1, member_2, member_3) with signature threshold 2, delpre=delegator
# The multisig group after rotation:
#   (member_2, member_3, member_4) with signature threshold 2

suffix=$(head /dev/urandom | tr -dc a-z0-9 | head -c4)
root="root_${suffix}"
delegator="delegator_${suffix}"
member_1="member_1_${suffix}"
member_2="member_2_${suffix}"
member_3="member_3_${suffix}"
member_4="member_4_${suffix}"

group_witness_aid="BBilc4-L3tFUnfM_wJr4S4OJanAv_VmF_dJNN6vkf2Ha"
group_witness_url="http://127.0.0.1:5642/oobi/$group_witness_aid/controller"
delegator_witness_aid="BLskRTInXnMxWaGqcpSyMgo0nYbalW99cGZESrz3zapM"
delegator_witness_url="http://127.0.0.1:5643/oobi/$delegator_witness_aid/controller"

config_dir="$(mktemp -d)/keri"
mkdir -p "$config_dir/keri/cf"
group_config_json="$config_dir/keri/cf/group_config.json"
delegator_config_json="$config_dir/keri/cf/delegator_config.json"
root_config_json="$config_dir/keri/cf/root_config.json"

cat << EOF > "$group_config_json"
{
    "dt": "2026-03-10T00:00:00.000000+00:00",
    "iurls": [
        "$group_witness_url"
    ]
}
EOF

cat << EOF > "$delegator_config_json"
{
    "dt": "2026-03-10T00:00:00.000000+00:00",
    "iurls": [
        "$delegator_witness_url"
    ]
}
EOF

cat << EOF > "$root_config_json"
{
    "dt": "2026-03-10T00:00:00.000000+00:00",
    "iurls": [
        "$delegator_witness_url"
    ]
}
EOF

exit_hook() {
    echo kli status --name "$member_1" --alias group
    echo kli status --name "$member_2" --alias group
    echo kli status --name "$member_3" --alias group
    echo kli status --name "$member_4" --alias group
    echo kli status --name "$delegator" --alias delegator
    echo kli status --name "$root" --alias root

    if [ -n "$group_oobi" ]; then
        echo "Group oobi: $group_oobi"
    fi
    if [ -n "$root_oobi" ]; then
        echo "Root oobi: $root_oobi"
    fi
    if [ -n "$delegator_oobi" ]; then
        echo "Delegator oobi: $delegator_oobi"
    fi
    if [ -n "$member_1_oobi" ]; then
        echo "Member 1 oobi: $member_1_oobi"
    fi
    if [ -n "$member_2_oobi" ]; then
        echo "Member 2 oobi: $member_2_oobi"
    fi
    if [ -n "$member_3_oobi" ]; then
        echo "Member 3 oobi: $member_3_oobi"
    fi
    if [ -n "$member_4_oobi" ]; then
        echo "Member 4 oobi: $member_4_oobi"
    fi
}
trap exit_hook EXIT

if ! curl -s "$group_witness_url" > /dev/null; then
    echo "Witness URL is not reachable, remember to run: kli witness demo"
    exit 1
fi
if ! curl -s "$delegator_witness_url" > /dev/null; then
    echo "Delegator witness URL is not reachable, remember to run: kli witness demo"
    exit 1
fi

kli init --name "$member_1" --config-dir "$config_dir" --config-file group_config --nopasscode
kli init --name "$member_2" --config-dir "$config_dir" --config-file group_config --nopasscode
kli init --name "$member_3" --config-dir "$config_dir" --config-file group_config --nopasscode
kli init --name "$member_4" --config-dir "$config_dir" --config-file group_config --nopasscode
kli init --name "$delegator" --config-dir "$config_dir" --config-file delegator_config --nopasscode
kli init --name "$root" --config-dir "$config_dir" --config-file root_config --nopasscode

# Root incepts first (no delpre). Then in delegator keystore: proxy hab for sending delegation messages, then delegator incepts as delegate of root.
kli incept --name "$root" --alias root --icount 1 --ncount 1 --isith 1 --nsith 1 --transferable --toad 1 --wit "$delegator_witness_aid"
kli ends add --name "$root" --alias root --eid "$delegator_witness_aid" --role mailbox
root_aid=$(kli aid --name "$root" --alias root)
root_oobi=$(kli oobi generate --name "$root" --alias root --role witness | tail -n 1)
kli oobi resolve --name "$delegator" --oobi-alias root --oobi "$root_oobi"

# Proxy hab in delegator keystore (same witness as root) so delegator can send delegation request to root
kli incept --name "$delegator" --alias proxy --icount 1 --ncount 1 --isith 1 --nsith 1 --transferable --toad 1 --wit "$delegator_witness_aid"
kli ends add --name "$delegator" --alias proxy --eid "$delegator_witness_aid" --role mailbox

# Delegator incepts as delegate of root (--proxy for delegation communication); root accepts in parallel
kli incept --name "$delegator" --alias delegator --icount 1 --ncount 1 --isith 1 --nsith 1 --transferable --toad 1 --wit "$delegator_witness_aid" --delpre "$root_aid" --proxy proxy &
PID_LIST="$!"
kli delegate confirm --name "$root" --alias root -Y &
PID_LIST+=" $!"
wait $PID_LIST

kli incept --name "$member_1" --alias member --icount 1 --ncount 1 --isith 1 --nsith 1 --transferable --toad 1 --wit "$group_witness_aid"
kli incept --name "$member_2" --alias member --icount 1 --ncount 1 --isith 1 --nsith 1 --transferable --toad 1 --wit "$group_witness_aid"
kli incept --name "$member_3" --alias member --icount 1 --ncount 1 --isith 1 --nsith 1 --transferable --toad 1 --wit "$group_witness_aid"
kli incept --name "$member_4" --alias member --icount 1 --ncount 1 --isith 1 --nsith 1 --transferable --toad 1 --wit "$group_witness_aid"
kli ends add --name "$delegator" --alias delegator --eid "$delegator_witness_aid" --role mailbox
kli ends add --name "$member_1" --alias member --eid "$group_witness_aid" --role mailbox
kli ends add --name "$member_2" --alias member --eid "$group_witness_aid" --role mailbox
kli ends add --name "$member_3" --alias member --eid "$group_witness_aid" --role mailbox
kli ends add --name "$member_4" --alias member --eid "$group_witness_aid" --role mailbox

delegator_oobi=$(kli oobi generate --name "$delegator" --alias delegator --role witness | tail -n 1)
member_1_oobi=$(kli oobi generate --name "$member_1" --alias member --role witness | tail -n 1)
member_2_oobi=$(kli oobi generate --name "$member_2" --alias member --role witness | tail -n 1)
member_3_oobi=$(kli oobi generate --name "$member_3" --alias member --role witness | tail -n 1)
member_4_oobi=$(kli oobi generate --name "$member_4" --alias member --role witness | tail -n 1)
delegator_aid=$(kli aid --name "$delegator" --alias delegator)
member_1_aid=$(kli aid --name "$member_1" --alias member)
member_2_aid=$(kli aid --name "$member_2" --alias member)
member_3_aid=$(kli aid --name "$member_3" --alias member)
member_4_aid=$(kli aid --name "$member_4" --alias member)

kli oobi resolve --name "$member_1" --oobi-alias member_2 --oobi "${member_2_oobi}"
kli oobi resolve --name "$member_1" --oobi-alias member_3 --oobi "${member_3_oobi}"
kli oobi resolve --name "$member_1" --oobi-alias delegator --oobi "${delegator_oobi}"

kli oobi resolve --name "$member_2" --oobi-alias member_1 --oobi "${member_1_oobi}"
kli oobi resolve --name "$member_2" --oobi-alias member_3 --oobi "${member_3_oobi}"
kli oobi resolve --name "$member_2" --oobi-alias delegator --oobi "${delegator_oobi}"

kli oobi resolve --name "$member_3" --oobi-alias member_1 --oobi "${member_1_oobi}"
kli oobi resolve --name "$member_3" --oobi-alias member_2 --oobi "${member_2_oobi}"
kli oobi resolve --name "$member_3" --oobi-alias delegator --oobi "${delegator_oobi}"

# Delegator needs to resolve member_1 and member_2 OOBI to send delegation approval to them
kli oobi resolve --name "$delegator" --oobi-alias member_1 --oobi "${member_1_oobi}"
kli oobi resolve --name "$delegator" --oobi-alias member_2 --oobi "${member_2_oobi}"

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
kli delegate confirm --name "$delegator" --alias delegator --interact -Y &
PID_LIST+=" $!"
wait $PID_LIST

group_oobi=$(kli oobi generate --name "$member_1" --alias group --role witness | tail -n 1)
group_aid=$(kli aid --name "$member_1" --alias group)


# Member 3 joins the group
kli oobi resolve --name "$member_3" --oobi-alias group --oobi "$group_oobi"
kli multisig join --name "$member_3" --group group --auto
kli status --name "$member_3" --alias group
kli kevers --name "$member_3" --prefix "$group_aid"


# Member 4 joins the group
kli rotate --name "$member_2" --alias member
kli query --name "$member_3" --alias member --prefix "$member_2_aid"

kli rotate --name "$member_3" --alias member
kli query --name "$member_2" --alias member --prefix "$member_3_aid"

kli oobi resolve --name "$member_1" --oobi-alias member_4 --oobi "$member_4_oobi"
kli oobi resolve --name "$member_2" --oobi-alias member_4 --oobi "$member_4_oobi"
kli oobi resolve --name "$member_3" --oobi-alias member_4 --oobi "$member_4_oobi"

kli oobi resolve --name "$member_4" --oobi-alias delegator --oobi "$delegator_oobi"
kli oobi resolve --name "$member_4" --oobi-alias member_1 --oobi "$member_1_oobi"
kli oobi resolve --name "$member_4" --oobi-alias member_2 --oobi "$member_2_oobi"
kli oobi resolve --name "$member_4" --oobi-alias member_3 --oobi "$member_3_oobi"

kli multisig rotate --name "$member_2" --alias group --smids "$member_2_aid" --smids "$member_3_aid" --smids "$member_4_aid" --isith "2" --nsith "2" --rmids "$member_2_aid" --rmids "$member_3_aid" --rmids "$member_4_aid" &
PID_LIST="$!"
kli multisig rotate --name "$member_3" --alias group --smids "$member_2_aid" --smids "$member_3_aid" --smids "$member_4_aid" --isith "2" --nsith "2" --rmids "$member_2_aid" --rmids "$member_3_aid" --rmids "$member_4_aid" &
PID_LIST+=" $!"
kli delegate confirm --name "$delegator" --alias delegator --interact -Y &
PID_LIST+=" $!"
echo "Waiting for multisig rotate to complete..."
wait $PID_LIST

# kli status --name "$member_1" --alias group
# kli status --name "$member_2" --alias group

echo kli oobi resolve --name "$member_4" --oobi-alias group --oobi "$group_oobi"
echo kli multisig join --name "$member_4" --group group --auto

# # kli local watch --name "$member_1"

# # kli status --name "$member_1" --alias group
# # kli status --name "$member_2" --alias group
# # kli status --name "$member_3" --alias group
# # kli status --name "$member_4" --alias group

# echo "kli kevers --name $member_1 --prefix $group_aid"
# echo "kli kevers --name $member_2 --prefix $group_aid"
# echo "kli kevers --name $member_3 --prefix $group_aid"
# echo "kli kevers --name $member_4 --prefix $group_aid"
