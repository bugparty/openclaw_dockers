# OpenViking operational notes

## Live config lives on the PVC

The entrypoint writes `/app/.openviking/ov.conf` from the `openviking-config` Secret
**only when the file doesn't exist**. After the first start, edit `ov.conf` on the PVC
(and mirror the change into the Secret so a fresh PVC gets it). Never `kubectl apply`
`openviking-memory.yaml` as-is: its Secret holds placeholder keys.

Non-default settings in the live `ov.conf`:

- `embedding.dense.dimension: 1024` (llama-cpp `model.gguf` returns 1024-dim vectors)
- `vlm`: OpenRouter, `inclusionai/ling-3.0-flash-sante:free` primary,
  `extra_request_body.models` fallback to `stealth/space-bunny-alpha`, `max_tokens: 8192`
- `memory.custom_templates_dir: /app/.openviking/memory-templates`

## Memory templates (`memory-templates/`)

Copies of the bundled v0.4.21 memory templates with a credential-policy rule prepended
to each `description`, so extraction never stores passwords, keys or tokens.

Restore onto the PVC:

```bash
P=$(sudo k0s kubectl -n openclaw get pod -l app=openviking -o jsonpath='{.items[0].metadata.name}')
tar -C k8s/openviking -cf - memory-templates | sudo k0s kubectl -n openclaw exec -i "$P" -- tar -C /app/.openviking -xf -
sudo k0s kubectl -n openclaw delete pod "$P"
```

After upgrading OpenViking, re-merge: diff these files against
`/app/.venv/lib/python3.13/site-packages/openviking/prompts/templates/memory/` in the new
image and carry the credential-policy block over.

## Secret scanner (`../hermes/scripts/ov_secret_scan.py`)

Hourly Hermes no-agent cron job that redacts credentials found in OpenViking memories
and alerts on Telegram (silent when clean). Install:

```bash
sudo k0s kubectl -n openclaw cp k8s/hermes/scripts/ov_secret_scan.py openclaw/hermes-t8kr5:/home/node/.hermes/scripts/ov_secret_scan.py -c hermes
sudo k0s kubectl -n openclaw exec hermes-t8kr5 -c hermes -- sh -c \
  'chmod 700 ~/.hermes/scripts/ov_secret_scan.py && ~/.local/bin/hermes cron create --name ov-secret-scan --script ov_secret_scan.py --no-agent --deliver telegram "7 * * * *"'
```

`--dry-run` reports without changing anything.
