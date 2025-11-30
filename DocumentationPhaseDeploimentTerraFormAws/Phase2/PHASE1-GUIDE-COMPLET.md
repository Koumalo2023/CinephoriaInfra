# Phase 1 - Guide Complet de Préparation

## 📋 Vue d'Ensemble de la Phase 1

Ce guide vous accompagne pas à pas pour compléter les 4 étapes restantes de la Phase 1.

## 🎯 Étapes à Suivre

### Étape 1: Configuration du domaine `cinephoria.eu`

**📋 Actions requises:**
1. Acheter le domaine `cinephoria.eu` chez un registrar (OVH, Gandi, etc.)
2. **ATTENTION:** Ne configurez pas les DNS tout de suite
3. Le domaine sera configuré APRÈS le déploiement Terraform

**🕒 Timing:**
- Achetez le domaine MAINTENANT
- Configurez les DNS APRÈS le déploiement Terraform (Phase 2)

### Étape 2: Création du bucket S3 pour le state Terraform

**📋 Actions dans AWS Console:**
1. Aller dans S3 → "Créer un bucket"
2. **Nom:** `cinephoria-terraform-state` (doit être unique)
3. **Région:** `eu-west-3` (Paris)
4. **Paramètres:**
   - ✅ Bloquer tout accès public
   - ✅ Activer le versioning
   - Chiffrement SSE-S3

**✅ Validation:**
- Le bucket apparaît dans votre liste S3
- Le versioning est activé
- Aucun accès public n'est autorisé

### Étape 3: Génération de la paire de clés SSH

**📋 Actions dans AWS Console:**
1. Aller dans EC2 → "Paires de clés" → "Créer une paire de clés"
2. **Nom:** `cinephoria-key-pair`
3. **Type:** RSA
4. **Format:** `.pem` (Linux/Mac) ou `.ppk` (Windows)

**🔐 Sécurité:**
- Téléchargez et sauvegardez la clé privée
- Sur Linux/Mac: `chmod 400 cinephoria-key-pair.pem`
- **NE PARTAGEZ JAMAIS** la clé privée

### Étape 4: Configuration de `terraform.tfvars`

**📋 Actions dans votre éditeur:**
```bash
cd CinephoriaInfra
cp terraform.tfvars.example terraform.tfvars
```

**Configuration du fichier `terraform.tfvars`:**
```hcl
region = "eu-west-3"
domain_name = "cinephoria.eu"
ec2_instance_type = "t3.micro"
ec2_key_name = "cinephoria-key-pair"  # Exactement le nom de votre paire de clés
postgres_password = "VotreMotDePasseSuperSecurise123!"

tags = {
  Environment = "production"
  Project = "Cinephoria"
  Owner = "VotreNom"
}

# DÉCOMMENTER et configurer:
terraform {
  backend "s3" {
    bucket = "cinephoria-terraform-state"  # Votre bucket
    key    = "cinephoria/infrastructure.tfstate"
    region = "eu-west-3"
  }
}
```

**⚠️ Sécurité importante:**
- **NE COMMITTEZ JAMAIS** `terraform.tfvars` dans Git
- Ajoutez à `.gitignore`: `terraform.tfvars` et `*.tfvars`

## 🚀 Checklist de Validation

Avant de passer à la Phase 2, vérifiez:

- [ ] Domaine `cinephoria.eu` acheté
- [ ] Bucket S3 `cinephoria-terraform-state` créé
- [ ] Paire de clés `cinephoria-key-pair` générée
- [ ] Fichier `terraform.tfvars` configuré et sécurisé
- [ ] Toutes les valeurs dans `terraform.tfvars` sont correctes

## 🔄 Prochaines Étapes (Phase 2)

Une fois la Phase 1 complétée, vous pourrez:

1. `terraform init` - Initialiser Terraform avec le backend S3
2. `terraform plan` - Vérifier le plan de déploiement
3. `terraform apply` - Déployer l'infrastructure AWS
4. Configurer les DNS du domaine avec les names servers Route53

## 📞 Support

Si vous rencontrez des difficultés, référez-vous aux documents détaillés:
- [`DOCUMENTATION-DOMAIN-SETUP.md`](DOCUMENTATION-DOMAIN-SETUP.md)
- [`DOCUMENTATION-TERRAFORM-STATE-S3.md`](DOCUMENTATION-TERRAFORM-STATE-S3.md)
- [`DOCUMENTATION-SSH-KEY-PAIR.md`](DOCUMENTATION-SSH-KEY-PAIR.md)
- [`DOCUMENTATION-TERRAFORM-TFVARS.md`](DOCUMENTATION-TERRAFORM-TFVARS.md)