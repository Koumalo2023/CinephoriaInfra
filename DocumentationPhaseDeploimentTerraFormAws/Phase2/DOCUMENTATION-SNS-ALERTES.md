# Configuration des Alertes SNS (Simple Notification Service)

## 📋 Qu'est-ce qu'un ARN SNS ?

**ARN** = Amazon Resource Name (Nom de Ressource Amazon)
**SNS** = Simple Notification Service (Service de Notification Simple)

Un **ARN SNS** est l'identifiant unique d'un topic SNS dans AWS. Il permet à CloudWatch d'envoyer des alertes (notifications) lorsque certaines conditions sont détectées.

## 🎯 À quoi sert SNS dans notre infrastructure ?

Dans Cinephoria, SNS est utilisé pour :
- Recevoir des alertes quand l'instance EC2 a une utilisation CPU élevée (>80%)
- Être notifié en cas de problèmes avec l'infrastructure
- Centraliser les notifications dans un seul endroit

## 🔧 Comment configurer SNS

### Option 1: Sans SNS (Recommandé pour débuter)
Laissez la valeur vide :
```hcl
cloudwatch_alarm_actions = []
```
Les alertes seront visibles dans CloudWatch mais vous ne recevrez pas de notifications.

### Option 2: Avec SNS (Pour la production)

#### Étape 1: Créer un topic SNS dans AWS Console
1. Aller dans SNS → "Créer un topic"
2. **Type:** "Standard"
3. **Nom:** `cinephoria-alerts`
4. **Nom d'affichage:** `Alertes Cinephoria`

#### Étape 2: S'abonner au topic
1. Cliquer sur le topic créé
2. "Créer un abonnement"
3. **Protocole:** Email, SMS, ou Slack (selon votre préférence)
4. **Endpoint:** Votre email ou numéro de téléphone

#### Étape 3: Récupérer l'ARN SNS
L'ARN ressemble à :
```
arn:aws:sns:eu-west-3:123456789012:cinephoria-alerts
```

#### Étape 4: Configurer dans terraform.tfvars
```hcl
cloudwatch_alarm_actions = ["arn:aws:sns:eu-west-3:123456789012:cinephoria-alerts"]
```

## 💰 Coûts SNS

- **Topic SNS:** Gratuit
- **Notifications Email/SMS:** Payant selon l'usage
- **Premiers 1 000 emails/mois:** Gratuits
- **SMS:** ~0.0075€ par SMS (Europe)

## 🚀 Exemple de configuration complète

```hcl
# Dans terraform.tfvars
cloudwatch_alarm_actions = ["arn:aws:sns:eu-west-3:123456789012:cinephoria-alerts"]
```

## 📱 Types d'abonnements disponibles

- **Email:** Recevez des alertes par email
- **SMS:** Alertes par texto (idéal pour les urgences)
- **Slack/Teams:** Intégration avec vos outils de travail
- **Lambda:** Déclenchement de fonctions automatiques
- **HTTP/HTTPS:** Webhooks vers vos applications

## 🔄 Processus de notification

1. **Détection:** CloudWatch détecte une utilisation CPU >80%
2. **Alerte:** L'alarme CloudWatch se déclenche
3. **Notification:** SNS envoie la notification à tous les abonnés
4. **Réception:** Vous recevez l'alerte par email/SMS/etc.

## ⚠️ Recommandation

Pour commencer, laissez la configuration vide :
```hcl
cloudwatch_alarm_actions = []
```

Vous pourrez ajouter SNS plus tard, une fois l'infrastructure déployée et stable.