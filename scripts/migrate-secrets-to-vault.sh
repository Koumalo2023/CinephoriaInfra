#!/bin/bash

# Script de migration des secrets vers Vault
set -e

echo "Migration des secrets vers Vault..."

# Variables Vault
VAULT_ADDR="http://localhost:8200"
VAULT_TOKEN="cinephoria-vault-root-token"

# Exporter les variables pour Vault CLI
export VAULT_ADDR
export VAULT_TOKEN

# Attendre que Vault soit prêt
echo "En attente du démarrage de Vault..."
sleep 10

# Vérifier que Vault est accessible
until vault status > /dev/null 2>&1; do
    echo "Vault n'est pas encore prêt, nouvelle tentative dans 5 secondes..."
    sleep 5
done

echo "Vault est opérationnel, début de la migration..."

# Migrer les secrets JWT
echo "Migration des secrets JWT..."
vault kv put secret/cinephoria/jwt \
  secret="POdkfoitofoip32094u3247GREDSADAFi23o487kdjkjfh" \
  issuer="https://localhost:5048" \
  audience="https://localhost:4200" \
  lifespan="7"

# Migrer les secrets PostgreSQL
echo "Migration des secrets PostgreSQL..."
vault kv put secret/cinephoria/database/postgres \
  connection_string="Host=localhost;Port=5432;Database=CinephoriaDB_Dev;Username=devUser;Password=Tefong006;Include Error Detail=true"

# Migrer les secrets MongoDB  
echo "Migration des secrets MongoDB..."
vault kv put secret/cinephoria/database/mongodb \
  connection_string="mongodb://localhost:27017" \
  database_name="CinephoriaDashboardDB_Dev"

# Migrer les secrets SMTP
echo "Migration des secrets SMTP..."
vault kv put secret/cinephoria/smtp \
  server="smtp.gmail.com" \
  port="587" \
  username="patricesimo.dev@gmail.com" \
  password="llgdglbopnwtznlm" \
  enable_ssl="true"

# Migrer les secrets TMDb
echo "Migration des secrets TMDb..."
vault kv put secret/cinephoria/tmdb \
  api_key="4dae810d0b1588c567f6d6242c1da244"

echo "Migration terminée avec succès!"
echo ""
echo "Vérification des secrets migrés:"
echo "================================="
vault kv list secret/cinephoria