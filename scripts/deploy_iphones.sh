#!/bin/zsh
set -euo pipefail

readonly script_dir="${0:A:h}"

typeset -a device_ids
if [[ -n "${DEVICE_IDS:-}" ]]; then
  device_ids=("${(@s: :)DEVICE_IDS}")
else
  device_ids=(
    "FEF52235-CFDD-5B89-B733-DD62E491295B" # Pipsniffs phone
    "F87EDE3E-1AE4-55DE-8D82-43CB7EDF7800" # dave's iPhone
  )
fi

for device_id in "${device_ids[@]}"; do
  print "Deploying to device $device_id…"
  DEVICE_ID="$device_id" "$script_dir/deploy_iphone.sh"
done

print "uFast was deployed to ${#device_ids[@]} iPhones."
