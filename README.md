# my-homelab-oci

Scripts, configs, files for my always free tier instance in OCI.

---

## Deployment

### 1. Clone and move to /srv

```bash
git clone git@github.com:itsfin3/my-homelab-oci.git
sudo mv -v my-homelab-oci/docker /srv/
```

### 2. Deploy Portainer

```bash
cd /srv/docker/server-management/portainer

# Edit .env with real values
sudo vim .env

sudo docker compose up -d
```

Portainer (and prometheus, grafana) are published on `10.10.0.1` — the main wg-easy VPN's own tunnel address — not `0.0.0.0`. This only works once wg-easy is deployed and its `wg0` interface exists on the host.

**Bootstrap order matters on a fresh install:** deploy `wg-easy` (step 3, host network mode) *before* portainer, prometheus, or grafana will bind successfully — otherwise their `ports:` publish fails at container start with `cannot assign requested address` (retries automatically via `restart: unless-stopped` once wg0 comes up, but faster to just deploy wg-easy first).

Once wg-easy is up and you're connected to the VPN, open `https://10.10.0.1:9443` for Portainer.

### 3. Re-add stacks via Portainer UI

After Portainer is running, add each stack from this git repo:

1. Open Portainer → **Stacks** → **Add stack**
2. Select **Repository**
3. Fill in:
   - **Repository URL:** `https://github.com/itsfin3/my-homelab-oci`
   - **Repository reference:** `refs/heads/main`
   - **Compose path:** e.g. `docker/server-management/grafana/docker-compose.yml`
4. Scroll to **Environment variables** → add values from the stack's `.env` file
5. Click **Deploy the stack**

Repeat for each stack under `docker/`.

> **Don't use `utilities/redeploy_stacks.sh` or manual `docker compose -f /srv/... up -d` for stacks managed this way.** Mixing manual compose runs with Portainer's git-based stack deploy causes config drift — Portainer's next redeploy silently overwrites whatever the manual run set, and vice versa. Once a stack is added via Portainer's Repository method, always redeploy it through the Portainer UI (pull + redeploy) so git stays the single source of truth.

### Stacks

| Stack | Path | Description |
|---|---|---|
| portainer | `docker/server-management/portainer` | Docker management UI |
| wg-easy | `docker/server-management/wg-easy` | WireGuard VPN + web UI |
| grafana | `docker/monitoring/grafana` | Metrics dashboards |
| prometheus | `docker/monitoring/prometheus` | Metrics collection (includes node-exporter, cAdvisor) |
| minecraft | `docker/hobby/minecraft` | Minecraft Paper server + MySQL (AuthMe) |
| nginx | `docker/hobby/nginx` | Static site + HTTPS redirect |

---

## Notes

### wg-easy

> **Warning:** wg-easy will create its own `wg0` interface. Stop and disable any existing WireGuard (`wg0`) on the host before deploying.

Before deploying, set required sysctls permanently on the host:
```bash
echo "net.ipv4.conf.all.src_valid_mark=1" | sudo tee -a /etc/sysctl.d/99-wireguard.conf
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.d/99-wireguard.conf
sudo sysctl -p /etc/sysctl.d/99-wireguard.conf
```

Web UI runs on port `51821`, bound to `127.0.0.1` only (not public) — access via SSH tunnel:
```bash
ssh -L 51821:localhost:51821 -fN <user>@<server-ip>
```
Then open `http://localhost:51821`.

Same pattern for the hobby VPNs: `wg-easy-hobby` UI on `51823`, `wg-easy-public` UI on `51825`, both `127.0.0.1`-bound — tunnel to those ports the same way. Their VPN data ports (`51822`/udp, `51824`/udp) stay published on `0.0.0.0` since that's the actual tunnel traffic clients need to reach.

### Networking / firewall gotcha

Docker's own iptables rules (nat `DOCKER` chain DNAT + filter `FORWARD` chain ACCEPT) bypass the host's custom INPUT chain firewall for **any** published container port — a `ports:` entry is reachable from the public internet even if that port isn't in the host's iptables ACCEPT list. Binding to `0.0.0.0` (the default) always means public.

When adding a new stack, decide access scope deliberately and bind accordingly:
- Public-facing (e.g. minecraft, nginx 80/443): `"PORT:PORT"` is fine.
- Host-only (e.g. mysql, admin UIs before VPN existed): `"127.0.0.1:PORT:PORT"`.
- VPN-only (portainer, prometheus, grafana currently): `"10.10.0.1:PORT:PORT"` — reachable only from the host itself or clients connected through the main wg-easy VPN, since `10.10.0.1` is that VPN's own tunnel address on the host (requires wg-easy running in `network_mode: host`, see bootstrap-order note above).

### minecraft

AuthMe config is at `docker/hobby/minecraft/data/plugins/AuthMe/config.yml` — copied to `/srv` with the rest of `docker/`. Set the real MySQL password before deploying:
```bash
sudo vim /srv/docker/hobby/minecraft/data/plugins/AuthMe/config.yml
```
Restart Minecraft after editing.

### prometheus

Prometheus runs as UID 65534 (nobody). Create and own the data dir before deploying:
```bash
sudo mkdir -p /srv/docker/monitoring/prometheus/data
sudo chown -R 65534:65534 /srv/docker/monitoring/prometheus/data
```
