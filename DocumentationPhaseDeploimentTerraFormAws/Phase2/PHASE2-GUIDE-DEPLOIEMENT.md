# Phase 2 - Guide de Déploiement de l'Infrastructure

## 📋 Vue d'Ensemble de la Phase 2

Cette phase vous guide pas à pas pour déployer l'infrastructure AWS complète avec Terraform.

## ⚠️ Prérequis Vérifiés

Avant de commencer, assurez-vous d'avoir :

- [ ] **AWS CLI** configuré avec les permissions appropriées
- [ ] **Terraform** 1.0+ installé
- [ ] **Bucket S3** `cinephoria-terraform-state` créé
- [ ] **Fichier** [`terraform.tfvars`](CinephoriaInfra/terraform.tfvars) configuré
- [ ] **Paire de clés SSH** `cinephoria-key-pair` générée dans AWS EC2

## 🚀 Étapes de Déploiement

### Étape 1: Initialiser Terraform

```bash
# Se placer dans le dossier d'infrastructure
cd CinephoriaInfra

# Initialiser Terraform avec le backend S3
terraform init
```

**Ce que fait cette commande:**
- Télécharge le provider AWS
- Configure le backend S3 pour stocker l'état
- Prépare l'environnement Terraform

**Résultat attendu:**
```
Terraform has been successfully initialized!
```

### Étape 2: Vérifier le plan de déploiement

```bash
# Vérifier ce qui va être créé
terraform plan
```

**Ce que fait cette commande:**
- Analyse votre configuration
- Montre toutes les ressources qui seront créées
- Estime les coûts
- **NE crée RIEN** - c'est une simulation

**Points à vérifier:**
- ✅ Environ 15-20 ressources doivent être créées
- ✅ Coût estimé: ~$15-30/mois
- ✅ Aucune erreur dans la configuration

### Étape 3: Déployer l'infrastructure

```bash
# Déployer l'infrastructure
terraform apply
```

**Processus:**
1. Terraform affiche à nouveau le plan
2. Vous devez confirmer en tapant `yes`
3. Le déploiement prend 10-15 minutes
4. Terraform créé toutes les ressources AWS

**Ressources créées:**
- 🖥️ Instance EC2 t3.micro
- 🌐 Buckets S3 (production & staging)
- 📡 Distributions CloudFront
- 🔐 Certificat SSL wildcard
- 🗺️ Zone Route53
- 👁️ Dashboard CloudWatch

### Étape 4: Récupérer les outputs importants

Une fois le déploiement terminé, récupérez les informations cruciales:

```bash
# Afficher toutes les sorties
terraform output

# Ou récupérer des outputs spécifiques
terraform output route53_name_servers
terraform output ec2_public_ip
terraform output cloudfront_prod_url
```

## 🌐 Configuration DNS (CRITIQUE)

### Récupérer les serveurs DNS Route53

```bash
terraform output route53_name_servers
```

Vous obtiendrez 4 serveurs DNS comme:
```
[
  "ns-xxxx.awsdns-xx.net",
  "ns-xxxx.awsdns-xx.co.uk", 
  "ns-xxxx.awsdns-xx.com",
  "ns-xxxx.awsdns-xx.org"
]
```

### Configurer le domaine chez votre registrar

1. **Aller** chez votre registrar (OVH, Gandi, etc.)
2. **Trouver** la section DNS/Nameservers
3. **Remplacer** les serveurs DNS actuels par les 4 serveurs Route53
4. **Sauvegarder** les changements

**⚠️ Important:**
- La propagation DNS peut prendre 24-48 heures
- Pendant ce temps, certains services peuvent ne pas fonctionner
- Les certificats SSL peuvent prendre quelques heures pour être validés

## 🔧 Dépannage Courant

### Erreur: "InvalidKeyPair.NotFound"
```bash
Error: creating EC2 Instance: InvalidKeyPair.NotFound: The key pair 'cinephoria-key-pair' does not exist
```
**Solution:** Vérifiez que la paire de clés existe exactement avec ce nom dans AWS EC2.

### Erreur: "BucketAlreadyExists"
```bash
Error: creating S3 Bucket: BucketAlreadyExists: The requested bucket name is not available
```
**Solution:** Changer le nom du bucket dans `terraform.tfvars` (doit être unique globalement).

### Erreur de permissions AWS
```bash
Error: error configuring Terraform AWS Provider: no valid credential sources found
```
**Solution:** Vérifiez que AWS CLI est configuré avec `aws configure`.

## ✅ Validation du Déploiement

Une fois déployé, testez:

### 1. Instance EC2
```bash
# Se connecter en SSH (après déploiement)
ssh -i cinephoria-key-pair.pem ec2-user@VOTRE_IP_EC2

# Vérifier les services
sudo docker ps
sudo systemctl status nginx
```

### 2. Frontend S3 + CloudFront
- Visitez l'URL CloudFront production
- Visitez l'URL CloudFront staging

### 3. Backend API
- Testez `https://api.cinephoria.eu/health` (après configuration DNS)
- Testez `https://staging-api.cinephoria.eu/health`

## 🔄 Gestion des Workspaces (Multi-Environnements)

### Créer l'environnement production
```bash
terraform workspace new production
terraform apply
```

### Créer l'environnement staging
```bash
terraform workspace new staging
terraform apply
```

### Changer d'environnement
```bash
terraform workspace select production
terraform workspace select staging
```

## 📊 Monitoring

Une fois déployé, vous pouvez:
- **CloudWatch:** Voir les métriques EC2 et CloudFront
- **EC2:** Monitorer l'utilisation CPU et mémoire
- **S3:** Vérifier le stockage et les accès
- **CloudFront:** Analyser le trafic et les performances

## 🆘 Support

Si vous rencontrez des problèmes:
1. Vérifiez les messages d'erreur Terraform
2. Consultez les logs CloudWatch
3. Vérifiez les configurations dans AWS Console
4. Référez-vous à la documentation de la Phase 1

**Prochaine étape:** Phase 3 - Configuration du Backend