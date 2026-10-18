# Elasticsearch 9.5.2 Administration Manual

**Environment**

| Component             | Specs                |
| --------------------- | -------------------- |
| OS                    | Oracle Linux 9.8     |
| Elasticsearch Version | 9.5.2                |
| Install Directory     | `/u01/elasticsearch` |
| Cluster Name          | `my-cluster`         |
| Node Name             | `node-1`             |
| HTTP Port             | `9200`               |
| Transport Port        | `9300`               |
| Discovery Mode        | `single-node`        |

---

## Table of Contents
1. [Installation](#1-installation)
2. [Starting & Verifying the Service](#2-starting--verifying-the-service)
3. [Resetting the `elastic` Superuser Password](#3-resetting-the-elastic-superuser-password)
4. [SELinux Troubleshooting](#4-selinux-troubleshooting)
5. [User & Role Management](#5-user--role-management)
6. [Granting Kibana Access](#6-granting-kibana-access)
7. [Deleting a User](#7-deleting-a-user)
8. [Sharing Connection Details with Developers](#8-sharing-connection-details-with-developers)
9. [Security Best Practices](#9-security-best-practices)
10. [Troubleshooting Quick Reference](#10-troubleshooting-quick-reference)
11. [Appendix: Full Command Log](#11-appendix-full-command-log)

---

## 1. Installation

Elasticsearch was installed via the **archive (tar.gz) method** — required because RPM packaging hardcodes system paths, and this environment uses the custom `/u01` mount.

### 1.1 Prerequisites
```bash
cat /etc/oracle-release
sudo dnf update -y
sudo dnf install -y wget tar which
```
> Elasticsearch 9.x bundles its own JDK — no separate Java install needed.

### 1.2 Create the service account
```bash
sudo groupadd elasticsearch
sudo useradd -g elasticsearch -d /u01/elasticsearch -s /sbin/nologin elasticsearch

sudo mkdir -p /u01/elasticsearch/{data,logs,config}
```

### 1.3 Download and verify
```bash
cd /tmp
wget https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-9.5.2-linux-x86_64.tar.gz
wget https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-9.5.2-linux-x86_64.tar.gz.sha512
shasum -a 512 -c elasticsearch-9.5.2-linux-x86_64.tar.gz.sha512
```

### 1.4 Extract and lay out directories
```bash
sudo tar -xzf elasticsearch-9.5.2-linux-x86_64.tar.gz -C /u01/
sudo mv /u01/elasticsearch-9.5.2 /u01/elasticsearch/es_home_952

sudo rm -rf /u01/elasticsearch/es_home_952/data /u01/elasticsearch/es_home_952/logs
sudo cp -r /u01/elasticsearch/es_home_952/config/* /u01/elasticsearch/config/
sudo rm -rf /u01/elasticsearch/es_home_952/config
sudo ln -s /u01/elasticsearch/config /u01/elasticsearch/es_home_952/config

sudo chown -R elasticsearch:elasticsearch /u01/elasticsearch
```

### 1.5 Core configuration — `elasticsearch.yml`
`/u01/elasticsearch/config/elasticsearch.yml`
```yaml
cluster.name: my-cluster
node.name: node-1
path.data: /u01/elasticsearch/data
path.logs: /u01/elasticsearch/logs
network.host: 0.0.0.0
http.port: 9200
transport.port: 9300
discovery.type: single-node
```

### 1.6 JVM heap
`/u01/elasticsearch/config/jvm.options.d/heap.options`
```
-Xms4g
-Xmx4g
```
> Rule of thumb: ~50% of available RAM, never above ~31 GB.

### 1.7 OS-level tuning (required)
```bash
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

sudo tee /etc/security/limits.d/elasticsearch.conf << 'EOF'
elasticsearch soft nofile 65535
elasticsearch hard nofile 65535
elasticsearch soft nproc 4096
elasticsearch hard nproc 4096
elasticsearch soft memlock unlimited
elasticsearch hard memlock unlimited
EOF
```

### 1.8 systemd unit
`/etc/systemd/system/elasticsearch.service`
```ini
[Unit]
Description=Elasticsearch
Documentation=https://elastic.co
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
RuntimeDirectory=elasticsearch
PrivateTmp=true
Environment=ES_HOME=/u01/elasticsearch/es_home_952
Environment=ES_PATH_CONF=/u01/elasticsearch/config
Environment=DATA_DIR=/u01/elasticsearch/data
Environment=LOG_DIR=/u01/elasticsearch/logs
Environment=PID_DIR=/run/elasticsearch
User=elasticsearch
Group=elasticsearch
ExecStart=/u01/elasticsearch/es_home_952/bin/elasticsearch -p ${PID_DIR}/elasticsearch.pid --quiet -Epath.data=${DATA_DIR} -Epath.logs=${LOG_DIR}
StandardOutput=journal
StandardError=inherit
LimitNOFILE=65535
LimitNPROC=4096
LimitAS=infinity
LimitFSIZE=infinity
TimeoutStartSec=0
SuccessExitStatus=143

[Install]
WantedBy=multi-user.target
```
```bash
sudo systemctl daemon-reload
sudo systemctl enable elasticsearch
```

### 1.9 Firewall
```bash
sudo firewall-cmd --permanent --add-port=9200/tcp
sudo firewall-cmd --permanent --add-port=9300/tcp
sudo firewall-cmd --reload
```

---

## 2. Starting & Verifying the Service

```bash
sudo systemctl start elasticsearch
sudo journalctl -u elasticsearch -f
```

On first boot, ES generates TLS certificates and prints the **one-time `elastic` superuser password**. Capture it immediately — it will not be shown again.

```bash
sudo journalctl -u elasticsearch | grep -B2 -A5 "elastic"
```

If missed, reset it:
```bash
sudo /u01/elasticsearch/es_home_952/bin/elasticsearch-reset-password -u elastic -i
```

**Verify the cluster is reachable:**
```bash
curl --cacert /u01/elasticsearch/config/certs/http_ca.crt \
  -u elastic:<password> https://localhost:9200
```
Expected response includes `"number" : "9.5.2"` and `"tagline" : "You Know, for Search"`.

**Check listening ports:**
```bash
netstat -ant | grep -i listen
```
Should show `:::9200` and `:::9300` in `LISTEN` state.

**Check `vm.max_map_count` took effect:**
```bash
sysctl vm.max_map_count
```
Should read `262144`.

---

## 3. Resetting the `elastic` Superuser Password

Use this whenever you need to set a **custom** password (not an auto-generated one) for the built-in `elastic` account — for example, after a first-boot bootstrap password was lost, or when standing up a new server and you don't want to reuse a password from another node.

> **Requirement:** the Elasticsearch service must already be `active (running)` — this tool talks to the live cluster, it does not just edit a config file.

### Interactive reset (you type the password)
```bash
sudo /u01/elasticsearch/es_home_952/bin/elasticsearch-reset-password -u elastic -i
```
You'll be prompted:
```
Enter password for [elastic]:
Re-enter password for [elastic]:
```

### Auto-generated reset (Elasticsearch picks one for you)
```bash
sudo /u01/elasticsearch/es_home_952/bin/elasticsearch-reset-password -u elastic
```

### Alternative — change a known password via the REST API
Only works if you already know the *current* password (used to authenticate the request):
```bash
curl -X POST --cacert /u01/elasticsearch/config/certs/http_ca.crt \
  -u elastic:<current-password> \
  https://localhost:9200/_security/user/elastic/_password \
  -H "Content-Type: application/json" -d '
{
  "password": "<your-new-custom-password>"
}'
```

> ⚠️ **Never reuse the same `elastic` password across multiple servers**, and never reuse a password that has previously been pasted into a chat, ticket, or shared document — treat it as compromised the moment it's been typed anywhere outside the terminal itself.

---

## 4. SELinux Troubleshooting

On Oracle Linux 9 with SELinux in `Enforcing` mode, Elasticsearch can fail to start with a **`Permission denied` / `203/EXEC`** error even when standard Unix file permissions (`rwxr-xr-x`, correct owner) are completely correct. This happens because SELinux enforces an additional **security context** on top of standard permissions — a binary without the right context (e.g. `bin_t`) can be blocked from executing even though `chmod`/`chown` look fine.

### Symptom
```
systemd[1]: elasticsearch.service: Failed to locate executable /u01/elasticsearch/es_home_952/bin/elasticsearch: Permission denied
systemd[1]: elasticsearch.service: Failed at step EXEC spawning ...: Permission denied
systemd[1]: elasticsearch.service: Main process exited, code=exited, status=203/EXEC
```

### Step 1 — Check SELinux mode
```bash
getenforce
```
- `Enforcing` → SELinux is actively blocking anything without the correct context — continue below.
- `Permissive` or `Disabled` → SELinux is not the cause; check for a `noexec` mount instead (see Troubleshooting table, Section 8).

### Step 2 — Inspect the binary's current SELinux context
```bash
ls -Z /u01/elasticsearch/es_home_952/bin/elasticsearch
```
Compare against a known-good system binary:
```bash
ls -Z /usr/bin/bash
```
If the ES binary shows a generic context like `unlabeled_t` or `usr_t` instead of `bin_t`, that mismatch is the cause — very common on a freshly built server where the labeling step was skipped during install.

### Step 3 — Fix the context
```bash
sudo semanage fcontext -a -t bin_t "/u01/elasticsearch/es_home_952/bin(/.*)?"
sudo restorecon -Rv /u01/elasticsearch/es_home_952/bin
```

### Step 4 — Restart and confirm
```bash
sudo systemctl restart elasticsearch
sudo systemctl status elasticsearch
```

### Step 5 — Confirm SELinux was actually the cause (optional but recommended)
```bash
sudo ausearch -m avc -ts recent | grep elasticsearch
```
Any `denied` entries referencing the Elasticsearch path confirm SELinux was blocking the exec.

### Fastest isolation test
Run the binary manually, bypassing systemd entirely:
```bash
sudo -u elasticsearch /u01/elasticsearch/es_home_952/bin/elasticsearch --version
```

| Result                                         | Meaning                                                  |
| ---------------------------------------------- | -------------------------------------------------------- |
| `Permission denied` + AVC denial in `ausearch` | SELinux context issue → apply Step 3                     |
| `Permission denied`, no AVC denial             | Likely a `noexec` mount → see Section 8                  |
| Runs normally                                  | Issue is systemd-specific (unit file, not SELinux/mount) |
|                                                |                                                          |

> **Note:** `semanage` requires the `policycoreutils-python-utils` package. If the command isn't found:
> ```bash
> sudo dnf install -y policycoreutils-python-utils
> ```

---

## 5. User & Role Management

Elasticsearch has no "database owner" concept like a relational DB. Instead, access is controlled through **roles** (permission sets) assigned to **users**. Never share the built-in `elastic` superuser with developers — always create scoped, named accounts.

### 3.1 List existing roles
```bash
curl --cacert /u01/elasticsearch/config/certs/http_ca.crt \
  -u 'elastic:<password>' \
  https://localhost:9200/_security/role?pretty
```

### 3.2 Create a scoped "owner" role
This example grants full control (create/read/write/delete/manage) over any index prefixed `cid-*`, plus enough cluster access to connect and check health — nothing more.

```bash
curl -X POST --cacert /u01/elasticsearch/config/certs/http_ca.crt \
  -u 'elastic:<password>' \
  https://localhost:9200/_security/role/cid_owner \
  -H "Content-Type: application/json" -d '
{
  "cluster": ["monitor"],
  "indices": [
    {
      "names": ["cid-*"],
      "privileges": ["all"]
    }
  ]
}'
```

### 3.3 Create the user and attach the role
```bash
curl -X POST --cacert /u01/elasticsearch/config/certs/http_ca.crt \
  -u 'elastic:<password>' \
  https://localhost:9200/_security/user/cid_user \
  -H "Content-Type: application/json" -d '
{
  "password": "<set-a-strong-password>",
  "roles": ["cid_owner"],
  "full_name": "CID Service User"
}'
```

### 3.4 Verify
```bash
curl --cacert /u01/elasticsearch/config/certs/http_ca.crt \
  -u 'elastic:<password>' \
  https://localhost:9200/_security/user/cid_user?pretty
```

### 3.5 Test as the new user
```bash
# Cluster connectivity
curl --cacert /u01/elasticsearch/config/certs/http_ca.crt \
  -u 'cid_user:<password>' \
  https://localhost:9200/_cluster/health?pretty

# Create an index inside their scope (should succeed)
curl --cacert /u01/elasticsearch/config/certs/http_ca.crt \
  -u 'cid_user:<password>' \
  -X PUT https://localhost:9200/cid-test-index

# Try an index outside their scope (should fail with 403)
curl --cacert /u01/elasticsearch/config/certs/http_ca.crt \
  -u 'cid_user:<password>' \
  -X PUT https://localhost:9200/other-team-index
```

---

## 6. Granting Kibana Access

Index-level roles (like `cid_owner`) only control **data** access. To let a user log into Kibana, they also need a **Kibana application privilege**.

### Option A — Full Kibana access (simplest)
Attach the built-in `kibana_admin` role alongside the data role:

```bash
curl -X PUT --cacert /u01/elasticsearch/config/certs/http_ca.crt \
  -u 'elastic:<password>' \
  https://localhost:9200/_security/user/cid_user \
  -H "Content-Type: application/json" -d '
{
  "roles": ["cid_owner", "kibana_admin"]
}'
```
> `kibana_admin` gives access to **every** Kibana feature (Discover, Dashboards, Dev Tools, Fleet, ML, etc.) across all spaces. Their actual **data** is still limited to `cid-*` by `cid_owner`, but they can see/manage Kibana saved objects belonging to other users too.

### Option B — Scoped Kibana access (recommended if you want to limit the UI surface)
Build a custom role combining data privileges and only the specific Kibana features they need:

```bash
curl -X PUT --cacert /u01/elasticsearch/config/certs/http_ca.crt \
  -u 'elastic:<password>' \
  https://localhost:9200/_security/role/cid_kibana_access \
  -H "Content-Type: application/json" -d '
{
  "cluster": ["monitor"],
  "indices": [
    {
      "names": ["cid-*"],
      "privileges": ["all"]
    }
  ],
  "applications": [
    {
      "application": "kibana-.kibana",
      "privileges": ["feature_discover.all", "feature_dev_tools.all"],
      "resources": ["*"]
    }
  ]
}'
```
Then assign it in place of the two separate roles:
```bash
curl -X PUT --cacert /u01/elasticsearch/config/certs/http_ca.crt \
  -u 'elastic:<password>' \
  https://localhost:9200/_security/user/cid_user \
  -H "Content-Type: application/json" -d '
{
  "roles": ["cid_kibana_access"]
}'
```

---

## 7. Deleting a User

```bash
curl -X DELETE --cacert /u01/elasticsearch/config/certs/http_ca.crt \
  -u 'elastic:<password>' \
  https://localhost:9200/_security/user/cid_user
```
Expected: `{"found":true}`

**Verify removal:**
```bash
curl --cacert /u01/elasticsearch/config/certs/http_ca.crt \
  -u 'elastic:<password>' \
  https://localhost:9200/_security/user/cid_user?pretty
```
Should return `404`.

> Deleting a user does **not** delete its role. If the role (e.g. `cid_owner`) won't be reused, remove it separately:
> ```bash
> curl -X DELETE --cacert /u01/elasticsearch/config/certs/http_ca.crt \
>   -u 'elastic:<password>' \
>   https://localhost:9200/_security/role/cid_owner
> ```

---

## 8. Sharing Connection Details with Developers

Never share the `elastic` superuser. Give developers a named, scoped account instead.

### Connection Details Template
```
Host              : https://10.1.184.116:9200
Protocol          : HTTPS (TLS required)
Elasticsearch ver.: 9.5.2
Cluster name      : my-cluster
Username          : cid_user
Password          : <deliver via password manager/vault — not chat or email>
CA Certificate    : http_ca.crt (send as a separate attachment)
Index scope       : cid-* (their account can only create/manage indices matching this prefix)
```

### Getting them the CA certificate
```bash
scp /u01/elasticsearch/config/certs/http_ca.crt user@devmachine:/path/
```
Or share the fingerprint for out-of-band verification:
```bash
openssl x509 -fingerprint -sha256 -noout -in /u01/elasticsearch/config/certs/http_ca.crt
```

### Example client snippets to hand off

**curl**
```bash
curl --cacert http_ca.crt -u cid_user:<password> https://10.1.184.116:9200/_cluster/health?pretty
```

**Python (`elasticsearch-py`)**
```python
from elasticsearch import Elasticsearch

es = Elasticsearch(
    "https://10.1.184.116:9200",
    basic_auth=("cid_user", "<password>"),
    ca_certs="/path/to/http_ca.crt"
)
```

**Node.js (`@elastic/elasticsearch`)**
```javascript
const { Client } = require('@elastic/elasticsearch')
const fs = require('fs')

const client = new Client({
  node: 'https://10.1.184.116:9200',
  auth: { username: 'cid_user', password: '<password>' },
  tls: { ca: fs.readFileSync('/path/to/http_ca.crt') }
})
```

---

## 9. Security Best Practices

- ✅ **Never share the `elastic` superuser** — it has unrestricted access and no per-user accountability.
- ✅ **One named account per developer or service**, scoped to an index-name pattern they own (e.g. `cid-*`).
- ✅ **Deliver passwords via a password manager or vault**, never plaintext chat/email.
- ✅ **Rotate the `elastic` password** if it was ever typed into a chat, ticket, or shared document.
  ```bash
  sudo /u01/elasticsearch/es_home_952/bin/elasticsearch-reset-password -u elastic -i
  ```
- ✅ **Restrict network exposure** — put ES behind a firewall/VPN/reverse proxy rather than exposing `9200` openly; only allow known developer IP ranges if possible.
- ✅ **Avoid `"names": ["*"]`** in custom roles unless a user genuinely needs ownership over every index — narrow patterns limit blast radius if credentials are ever compromised.
- ✅ **Enable audit logging** once multiple people have access:
  ```yaml
  xpack.security.audit.enabled: true
  ```

> ⚠️ **Action needed:** The `elastic` password used throughout this setup (`hPCAi4rrxi=O2+XamSgI`) has appeared in this chat multiple times and should be treated as compromised. Rotate it before handing off any access to developers.

---

## 10. Troubleshooting Quick Reference

| Symptom | Cause | Fix |
|---|---|---|
| `unknown setting [path.conf]` on start | `-Epath.conf=` used as a CLI flag | Set config path via `ES_PATH_CONF` environment variable instead |
| `systemd: start operation timed out` | `Type=notify` unit waited too long on first-boot setup | Add `TimeoutStartSec=180` (or use `Type=simple` + `TimeoutStartSec=0`) |
| `vm.max_map_count [65530] is too low` | sysctl setting not applied/persisted | `sudo sysctl -p` after adding to `/etc/sysctl.conf`; restart service |
| PID file write fails | `PID_DIR` points to a path not auto-created by systemd | Use `/run/elasticsearch` (auto-created via `RuntimeDirectory=elasticsearch`) instead of a custom `/u01/...` path |
| `ERROR: u is not a recognized option` (`elasticsearch-users`) | Wrong tool — `elastic` is a reserved-realm user, not a file-realm user | Use the `_security` REST API instead: `GET /_security/user/elastic` |
| Clean shutdown logged as "failed" | Missing `SuccessExitStatus=143` | Add `SuccessExitStatus=143` to the systemd unit |

**Useful commands:**
```bash
sudo systemctl status elasticsearch
sudo journalctl -u elasticsearch -f
tail -f /u01/elasticsearch/logs/*.log
```

---

## 11. Appendix: Full Command Log

This is the exact sequence used to reset the `elastic` password and set up the `cid_owner` role / `ciduser` / `cid_user` accounts on the second server (`TAH164163`). Kept here as a reference for repeating the same setup elsewhere.

> 🔒 **`<password>` placeholders below stand in for the real value.** The actual `elastic` password used while running these commands was pasted into this chat multiple times in plaintext and must be treated as **compromised** — see the warning in Section 9. Do not copy the old value into a new server; generate a fresh one with Section 3 instead.

```bash
# Reset the elastic password interactively (custom password, not auto-generated)
sudo /u01/elasticsearch/es_home_952/bin/elasticsearch-reset-password -u elastic -i

# Confirm the elastic user's own record
curl --cacert /u01/elasticsearch/config/certs/http_ca.crt \
  -u 'elastic:<password>' \
  https://localhost:9200/_security/user/elastic?pretty

# Confirm current authentication context
curl --cacert /u01/elasticsearch/config/certs/http_ca.crt \
  -u 'elastic:<password>' \
  https://localhost:9200/_security/_authenticate?pretty

# List all roles on this cluster
curl --cacert /u01/elasticsearch/config/certs/http_ca.crt \
  -u 'elastic:<password>' \
  https://localhost:9200/_security/role?pretty

# Attempt to update a user that doesn't exist yet -- fails, password required for creation
curl -X PUT --cacert /u01/elasticsearch/config/certs/http_ca.crt \
  -u 'elastic:<password>' \
  https://localhost:9200/_security/user/ciduser \
  -H "Content-Type: application/json" -d '
{
  "roles": ["cid_owner", "kibana_admin"]
}'
# -> 400 validation_exception: "password must be specified unless you are updating an existing user"

# Create the cid_owner role (scoped to cid-* indices, monitor-only cluster access)
curl -X POST --cacert /u01/elasticsearch/config/certs/http_ca.crt \
  -u 'elastic:<password>' \
  https://localhost:9200/_security/role/cid_owner \
  -H "Content-Type: application/json" -d '
{
  "cluster": ["monitor"],
  "indices": [
    {
      "names": ["cid-*"],
      "privileges": ["all"]
    }
  ]
}'

# Create cid_user with password included, plus cid_owner + kibana_admin roles
curl -X POST --cacert /u01/elasticsearch/config/certs/http_ca.crt \
  -u 'elastic:<password>' \
  https://localhost:9200/_security/user/cid_user \
  -H "Content-Type: application/json" -d '
{
  "password": "<set-a-fresh-strong-password>",
  "roles": ["cid_owner", "kibana_admin"],
  "full_name": "CID Service User"
}'

# Verify the user was created with the expected roles
curl --cacert /u01/elasticsearch/config/certs/http_ca.crt \
  -u 'elastic:<password>' \
  https://localhost:9200/_security/user/cid_user?pretty

# Delete the user when no longer needed
curl -X DELETE --cacert /u01/elasticsearch/config/certs/http_ca.crt \
  -u 'elastic:<password>' \
  https://localhost:9200/_security/user/cid_user
```

### Key lesson from this sequence
`PUT /_security/user/<name>` is a combined create-or-update endpoint:
- **Creating** a new user → `password` is **required**.
- **Updating** an existing user (e.g. just changing roles) → `password` may be omitted.

Also note: **roles and users are per-cluster**, not shared across servers. Anything created on `TAH184116` (the first server) does not automatically exist on `TAH164163` (the second) — each new node needs its own `cid_owner` role and `cid_user` account created independently, following the same commands above.

---
*End of manual — Elasticsearch 9.5.2 on Oracle Linux 9.8, install path `/u01/elasticsearch`.*
