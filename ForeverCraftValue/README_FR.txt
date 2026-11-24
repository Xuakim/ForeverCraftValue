FOREVER CRAFTVALUE 0.5.0
=======================

Client cible
- WoW Forever 1.60.1
- Interface: 16001

Installation
1. Fermer WoW Forever.
2. Extraire le dossier ForeverCraftValue dans :
   World of Warcraft\\_forever_\\Interface\\AddOns\\
3. Vérifier que le fichier ForeverCraftValue.toc est dans ce dossier.
4. Relancer WoW Forever et activer Forever CraftValue.
5. Ouvrir l'addon avec /fcv (ancienne commande /flm toujours compatible).

Mode d'emploi
1. Ouvrir le métier souhaité.
2. Cliquer sur « Importer recettes ».
3. Répéter l'import pour chaque métier voulu.
4. Utiliser le sélecteur « Métier » pour passer d'un métier importé à l'autre.
5. Ouvrir l'hôtel des ventes et cliquer sur « Scan ciblé ».
6. Le scan ciblé conserve uniquement les annonces des objets utilisés par les recettes du métier actif, y compris les composants fabriqués par les autres métiers importés.
7. Utiliser « Scan complet » uniquement pour actualiser tous les objets de l'hôtel des ventes.
8. Consulter les coûts, ventes nettes, dépôts, bénéfices et marges calculés.

Données et compatibilité
- Les données sauvegardées existantes sont conservées : la variable ForeverLeatherMasterDB est volontairement conservée.
- La commande /flm reste disponible pour compatibilité ; /fcv est la nouvelle commande.
- Les prix observés à l'hôtel des ventes sont partagés entre les métiers.
- Aucun achat, craft ou dépôt automatique n'est effectué.
- Version 0.5.0 : scan ciblé des composants et produits des recettes, avec conservation du scan complet.

Limites
- L'addon doit être validé en jeu sur le build exact de WoW Forever.
- L'import dépend des API de métiers disponibles sur le client.
- Les recettes sans composants exploitables ne sont pas intégrées.
- Les composants alternatifs sont simplifiés par la logique actuelle de l'optimiseur.
- Le scan ciblé utilise la réplication HDV du client, puis filtre localement les annonces : le serveur transmet donc toujours la liste répliquée complète. Le gain porte sur le traitement et le stockage, pas sur le volume téléchargé.
- Le prix retenu est le plus bas observé dans le scan ; ce n'est pas une moyenne de marché.
