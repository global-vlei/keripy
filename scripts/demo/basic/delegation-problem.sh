#!/bin/bash
set -e

# If kli is not installed, install from requirements.txt
if ! command -v kli &> /dev/null; then
    echo "kli could not be found, installing from requirements.txt..."
    python3 -m venv .venv
    source .venv/bin/activate
    pip install -r requirements.txt
fi

pkill kli || true

function cleanup() {
    pkill kli || true
}
trap cleanup EXIT

suffix=$(head /dev/urandom | tr -dc a-z0-9 | head -c4)
delegator="delegator_${suffix}"
delegator_witness="delegator_witness_${suffix}"

delegate="delegate_${suffix}"
delegate_witness="delegate_witness_${suffix}"

delegator_witness_http_port="5642"
delegator_witness_tcp_port="5632"
delegate_witness_http_port="5643"
delegate_witness_tcp_port="5633"
delegator_witness_url="http://127.0.0.1:$delegator_witness_http_port"
delegate_witness_url="http://127.0.0.1:$delegate_witness_http_port"

config_dir="$(mktemp -d)/keri"
mkdir -p "$config_dir/keri/cf"
delegator_config_json="$config_dir/keri/cf/delegator_config.json"
delegate_config_json="$config_dir/keri/cf/delegate_config.json"

kli init --name "$delegator_witness" --nopasscode
kli incept --name "$delegator_witness" --alias witness --icount 1 --ncount 0 --isith 1 --nsith 0 --toad 0
delegator_witness_aid=$(kli aid --name "$delegator_witness" --alias witness)
kli ends add --name "$delegator_witness" --alias witness --eid "$delegator_witness_aid" --role controller
kli location add --name "$delegator_witness" --alias witness --url "$delegator_witness_url"
kli witness start --name "$delegator_witness" --alias witness -H "$delegator_witness_http_port" -T "$delegator_witness_tcp_port" &
delegator_witness_pid=$!

while ! curl -s "$delegator_witness_url" > /dev/null; do
    echo "Waiting for delegator witness to be ready..."
    sleep 1
done

kli init --name "$delegate_witness" --nopasscode
kli incept --name "$delegate_witness" --alias witness --icount 1 --ncount 0 --isith 1 --nsith 0 --toad 0
delegate_witness_aid=$(kli aid --name "$delegate_witness" --alias witness)
kli ends add --name "$delegate_witness" --alias witness --eid "$delegate_witness_aid" --role controller
kli location add --name "$delegate_witness" --alias witness --url "$delegate_witness_url"
kli witness start --name "$delegate_witness" --alias witness -H "$delegate_witness_http_port" -T "$delegate_witness_tcp_port" &
delegate_witness_pid=$!

while ! curl -s "$delegate_witness_url" > /dev/null; do
    echo "Waiting for delegate witness to be ready..."
    sleep 1
done

cat << EOF > "$delegator_config_json"
{
    "dt": "2026-03-10T00:00:00.000000+00:00",
    "iurls": [
        "$delegator_witness_url/oobi/$delegator_witness_aid/controller"
    ]
}
EOF

cat << EOF > "$delegate_config_json"
{
    "dt": "2026-03-10T00:00:00.000000+00:00",
    "iurls": [
        "$delegate_witness_url/oobi/$delegate_witness_aid/controller"
    ]
}
EOF

kli init --name "$delegator" --config-dir "$config_dir" --config-file delegator_config --nopasscode
kli init --name "$delegate" --config-dir "$config_dir" --config-file delegate_config --nopasscode

kli incept --name "$delegator" --alias delegator --icount 1 --ncount 1 --isith 1 --nsith 1 --transferable --toad 1 --wit "$delegator_witness_aid"
kli ends add --name "$delegator" --alias delegator --eid "$delegator_witness_aid" --role mailbox
delegator_aid=$(kli aid --name "$delegator" --alias delegator)
delegator_oobi=$(kli oobi generate --name "$delegator" --alias delegator --role witness | tail -n 1)

kli incept --name "$delegate" --alias proxy --icount 1 --ncount 1 --isith 1 --nsith 1 --transferable --toad 1 --wit "$delegate_witness_aid"
kli ends add --name "$delegate" --alias proxy --eid "$delegate_witness_aid" --role mailbox
proxy_oobi=$(kli oobi generate --name "$delegate" --alias proxy --role witness | tail -n 1)
kli oobi resolve --name "$delegate" --oobi-alias delegator --oobi "$delegator_oobi"
kli oobi resolve --name "$delegator" --oobi-alias delegate --oobi "$proxy_oobi"
kli incept --name "$delegate" --alias delegate --icount 1 --ncount 1 --isith 1 --nsith 1 --transferable --toad 1 --wit "$delegate_witness_aid" --delpre "$delegator_aid" --proxy proxy &
PID_LIST="$!"
kli delegate confirm --name "$delegator" --alias delegator --interact -Y &
PID_LIST+=" $!"
wait $PID_LIST

kli ends add --name "$delegate" --alias delegate --eid "$delegate_witness_aid" --role mailbox
delegate_aid=$(kli aid --name "$delegate" --alias delegate)
delegate_oobi=$(kli oobi generate --name "$delegate" --alias delegate --role witness | tail -n 1)

echo "--------------------------------"
echo "Delegate kevers from delegator, note showing 'Anchored'"
echo "--------------------------------"

kli kevers --name "$delegator" --prefix "$delegate_aid"

echo "--------------------------------"
echo "Delegate kevers from delegate, note showing 'Anchored'"
echo "--------------------------------"

kli kevers --name "$delegate" --prefix "$delegate_aid"

echo "--------------------------------"
echo "Delegate kevers from delegate witness, note showing 'Not anchored'"
echo "--------------------------------"

kli kevers --name "$delegate_witness" --prefix "$delegate_aid"
