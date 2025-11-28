# Configuration de développement pour HashiCorp Vault
storage "file" {
  path = "/vault/data"
}

# Écouteur HTTP pour le développement
listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1
}

# Configuration du mode développement
disable_mlock = true
api_addr = "http://0.0.0.0:8200"
ui = true

# Configuration des politiques de sécurité
default_lease_ttl = "24h"
max_lease_ttl = "72h"