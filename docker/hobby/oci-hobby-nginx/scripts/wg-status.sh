#!/bin/bash
# Generates a sanitized VPN status JSON (no keys) for vpn.itsfin3.com, polled by its index.html.
# Must run as root (or via sudo) — reads wg0.json (0640 root:root) for client names.
set -uo pipefail

OUT=/srv/docker/hobby/oci-hobby-nginx/html/DOMAIN_3/status.json
NOW=$(date +%s)
THRESHOLD=180 # seconds since last handshake to consider a peer "connected"

vpn_json() {
  local id=$1 label=$2 container=$3 subnet=$4 port=$5 jsonfile=$6 exclude=${7:-}
  local dump

  if ! dump=$(docker exec "$container" wg show wg0 dump 2>/dev/null); then
    jq -n --arg id "$id" --arg label "$label" --arg subnet "$subnet" --argjson port "$port" \
      '{id:$id,label:$label,subnet:$subnet,port:$port,up:false,clients:[]}'
    return
  fi

  local dump_json
  dump_json=$(echo "$dump" | tail -n +2 | awk -F'\t' '
    BEGIN{print "["}
    NF>=5 {printf "%s{\"pubkey\":\"%s\",\"hs\":%s}", (n++>0?",":""), $1, ($5==""?0:$5)}
    END{print "]"}')

  jq -n \
    --argjson clients_raw "$(jq '[.clients[] | {name,address,enabled,publicKey}]' "$jsonfile" 2>/dev/null || echo '[]')" \
    --argjson dump "$dump_json" \
    --argjson now "$NOW" --argjson threshold "$THRESHOLD" \
    --arg exclude "$exclude" \
    --arg id "$id" --arg label "$label" --arg subnet "$subnet" --argjson port "$port" '
    ($dump | map({(.pubkey): .hs}) | add // {}) as $hsmap
    | [ $clients_raw[] | select(.name != $exclude) |
        ($hsmap[.publicKey] // 0) as $hs |
        { name, address, enabled,
          connected: (.enabled and ($hs>0) and (($now-$hs) < $threshold)),
          last_handshake_sec: (if $hs>0 then ($now-$hs) else null end)
        }
      ] as $clients
    | {id:$id,label:$label,subnet:$subnet,port:$port,up:true,clients:$clients}
  '
}

# Main VPN is never published on the public site — only hobby + public.
HOBBY=$(vpn_json hobby "Hobby VPN" oci-hobby-wg-private "20.20.0.0/24" 51822 /srv/docker/hobby/oci-hobby-wg-private/data/wg0.json "server-access")
PUBLIC=$(vpn_json public "Public VPN" oci-hobby-wg-public "30.30.0.0/24" 51824 /srv/docker/hobby/oci-hobby-wg-public/data/wg0.json "server-access")

# Resolved fresh each run so a DNS/IP change on the host is picked up automatically.
SERVER_IP=$(dig +short -4 vpn.itsfin3.com A | tail -n1)

jq -n --argjson hobby "$HOBBY" --argjson public "$PUBLIC" --arg server_ip "$SERVER_IP" --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{generated_at:$ts, server_ip:$server_ip, vpns:[$hobby,$public]}' > "${OUT}.tmp" && mv "${OUT}.tmp" "$OUT"
chmod 644 "$OUT"
