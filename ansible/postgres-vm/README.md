# LAN Postgres VM

Provisions PostgreSQL 16 on a Debian/Ubuntu VM on the LAN — the database
behind [`applications/herd-scheduler`](../../applications/herd-scheduler/README.md).
It lives outside the cluster on purpose: poll data survives k3s rebuilds, and
pods reach it directly over the LAN via `DATABASE_URL` (no in-cluster DB, no
pooler).

What the playbook does (idempotent):

1. Installs `postgresql-16` + client and enables the service.
2. Sets `listen_addresses` (default `*`) and `password_encryption =
   scram-sha-256` (restarts once when changed).
3. Creates the `herd` role and the `scheduler` database owned by it.
4. Adds a `pg_hba` rule allowing `herd` → `scheduler` from the LAN CIDR
   (default `192.168.1.0/24`) with scram auth. Nothing else is admitted
   remotely.
5. Optionally (`-e manage_ufw=true`) opens 5432/tcp from that CIDR in UFW.

## Run it

```sh
cd ansible/postgres-vm
ansible-galaxy collection install -r requirements.yml
cp inventory.example.ini inventory.ini   # set the VM IP + SSH user
ansible-playbook -i inventory.ini playbook.yml -e db_password='<16+ chars>'
```

The password is never written to the repo — pass it with `-e` (as above) or
an Ansible Vault file. Override defaults the same way: `postgres_version`,
`db_name`, `db_user`, `lan_cidr`, `listen_addresses`.

## Verify + wire into the cluster

```sh
# from a k3s node (or any LAN host):
psql 'postgresql://herd:<password>@<vm-ip>:5432/scheduler' -c 'select 1'
```

Then store the same URL in Infisical as `herd-scheduler-database-url` — the
app's ExternalSecret turns it into `DATABASE_URL`, and the migrate Job
populates the schema on the next sync (`prisma migrate deploy`).

## Not covered (deliberately)

- **Backups.** Set up at minimum a nightly `pg_dump` cron on the VM, e.g.
  `pg_dump -Fc scheduler > /var/backups/scheduler-$(date +%F).dump`, with
  off-VM copies.
- VM creation itself (Proxmox/cloud-init/etc.) and SSH bootstrap — the
  playbook assumes a reachable Debian/Ubuntu host with sudo.
