# --- Data Sources ---
# Read the pre-existing external traefik-net network
data "docker_network" "traefik_net" {
  name = "traefik-net"
}

# --- Networks ---
# Define the internal overlay network for app-db communication.
# We set attachable = true to allow temporary backup containers to run against it.
resource "docker_network" "freshrss_net" {
  name       = "${var.stack_name}_freshrss-net"
  driver     = "overlay"
  attachable = false

  labels {
    label = "com.docker.stack.namespace"
    value = var.stack_name
  }

  lifecycle {
    ignore_changes = [
      labels,
      options
    ]
  }
}

# --- Volumes ---
# Define the volumes for persisting data, matching the active stack naming
resource "docker_volume" "freshrss_data" {
  name = "${var.stack_name}_freshrss-data"
  labels {
    label = "com.docker.stack.namespace"
    value = var.stack_name
  }
}

resource "docker_volume" "freshrss_db" {
  name = "${var.stack_name}_freshrss-db"
  labels {
    label = "com.docker.stack.namespace"
    value = var.stack_name
  }
}

# --- Secrets ---
# Define the database password secret with a dynamic name based on the content hash
resource "docker_secret" "db_password" {
  name = "freshrss_db_password_${substr(sha256(var.postgres_password), 0, 8)}"
  data = base64encode(var.postgres_password)

  lifecycle {
    create_before_destroy = true
  }
}

# --- Services ---

# 1. PostgreSQL Database Service
resource "docker_service" "db" {
  name = "${var.stack_name}_db"

  task_spec {
    container_spec {
      image = var.postgres_image

      env = {
        POSTGRES_DB            = var.postgres_db
        POSTGRES_USER          = var.postgres_user
        POSTGRES_PASSWORD_FILE = "/run/secrets/freshrss_db_password"
        TZ                     = var.timezone
      }

      secrets {
        secret_id   = docker_secret.db_password.id
        secret_name = docker_secret.db_password.name
        file_name   = "/run/secrets/freshrss_db_password"
      }

      mounts {
        target = "/var/lib/postgresql/data"
        source = docker_volume.freshrss_db.name
        type   = "volume"
        volume_options {
          labels {
            label = "com.docker.stack.namespace"
            value = var.stack_name
          }
        }
      }

      labels {
        label = "com.docker.stack.namespace"
        value = var.stack_name
      }
    }

    placement {
      constraints = [
        "node.role == manager"
      ]
    }

    networks_advanced {
      id      = docker_network.freshrss_net.id
      aliases = ["db"]
    }
  }

  labels {
    label = "com.docker.stack.namespace"
    value = var.stack_name
  }

  lifecycle {
    ignore_changes = [
      task_spec[0].networks_advanced
    ]
  }
}

# 2. FreshRSS Application Service
resource "docker_service" "app" {
  name = "${var.stack_name}_app"

  task_spec {
    container_spec {
      image = var.freshrss_image

      command = [
        "/bin/sh",
        "-c",
        "for var in $(env | grep '^FILE__'); do val_path=\"$${var#*=}\"; var_name=\"$${var%%=*}\"; var_name=\"$${var_name#FILE__}\"; if [ -f \"$val_path\" ]; then export \"$var_name\"=\"$(cat \"$val_path\")\"; fi; done && exec ./Docker/entrypoint.sh \"$0\" \"$@\""
      ]

      args = [
        "/bin/bash",
        "-o",
        "pipefail",
        "-c",
        "([ -z \"$CRON_MIN\" ] || cron) && . /etc/apache2/envvars && exec apache2 -D FOREGROUND $([ -n \"$OIDC_ENABLED\" ] && [ \"$OIDC_ENABLED\" -ne 0 ] && echo \"-D OIDC_ENABLED\")"
      ]

      env = {
        TZ                = var.timezone
        DB_TYPE           = "pgsql"
        DB_HOST           = "${var.stack_name}_db"
        DB_PORT           = "5432"
        DB_NAME           = var.postgres_db
        DB_USER           = var.postgres_user
        FILE__DB_PASSWORD = "/run/secrets/freshrss_db_password"
        CRON_MIN          = "*/15"
      }

      secrets {
        secret_id   = docker_secret.db_password.id
        secret_name = docker_secret.db_password.name
        file_name   = "/run/secrets/freshrss_db_password"
      }

      mounts {
        target = "/var/www/FreshRSS/data"
        source = docker_volume.freshrss_data.name
        type   = "volume"
        volume_options {
          labels {
            label = "com.docker.stack.namespace"
            value = var.stack_name
          }
        }
      }

      labels {
        label = "com.docker.stack.namespace"
        value = var.stack_name
      }
    }

    placement {
      constraints = [
        "node.role == manager"
      ]
    }

    networks_advanced {
      id      = data.docker_network.traefik_net.id
      aliases = ["app"]
    }

    networks_advanced {
      id      = docker_network.freshrss_net.id
      aliases = ["app"]
    }
  }

  labels {
    label = "com.docker.stack.namespace"
    value = var.stack_name
  }

  lifecycle {
    ignore_changes = [
      task_spec[0].networks_advanced
    ]
  }

  # Traefik routing rules are defined as Swarm service labels
  labels {
    label = "traefik.enable"
    value = "true"
  }
  labels {
    label = "traefik.swarm.network"
    value = "traefik-net"
  }
  labels {
    label = "traefik.http.routers.freshrss.rule"
    value = "Host(`rss.trelvik.net`)"
  }
  labels {
    label = "traefik.http.routers.freshrss.entrypoints"
    value = "https"
  }
  labels {
    label = "traefik.http.routers.freshrss.tls"
    value = "true"
  }
  labels {
    label = "traefik.http.routers.freshrss.tls.certresolver"
    value = "myresolver"
  }
  labels {
    label = "traefik.http.services.freshrss.loadbalancer.server.port"
    value = "80"
  }
  labels {
    label = "traefik.http.services.freshrss.loadbalancer.passhostheader"
    value = "true"
  }
}
