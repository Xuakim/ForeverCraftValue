FOREVER LEATHER MASTER 0.2.3
=============================

Client cible
- WoW Forever 1.60.1
- Interface: 16001

Installation
1. Fermer WoW Forever.
2. Sauvegarder puis supprimer l'ancien dossier ForeverLeatherMaster.
3. Extraire le dossier ForeverLeatherMaster dans :
   World of Warcraft\_forever_\Interface\AddOns\
4. Vérifier que le fichier se trouve ici :
   Interface\AddOns\ForeverLeatherMaster\ForeverLeatherMaster.toc
5. Relancer WoW Forever et activer l'addon.
6. Taper /flm.

Mode d'emploi
A. Importer les recettes
1. Ouvrir le métier Travail du cuir.
2. Laisser sa fenêtre ouverte.
3. Ouvrir /flm et cliquer « Importer recettes ».
4. L'import utilise les recettes renvoyées par le client pour le métier affiché.

B. Scanner l'hôtel des ventes
1. Ouvrir l'hôtel des ventes.
2. Ouvrir /flm et cliquer « Scanner l'HDV ».
3. Attendre la fin du traitement.
4. Le module conserve le prix unitaire de rachat le plus bas observé pour chaque objet dans ce scan. Les anciens prix sont remplacés à la fin du scan.
5. L'API de réplication a une limite serveur de 15 minutes entre scans complets réussis.

C. Consulter les résultats
- Ouvrir /flm.
- Les recettes avec prix manquants ne sont pas classées.
- Les recettes sont triées par bénéfice estimé décroissant.

Important — limites de cette version
- Il s'agit d'une version de test. Elle doit être validée en jeu sur le build exact.
- L'import ne conserve que les recettes effectivement apprises par le personnage (champ learned/isLearned renvoyé par le client).
- L'import dépend de l'ouverture de la fenêtre du Travail du cuir.
- L'API moderne peut renvoyer des schémas différents selon les recettes, les variantes et les données de profession. Les emplacements de composants alternatifs sont simplifiés en choisissant le composant dont le coût est le plus faible.
- Les prix sont issus des buyouts observés au scan, convertis en prix unitaire. Les annonces sans prix d'achat immédiat sont ignorées.
- Les dépôts d'annonce, les taxes propres au serveur, les coûts de craft non marchands et les matériaux déjà possédés ne sont pas encore intégrés.
- Le prix conservé est le plus bas observé, pas une moyenne de marché.
- Le scan complet peut être refusé par le serveur si le délai de 15 minutes n'est pas écoulé.
- Aucun achat, craft ou dépôt automatique n'est effectué.
- Ne pas publier comme version stable CurseForge avant tests.

Commandes
/flm
/flm help
/flm price <itemID> <cuivre>


Nouveautés 0.2.2 — Affichage des recettes
- Liste en colonnes : recette, coût de fabrication, vente nette, bénéfice net et marge.
- Bénéfice positif affiché en vert, perte en rouge.
- Lignes alternées pour faciliter la lecture.
- Statistiques en bas de fenêtre : recettes apprises, objets tarifés, résultats calculables et date du dernier scan.
- La liste affiche les 14 premières recettes les plus rentables.


Nouveautés 0.2.3 — Icône et minimap
- Icône d'addon définie dans le TOC (icône d'armure en cuir intégrée au client WoW).
- Bouton rond autour de la minimap.
- Clic gauche : ouvrir ou fermer la fenêtre.
- Clic droit : actualiser le classement.
- Déplacement du bouton autour de la minimap par glisser-déposer.
- Position et préférence d'affichage sauvegardées.
- /flm minimap affiche ou masque le bouton.
