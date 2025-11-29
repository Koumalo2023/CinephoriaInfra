# Gestion des États Terraform pour Multi-Environnements

## 📋 Question: Un seul bucket S3 suffit-il pour staging et production ?

**RÉPONSE: OUI, absolument !** Un seul bucket S3 peut gérer plusieurs environnements en utilisant des clés (keys) différentes.

## 🏗️ Architecture recommandée

### Structure du bucket S3
```
cinephoria-terraform-state/
├── production/
│   └── infrastructure.tfstate
└── staging/
    └── infrastructure.tfstate
```

### Avantages d'un seul bucket
- **Centralisation** : Tous les états au même endroit
- **Économie** : Un seul bucket à gérer
- **Sécurité** : Une seule politique de sécurité à maintenir
- **Simplicité** : Gestion unique des backups et versioning

## 🔧 Configuration recommandée

### Option 1: Utilisation de workspaces Terraform (Recommandée)

**Pour la production:**
```bash
cd CinephoriaInfra
terraform workspace new production
terraform init
terraform apply
```

**Pour le staging:**
```bash
cd CinephoriaInfra  
terraform workspace new staging
terraform init
terraform apply
```

### Option 2: Clés manuelles différentes

**Production:**
```hcl
key = "production/infrastructure.tfstate"
```

**Staging:**
```hcl  
key = "staging/infrastructure.tfstate"
```

## 🚀 Notre configuration actuelle

Nous allons utiliser **l'Option 1 (workspaces)** car c'est la pratique recommandée par HashiCorp.

### Mise à jour de la configuration

Dans [`terraform.tfvars`](CinephoriaInfra/terraform.tfvars:21), nous gardons :
```hcl
key = "cinephoria/terraform.tfstate"
```

Terraform gérera automatiquement les sous-dossiers par workspace :
```
cinephoria-terraform-state/
├── env:production/
│   └── cinephoria/terraform.tfstate
└── env:staging/
    └── cinephoria/terraform.tfstate
```

## 🔄 Processus de déploiement

### Premier déploiement (Production)
```bash
cd CinephoriaInfra
terraform workspace new production
terraform init
terraform plan
terraform apply
```

### Déploiement Staging
```bash
cd CinephoriaInfra
terraform workspace new staging
terraform init
terraform plan
terraform apply
```

### Changer d'environnement
```bash
# Aller en production
terraform workspace select production

# Aller en staging  
terraform workspace select staging

# Voir l'environnement courant
terraform workspace show
```

## 💰 Considérations de coût

- **Coût S3** : Le même (quelques centimes par mois)
- **Stockage** : Deux fichiers d'état au lieu d'un
- **Performance** : Aucun impact

## 🔐 Sécurité

- Même niveau de sécurité pour les deux environnements
- Versioning activé sur tout le bucket
- Accès public bloqué
- Chiffrement SSE-S3

## ✅ Validation

Vérifiez dans votre bucket S3 après déploiement :
- Le dossier `env:production/` existe
- Le dossier `env:staging/` existe  
- Chaque environnement a son propre fichier d'état

## 🎯 Recommandation finale

**Gardez votre bucket unique** - c'est la meilleure pratique pour gérer plusieurs environnements avec Terraform.