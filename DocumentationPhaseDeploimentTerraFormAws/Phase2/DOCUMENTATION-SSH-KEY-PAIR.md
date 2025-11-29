# Génération d'une paire de clés SSH pour EC2

## 📋 Étapes pour créer la paire de clés

### 1. Accéder à la console AWS EC2
- Connectez-vous à la [console AWS](https://console.aws.amazon.com/)
- Allez dans le service EC2
- Dans le menu de gauche, cliquez sur "Paires de clés" sous "Réseau et sécurité"

### 2. Créer une nouvelle paire de clés

**Cliquez sur "Créer une paire de clés"**

**Configuration:**
- **Nom:** `cinephoria-key-pair`
- **Type de paire de clés:** `RSA`
- **Format de fichier de clé privée:** `.pem` (pour Linux/Mac) ou `.ppk` (pour Windows/PuTTY)

**Cliquez sur "Créer une paire de clés"**

### 3. Télécharger et sécuriser la clé privée
- Le fichier `cinephoria-key-pair.pem` sera téléchargé automatiquement
- Stockez-le dans un endroit sécurisé (ex: `~/.ssh/` sur Linux/Mac)
- Modifiez les permissions du fichier:

```bash
# Sur Linux/Mac
chmod 400 cinephoria-key-pair.pem
```

### 4. Utilisation avec Windows
Si vous utilisez Windows:
- Utilisez PuTTYgen pour convertir le fichier .pem en .ppk
- Ou utilisez Windows Subsystem for Linux (WSL)

### 5. Vérification
- La paire de clés doit apparaître dans votre liste EC2 > Paires de clés
- La clé privée doit être sauvegardée en sécurité

### ⚠️ Important
- **NE PARTAGEZ JAMAIS** votre clé privée
- Sans cette clé, vous ne pourrez pas vous connecter en SSH à l'instance EC2
- Gardez le nom de la paire de clés, vous en aurez besoin pour `terraform.tfvars`