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
nano .env

docker compose up -d
```

Portainer will be available at `https://<your-domain>:9443`.

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

---

## Notes

### wg-easy

> **Warning:** wg-easy will create its own `wg0` interface. Stop and disable any existing WireGuard (`wg0`) on the host before deploying.

Generate the password hash before deploying:
```bash
docker run --rm ghcr.io/wg-easy/wg-easy wgpw YOUR_PASSWORD
```
Paste the output into `WG_PASSWORD_HASH` in the Portainer stack environment variables.

Web UI runs on port `51821` — blocked by firewall by default, access via SSH tunnel:
```bash
ssh -i ~/.ssh/oci-ubuntu -L 51821:localhost:51821 -fN ubuntu@<server-ip>
```
Then open `http://localhost:51821`.
