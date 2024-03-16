#!/usr/bin/env bash

# Get directory relative to this script
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

echo "* Packing payload..."
sudo tar -cvpf ${DIR}/payload.tar -C ${DIR}/payload .
