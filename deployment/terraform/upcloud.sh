#!/bin/bash
set -e

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ENV_FILE="../../.env"

# Fonction pour demander et stocker les credentials
setup_credentials() {
    echo -e "${YELLOW}⚙️  Configuration des credentials UpCloud${NC}"
    echo ""
    
    # Demander le username
    read -p "Username API UpCloud: " username
    
    # Demander le password (masqué)
    read -sp "Password API UpCloud: " password
    echo ""
    echo ""
    
    # Créer ou mettre à jour le .env
    if [ -f "$ENV_FILE" ]; then
        # Supprimer les anciennes lignes UPCLOUD si elles existent
        sed -i '/^UPCLOUD_USERNAME=/d' "$ENV_FILE"
        sed -i '/^UPCLOUD_PASSWORD=/d' "$ENV_FILE"
    fi
    
    # Ajouter les credentials
    echo "UPCLOUD_USERNAME=$username" >> "$ENV_FILE"
    echo "UPCLOUD_PASSWORD=$password" >> "$ENV_FILE"
    
    echo -e "${GREEN}✓ Credentials sauvegardés dans $ENV_FILE${NC}"
    echo ""
}

# Vérifier si les credentials existent
check_credentials() {
    if [ ! -f "$ENV_FILE" ]; then
        return 1
    fi
    
    if ! grep -q "^UPCLOUD_USERNAME=" "$ENV_FILE" 2>/dev/null || \
       ! grep -q "^UPCLOUD_PASSWORD=" "$ENV_FILE" 2>/dev/null; then
        return 1
    fi
    
    # Vérifier que les valeurs ne sont pas vides
    source "$ENV_FILE"
    if [ -z "$UPCLOUD_USERNAME" ] || [ -z "$UPCLOUD_PASSWORD" ]; then
        return 1
    fi
    
    return 0
}

# Si credentials manquants, les demander
if ! check_credentials; then
    setup_credentials
fi

# Charger les credentials
set -a
source "$ENV_FILE"
set +a

echo -e "${GREEN}✓ Credentials chargés (User: $UPCLOUD_USERNAME)${NC}"
echo ""

# Vérifier qu'une commande terraform est passée
if [ $# -eq 0 ]; then
    echo -e "${RED}❌ Erreur: Aucune commande terraform spécifiée${NC}"
    echo ""
    echo "Usage: $0 <terraform-command> [args...]"
    echo ""
    echo "Exemples:"
    echo "  $0 init"
    echo "  $0 plan"
    echo "  $0 apply"
    echo "  $0 destroy"
    echo "  $0 output"
    exit 1
fi

# Exécuter la commande terraform avec tous les arguments
echo -e "${YELLOW}🚀 Exécution: terraform $@${NC}"
echo ""
terraform "$@"