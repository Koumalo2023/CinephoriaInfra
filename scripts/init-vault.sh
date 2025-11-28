#!/bin/bash

# Script d'initialisation de HashiCorp Vault pour Cinephoria
# Ce script configure les secrets et politiques nécessaires au démarrage

set -e

# Attendre que Vault soit prêt
echo "En attente du démarrage de Vault..."
sleep 10

# Exporter les variables d'environnement
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='cinephoria-vault-root-token'

# Vérifier que Vault est opérationnel
until vault status > /dev/null 2>&1; do
    echo "Vault n'est pas encore prêt, nouvelle tentative dans 5 secondes..."
    sleep 5
done

echo "Vault est opérationnel, configuration des secrets..."

# Activer le moteur de secrets KV v2
vault secrets enable -path=secret kv-v2

# Configurer les secrets JWT
vault kv put secret/cinephoria/jwt \
    secret="POdkfoitofoip32094u3247GREDSADAFi23o487kdjkjfh" \
    issuer="https://localhost:5048" \
    audience="https://localhost:4200" \
    lifespan="7"

# Configurer les secrets de base de données PostgreSQL
vault kv put secret/cinephoria/database/postgres \
    host="postgres" \
    port="5432" \
    database="CinephoriaDB" \
    username="cinephoria_user" \
    password="cinephoria_password"

# Configurer les secrets MongoDB
vault kv put secret/cinephoria/database/mongodb \
    connection_string="mongodb://mongodb:27017" \
    database_name="CinephoriaDashboardDB"

# Configurer les secrets SMTP
vault kv put secret/cinephoria/smtp \
    server="smtp.gmail.com" \
    port="587" \
    username="patricesimo.dev@gmail.com" \
    password="llgdglbopnwtznlm" \
    enable_ssl="true"

# Créer une politique pour l'application Cinephoria
vault policy write cinephoria-app - <<EOF
path "secret/data/cinephoria/*" {
  capabilities = ["read"]
}

path "secret/metadata/cinephoria/*" {
  capabilities = ["list"]
}
EOF

# Créer un token pour l'application
APP_TOKEN=$(vault token create -policy=cinephoria-app -format=json | jq -r '.auth.client_token')

echo "Configuration Vault terminée avec succès!"
echo "Token d'application: $APP_TOKEN"
echo "Vault UI disponible sur: http://localhost:8200"
