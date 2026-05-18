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

Portainer UI is blocked by firewall — access via SSH tunnel:
```bash
ssh -L 9443:localhost:9443 -fN <user>@<server-ip>
```
Then open `https://localhost:9443`.

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

Web UI runs on port `51821` — blocked by firewall by default, access via SSH tunnel:
```bash
ssh -L 51821:localhost:51821 -fN <user>@<server-ip>
```
Then open `http://localhost:51821`.

### minecraft

AuthMe config is at `docker/hobby/minecraft/plugins/AuthMe/config.yml`. After deploy, copy it to the server and set the real MySQL password:
```bash
sudo cp docker/hobby/minecraft/plugins/AuthMe/config.yml \
     /srv/docker/hobby/minecraft/data/plugins/AuthMe/config.yml

# Then edit and set mySQLPassword to the real value
sudo vim /srv/docker/hobby/minecraft/data/plugins/AuthMe/config.yml
```
Restart Minecraft after editing.

### prometheus

Prometheus runs as UID 65534 (nobody). Create and own the data dir before deploying:
```bash
sudo mkdir -p /srv/docker/monitoring/prometheus/data
sudo chown -R 65534:65534 /srv/docker/monitoring/prometheus/data
```
