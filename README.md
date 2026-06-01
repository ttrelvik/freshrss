# FreshRSS Docker Stack Configuration

This repository contains the configuration files required to deploy and run **[FreshRSS](https://freshrss.org/)**—a self-hosted, lightweight, and customizable RSS feed aggregator—using Docker Swarm.

The deployment features:
- **FreshRSS App** (v1.29.1) containerized service.
- **PostgreSQL 16** containerized database.
- **Traefik Ingress Integration** with automatic TLS configuration (Let's Encrypt).
- **Persistent Storage** using Docker volumes.

---

## 📁 Repository Structure

- [docker-compose.yml](docker-compose.yml): The main configuration file defining the services, networks, volumes, and Traefik routing rules.
- [.env](.env): Environment variables containing local timezone, database credentials, and secrets.

---

## 🛠️ Prerequisites

Before deploying the stack, ensure you have the following ready:
1. **Docker & Docker Swarm** installed and initiated on your host machine:
   ```bash
   docker swarm init
   ```
2. **Traefik Ingress Controller** running on your swarm cluster, listening on an external overlay network named `traefik-net`.
   - If the network does not exist, create it:
     ```bash
     docker network create --driver overlay traefik-net
     ```
3. A **DNS record** pointing `rss.trelvik.net` to your swarm entrypoint.

---

## 🚀 Getting Started & Configuration

### 1. Configure the Environment

Open the [.env](.env) file and adjust the configuration to match your environment:

- **Timezone**: Set `TZ` to your local timezone (e.g. `America/New_York`).
- **PostgreSQL Credentials**: 
  - Change `POSTGRES_DB` and `POSTGRES_USER` if desired.
  - Generate a new, strong database password for `POSTGRES_PASSWORD`. You can run this command to generate a random 32-byte hex string:
    ```bash
    openssl rand -hex 32
    ```

> [!IMPORTANT]
> Keep the `.env` file secure and do not commit database passwords or sensitive credentials to public source control repositories.

### 2. Deploy the Stack

Deploy the stack to your Docker Swarm cluster using the following command:

```bash
docker stack deploy -c docker-compose.yml freshrss
```

### 3. Verify the Deployment

Check the status of the deployed services:

```bash
docker stack services freshrss
```

You can also check the logs for each service using:

```bash
docker service logs freshrss_app
docker service logs freshrss_db
```

Once running, access the FreshRSS web interface at [https://rss.trelvik.net](https://rss.trelvik.net).

---

## ⚙️ Service Specifications

### FreshRSS Application (`app`)
- **Image**: `freshrss/freshrss:1.29.1`
- **Volume**: `freshrss-data` mapped to `/var/www/FreshRSS/data` to persist system state, feeds, configuration, and logs.
- **Routing & TLS**:
  - Traefik routing rule: `Host(\`rss.trelvik.net\`)`
  - TLS enabled with Let's Encrypt using `myresolver`.
  - Swarm internal load balancing to port `80`.
- **Cron Jobs**: Setup to execute automated feed updates every 15 minutes (`CRON_MIN=*/15`).

### PostgreSQL Database (`db`)
- **Image**: `postgres:16`
- **Volume**: `freshrss-db` mapped to `/var/lib/postgresql/data` to persist database records.
- **Environment**: Automatically inherits Postgres username, password, and database name from the `.env` file.

---

## 💾 Maintenance & Backups

### Feed Updates & Cron
FreshRSS is configured with a built-in cron job configured via `CRON_MIN` in the environment block of `docker-compose.yml`. This automatically updates your feeds in the background.

### Database Backups
To perform a backup of the PostgreSQL database, run the following command directly on the Swarm node running the database task:

```bash
docker exec -t $(docker ps -q -f name=freshrss_db) pg_dump -U freshrss_user freshrss > freshrss_backup.sql
```
*(Make sure to replace `freshrss_user` and `freshrss` if you changed them in your `.env` file).*
