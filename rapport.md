# Rapport d'État des Lieux - Projets Cinephoria

**Date :** 2 décembre 2025  
**Auteur :** Roo (Assistant IA)  
**Version :** 1.0

## Table des matières

1. [Introduction](#introduction)
2. [Méthodologie](#méthodologie)
3. [État des lieux par environnement](#état-des-lieux-par-environnement)
   - [3.1 Environnement de développement local](#31-environnement-de-développement-local)
   - [3.2 Environnement de staging](#32-environnement-de-staging)
   - [3.3 Environnement de production](#33-environnement-de-production)
4. [Analyse comparative backend vs web](#analyse-comparative-backend-vs-web)
5. [Évaluation de la gestion de la sécurité](#évaluation-de-la-gestion-de-la-sécurité)
6. [Évaluation de la gestion des images Docker](#évaluation-de-la-gestion-des-images-docker)
7. [Écarts identifiés et recommandations](#écarts-identifiés-et-recommandations)
8. [Conclusion](#conclusion)

## Introduction

Ce rapport présente un état des lieux complet des projets **CinephoriaBackEnd** (API .NET 8) et **Cinephoria-web** (frontend Angular) à travers leurs trois environnements : développement local, staging et production. L'analyse couvre également la gestion de la sécurité et des images Docker, avec des propositions d'amélioration.

## Méthodologie

L'analyse a été réalisée par examen des fichiers de configuration, des workflows CI/CD, des Dockerfiles et de la documentation existante. Les outils utilisés incluent la lecture de fichiers, la recherche de patterns et l'évaluation des bonnes pratiques.

## État des lieux par environnement

### 3.1 Environnement de développement local

**Backend (CinephoriaBackEnd)**
- **Technologie :** .NET 8, ASP.NET Core
- **Base de données :** PostgreSQL (conteneur Docker) + MongoDB (conteneur Docker)
- **Configuration :** `appsettings.Development.json` avec secrets en clair (à migrer vers Vault)
- **Démarrage :** Docker Compose (via `docker-compose.yml`) ou via IDE (Visual Studio)
- **Ports :** 5000 (backend), 5432 (PostgreSQL), 27017 (MongoDB), 8200 (Vault)
- **Sécurité :** HTTPS avec certificat auto-signé, CORS permissif (`AllowAnyOrigin`)

**Frontend (Cinephoria-web)**
- **Technologie :** Angular 19, Node.js 18
- **Configuration :** `environment.ts` avec API URL `https://localhost:5048/api`
- **Démarrage :** `ng serve` ou conteneur Docker avec Nginx
- **Port :** 4200 (dev) ou 80 (Docker)
- **Build :** Configurations multiples (development, staging, production, aws)

**Points forts :**
- Environnement containerisé cohérent
- Intégration de Vault pour la gestion des secrets
- Health checks et monitoring de base

**Points faibles :**
- Secrets encore présents en clair dans certains fichiers
- CORS trop permissif en développement
- Absence de tests automatisés locaux

### 3.2 Environnement de staging

**Infrastructure AWS (Terraform)**
- **EC2 :** Instance t3.micro avec Amazon Linux 2023
- **S3 :** Buckets `cinephoria-frontend-staging` (frontend statique)
- **CloudFront :** Distribution CDN pour le frontend (optionnelle)
- **Route53 :** Sous-domaine `staging-app.cinephoria.eu` et `staging-api.cinephoria.eu`
- **ACM :** Certificat SSL wildcard pour `*.cinephoria.eu`

**Déploiement CI/CD**
- **Workflow GitHub Actions :** Déclenché sur branche `develop`
- **Authentification :** OIDC AWS (rôle IAM `github-actions-frontend-role` / `github-actions-backend-role`)
- **Backend :** Build Docker → Push GHCR → Déploiement EC2 via SSM
- **Frontend :** Build Angular → Déploiement S3 → Invalidation CloudFront

**Configuration applicative**
- **Backend :** Variables d'environnement injectées via Docker Compose
- **Frontend :** Build avec configuration `staging` (`environment.staging.ts`)

### 3.3 Environnement de production

**Similaire au staging avec différences :**
- **Branche :** `main` ou tags `v*`
- **URLs :** `www.cinephoria.eu` (frontend), `api.cinephoria.eu` (backend)
- **S3 Bucket :** `cinephoria-frontend-prod`
- **Ports backend :** 5000 (production) vs 5001 (staging)
- **Base de données :** Séparée (suffixe `_Prod`)

**Sécurité renforcée :**
- Security groups restrictifs (à vérifier)
- Monitoring CloudWatch avec alertes
- Backup automatique des bases de données (à implémenter)

## Analyse comparative backend vs web

| Aspect | Backend | Frontend |
|--------|---------|----------|
| **Langage** | C# (.NET 8) | TypeScript (Angular 19) |
| **Conteneurisation** | Multi-stage Dockerfile .NET | Multi-stage Dockerfile Node.js + Nginx |
| **CI/CD** | Workflow GitHub Actions dédié | Workflow GitHub Actions dédié |
| **Déploiement** | EC2 + Docker Compose | S3 + CloudFront |
| **Configuration** | AppSettings + Vault | Environment files (par build) |
| **Sécurité** | JWT, Identity, Vault | Headers sécurité Nginx, CSP |
| **Monitoring** | Health endpoints, logs | Health check Nginx, logs CloudFront |

**Écarts notables :**
1. **Gestion des secrets :** Backend utilise Vault, frontend utilise des variables d'environnement build-time
2. **Stockage des configurations :** Backend a plusieurs `appsettings.*.json`, frontend a des `environment.*.ts`
3. **Stratégie de déploiement :** Backend déployé sur EC2, frontend sur S3 statique
4. **Résilience :** Backend scalable manuellement, frontend via CDN

## Évaluation de la gestion de la sécurité

**Points positifs :**
- ✅ Intégration de HashiCorp Vault pour les secrets backend
- ✅ Certificats SSL via ACM (production/staging)
- ✅ Politique de mots de passe robuste (Identity)
- ✅ Headers de sécurité Nginx (CSP, X-Frame-Options, etc.)
- ✅ Authentification OIDC pour GitHub Actions (pas de credentials statiques)
- ✅ Bases de données en conteneurs isolés

**Points à améliorer :**
- ⚠️ **Secrets en clair** dans `appsettings.json` (ex: mots de passe PostgreSQL)
- ⚠️ **CORS trop permissif** (`AllowAnyOrigin`) en développement
- ⚠️ **Security group EC2** trop ouvert (SSH depuis 0.0.0.0/0)
- ⚠️ **Absence de scanning de vulnérabilités** dans les images Docker
- ⚠️ **Pas de rotation automatique** des secrets JWT
- ⚠️ **Logs sensibles** potentiellement exposés

## Évaluation de la gestion des images Docker

**Backend Dockerfile :**
- ✅ Multi-stage build optimisé
- ✅ Utilisation d'images officielles .NET 8
- ✅ Running as non-root user (`app`)
- ✅ Health check intégré
- ⚠️ **Tailles d'image** non optimisées (pas de .NET trimming)
- ⚠️ **Couches de cache** non optimisées pour CI

**Frontend Dockerfile :**
- ✅ Multi-stage build (Node.js + Nginx)
- ✅ Utilisation d'images Alpine légères
- ✅ Health check avec curl
- ✅ Configuration Nginx sécurisée
- ⚠️ **Build context** inclut tout le projet (lourd)
- ⚠️ **Pas de serveur de développement** dans le conteneur (volontaire)

**Docker Compose (développement) :**
- ✅ Services interconnectés (backend, frontend, bases de données, Vault)
- ✅ Health checks et dépendances
- ✅ Volumes persistants pour les données
- ⚠️ **Version de Compose** non spécifiée
- ⚠️ **Variables d'environnement** en clair dans le fichier

## Écarts identifiés et recommandations

### 1. Sécurité des secrets
**Écart :** Secrets en clair dans `appsettings.json` et `docker-compose.yml`
**Recommandation :**
- Compléter la migration vers Vault pour tous les secrets
- Utiliser `appsettings.Development.json` sans secrets (valeurs factices)
- Injecter les secrets via variables d'environnement ou Vault Provider
- **Priorité :** Haute

### 2. Configuration CORS
**Écart :** Politique `AllowAnyOrigin` en développement
**Recommandation :**
- Définir des origines spécifiques dans `CorsOption`
- Utiliser des configurations différentes par environnement
- **Priorité :** Moyenne

### 3. Hardening des security groups
**Écart :** SSH ouvert à 0.0.0.0/0, ports backend exposés largement
**Recommandation :**
- Restreindre SSH à une IP spécifique ou utiliser SSM Session Manager
- Limiter les ports backend aux IPs du load balancer/CloudFront
- **Priorité :** Haute

### 4. Scanning de vulnérabilités Docker
**Écart :** Absence de scanning dans le pipeline CI
**Recommandation :**
- Ajouter Trivy ou Docker Scout dans les workflows GitHub Actions
- Rejeter les images avec des vulnérabilités critiques
- **Priorité :** Moyenne

### 5. Optimisation des images Docker
**Écart :** Images backend volumineuses, couches de cache non optimisées
**Recommandation :**
- Utiliser `.dockerignore` pour exclure les fichiers inutiles
- Implémenter le trimming .NET pour réduire la taille
- Utiliser BuildKit cache mounts pour accélérer les builds
- **Priorité :** Basse

### 6. Monitoring et alerting
**Écart :** Monitoring basique, pas d'alertes sur les métriques applicatives
**Recommandation :**
- Configurer des dashboards CloudWatch pour les métriques custom
- Ajouter des alertes sur le taux d'erreur HTTP, latence, utilisation CPU
- Intégrer avec Slack/Email pour les notifications
- **Priorité :** Moyenne

### 7. Backup et reprise
**Écart :** Pas de stratégie de backup automatisée des bases de données
**Recommandation :**
- Mettre en place des snapshots EBS ou backups PostgreSQL/MongoDB
- Tester la restauration régulièrement
- **Priorité :** Haute

### 8. Documentation opérationnelle
**Écart :** Documentation dispersée, pas de runbook d'urgence
**Recommandation :**
- Centraliser la documentation dans un wiki ou README opérationnel
- Créer des runbooks pour les incidents courants (downtime, corruption données)
- **Priorité :** Moyenne

## Conclusion

Les projets Cinephoria présentent une architecture moderne et bien structurée, avec une séparation claire entre backend et frontend, et une bonne base pour le CI/CD. La gestion de la sécurité a été initiée avec Vault et des pratiques raisonnables, mais des améliorations sont nécessaires notamment sur la protection des secrets résiduels et le hardening réseau.

Les environnements staging et production sont bien définis via Terraform, avec une approche low-cost efficace. La gestion des images Docker suit les bonnes pratiques de base mais pourrait être optimisée.

**Recommandations prioritaires :**
1. Éliminer tous les secrets en clair via la migration complète vers Vault
2. Restreindre les security groups AWS
3. Mettre en place une stratégie de backup des bases de données
4. Ajouter du scanning de vulnérabilités dans le pipeline CI

Ces améliorations renforceront la sécurité, la résilience et la maintenabilité de la plateforme Cinephoria.

---

**Annexes :**
- [Documentation sécurité immédiate](Memory-Bank/Documentation-Securite-Immediate.md)
- [Plan CI/CD GitHub Actions](CinephoriaInfra/DocumentationPhaseDeploimentTerraFormAws/Phase3/Plan-CI-CD-GitHub-Actions.md)
- [Guide configuration secrets](CinephoriaInfra/DocumentationPhaseDeploimentTerraFormAws/Phase3/GUIDE-CONFIGURATION-SECRETS.md)