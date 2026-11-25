FOREVER CRAFTVALUE 1.0.0
=======================

Présentation
- Addon d'analyse de rentabilité des recettes pour WoW Forever.
- Gestion de plusieurs métiers de fabrication dans des onglets séparés.
- Comparaison du coût des composants avec le prix de vente à l'hôtel des ventes.
- Calcul du prix de vente net, de la commission, du dépôt, du bénéfice et de la marge.

Client cible
- WoW Forever 1.60.1
- Interface : 16001

Installation
1. Fermer WoW Forever.
2. Extraire le dossier ForeverCraftValue dans :
   World of Warcraft\\_forever_\\Interface\\AddOns\\
3. Vérifier que le fichier ForeverCraftValue.toc est dans ce dossier.
4. Relancer WoW Forever et activer Forever CraftValue dans la liste des addons.
5. Ouvrir l'addon avec /fcv (l'ancienne commande /flm reste compatible).

Mode d'emploi
1. Ouvrir la fenêtre d'un métier de fabrication.
2. Cliquer sur « Importer recettes » pour importer les recettes apprises de ce métier.
3. Recommencer pour chaque métier que l'on souhaite analyser.
4. Utiliser les onglets ou le sélecteur « Métier » pour afficher les recettes d'un métier importé.
5. Ouvrir l'hôtel des ventes et lancer « Scan ciblé » pour rechercher les objets utiles aux recettes importées.
6. Consulter les résultats : coûts des matériaux, prix de vente brut et net, commission, dépôt, bénéfice et marge.
7. Relancer le scan après une évolution des prix du marché.

Fonctionnement des scans
- Le scan ciblé construit une liste des objets utiles aux recettes importées et interroge ces objets individuellement à l'hôtel des ventes.
- Les composants fabriqués par un autre métier importé sont développés récursivement : leurs propres ingrédients sont également recherchés.
- Les recherches sont espacées pour limiter le rythme des requêtes ; les recherches qui n'aboutissent pas dans le délai prévu sont comptabilisées comme terminées.
- Le scan complet, lorsqu'il est disponible dans l'interface, sert à actualiser les prix de l'ensemble des objets renvoyés par l'hôtel des ventes.
- Les prix enregistrés sont partagés entre les métiers.

Calculs
- Pour chaque réactif, l'optimiseur compare les choix de composants disponibles et retient le coût connu le plus bas.
- Lorsqu'un composant peut être fabriqué avec une recette importée, son coût de fabrication peut être comparé à son prix d'achat à l'hôtel des ventes.
- Le prix de vente net tient compte de la commission de l'hôtel des ventes configurée.
- Le dépôt est estimé selon la durée d'annonce configurée et le prix vendeur de l'objet lorsque cette information est disponible.
- Un bénéfice n'est affiché que lorsque les coûts des matériaux et le prix de vente sont suffisamment renseignés.

Données et compatibilité
- Les données sauvegardées existantes sont conservées ; la variable ForeverLeatherMasterDB est volontairement maintenue pour assurer la compatibilité.
- Les anciennes données de recettes sont migrées vers le système multi-métiers lors de l'initialisation.
- Les commandes /flm et /fcv sont prises en charge.
- Aucun achat, craft ou dépôt automatique n'est effectué.

Limites
- L'addon doit être validé en jeu sur le build exact de WoW Forever ; les API disponibles peuvent varier selon le client.
- Seules les recettes apprises et correctement exposées par l'API des métiers peuvent être importées.
- Les composants alternatifs sont comparés selon les prix connus ; les règles de fabrication plus complexes peuvent ne pas être entièrement représentées.
- Les prix observés sont des instantanés du scan, pas une moyenne ni une garantie de prix de vente.
- Le scan ciblé dépend des API de recherche de l'hôtel des ventes du client. Les résultats absents ou les recherches expirées ne fournissent pas de prix.
- Le dépôt affiché est une estimation et peut varier selon les règles du serveur et les caractéristiques de l'objet.

Version 1.0.0
- Passage à une gestion multi-métiers.
- Import des recettes apprises pour chaque métier et sélection du métier à afficher.
- Optimisation récursive des composants fabriquables à partir de tous les métiers importés.
- Scan ciblé des objets nécessaires aux recettes, avec limitation du rythme des recherches.
- Calcul enrichi des ventes nettes, commissions, dépôts, bénéfices et marges.
