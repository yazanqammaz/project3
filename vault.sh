#!/usr/bin/env bash
set -euo pipefail

VAULT_DIR="./vault"
KEYS_DIR="${VAULT_DIR}/keys"

mkdir -p "${KEYS_DIR}" "${VAULT_DIR}/data"

echo "[1/6] Starting Vault..."
docker compose -f "${VAULT_DIR}/docker-compose.yml" up -d

echo "[2/6] Waiting for Vault..."
until curl -s http://127.0.0.1:8200/v1/sys/health >/dev/null 2>&1; do
  sleep 2
done

if [ ! -f "${KEYS_DIR}/init.json" ]; then
  echo "[3/6] Initializing Vault..."
  docker exec project3_vault vault operator init -format=json > "${KEYS_DIR}/init.json"
else
  echo "[3/6] Vault already initialized."
fi

SEALED=$(docker exec project3_vault vault status -format=json | python3 -c 'import sys,json; print(json.load(sys.stdin)["sealed"])')

if [ "$SEALED" = "True" ] || [ "$SEALED" = "true" ]; then
  echo "[4/6] Unsealing Vault..."

  for i in 0 1 2
  do
    UNSEAL_KEY=$(python3 -c "import json; print(json.load(open('${KEYS_DIR}/init.json'))['unseal_keys_b64'][$i])")

    docker exec project3_vault \
      vault operator unseal "${UNSEAL_KEY}" >/dev/null
  done
else
  echo "[4/6] Vault is already unsealed."
fi

ROOT_TOKEN=$(python3 -c "import json; print(json.load(open('${KEYS_DIR}/init.json'))['root_token'])")

echo "[5/6] Ensuring KV secrets engine exists..."
docker exec -e VAULT_TOKEN="${ROOT_TOKEN}" project3_vault \
  vault secrets enable -path=secret kv-v2 >/dev/null 2>&1 || true

echo "[6/6] Vault is ready."

echo
echo "Vault status:"
docker exec project3_vault vault status
