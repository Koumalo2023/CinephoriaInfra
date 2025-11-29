# Configuration du domaine cinephoria.eu

## 📋 Étapes pour configurer le domaine

### 1. Achat du domaine
- Rendez-vous chez un registrar (ex: OVH, Gandi, Namecheap, GoDaddy)
- Recherchez et achetez le domaine `cinephoria.eu`
- Complétez le processus d'enregistrement

### 2. Configuration DNS
Après l'achat du domaine, vous devrez configurer les serveurs DNS avec les names servers Route53 qui seront fournis après le déploiement Terraform.

**Processus:**
1. Déployer d'abord l'infrastructure Terraform (sans domaine configuré)
2. Récupérer les names servers Route53 depuis les outputs Terraform
3. Configurer ces names servers chez votre registrar

### 3. Serveurs DNS à configurer
Une fois Terraform déployé, vous obtiendrez 4 serveurs DNS comme:
```
ns-xxxx.awsdns-xx.net
ns-xxxx.awsdns-xx.co.uk
ns-xxxx.awsdns-xx.com
ns-xxxx.awsdns-xx.org
```

### ⚠️ Important
Le domaine doit être configuré APRÈS le déploiement initial de Terraform, car Route53 génère les serveurs DNS.