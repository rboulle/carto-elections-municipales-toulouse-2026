#!/usr/bin/env Rscript
# MCO-elections-toulouse-contraint.R
#
# Objectif : estimer le taux de report de chaque liste du 1er tour vers
# Moudenc, Piquemal ou l'abstention au 2nd tour.
#
# On impose deux contraintes physiques :
#   - tous les taux sont entre 0 % et 100 %
#   - pour chaque liste, les trois flux (Moudenc + Piquemal + abstention) = 100 %
#
# Briançon (PS) et Piquemal (LFI) ont fusionné pour le R2 → on les regroupe
# en "UnionGauche" pour éviter un problème de corrélation géographique (r = 0,66)
# qui rendrait leurs coefficients individuels non fiables.
#
# Usage : Rscript notes/MCO-elections-toulouse-contraint.R   (depuis la racine)

library(quadprog)  # install.packages("quadprog") si nécessaire


# ── 1. Charger les données ─────────────────────────────────────────────────────

# X : 284 bureaux × 11 colonnes — voix obtenues par chaque liste au R1
#                                  + nombre de non-votants au R1
X <- as.matrix(read.csv("notes/X_bureaux_R1.csv", row.names = 1)[, -1])

# Y : 284 bureaux × 3 colonnes — voix Moudenc, Piquemal, non-votants au R2
Y <- as.matrix(read.csv("notes/Y_bureaux_R2.csv", row.names = 1)[, -1])

Y_M   <- Y[, 1]   # voix Moudenc R2 dans chaque bureau
Y_P   <- Y[, 2]   # voix Piquemal R2
Y_abs <- Y[, 3]   # non-votants R2


# ── 2. Fusionner Briançon + Piquemal en "UnionGauche" ─────────────────────────

# Ces deux listes ont fusionné pour le R2. Les traiter séparément crée une
# ambiguïté que les données ne permettent pas de lever.
X <- cbind(
  X[, !colnames(X) %in% c("Briancon_PS", "Piquemal_LFI")],
  UnionGauche = X[, "Briancon_PS"] + X[, "Piquemal_LFI"]
)
# X a maintenant 10 colonnes au lieu de 11.

n_bureaux <- nrow(X)   # 284 bureaux de vote
n_listes  <- ncol(X)   # 10 listes sources


# ── 3. Construire le système d'équations ───────────────────────────────────────

# On cherche deux vecteurs de 10 coefficients :
#   beta_M   : fraction de chaque liste qui vote Moudenc au R2
#   beta_P   : fraction de chaque liste qui vote Piquemal au R2
#   beta_abs : fraction restante (= 1 - beta_M - beta_P), déduite par soustraction
#
# Chaque bureau de vote fournit une équation :
#   voix_Moudenc_i  ≈  X[i,] · beta_M
#   voix_Piquemal_i ≈  X[i,] · beta_P
#
# En substituant beta_abs = 1 - beta_M - beta_P dans la troisième équation,
# les 3 × 284 équations se réécrivent comme un seul grand système :
#
#   ┌ Y_M    ┐   ┌  X    0  ┐ ┌ beta_M ┐
#   │ Y_P    │ = │  0    X  │ │ beta_P │
#   └ Ỹ_abs ┘   └ -X   -X  ┘ └        ┘
#
# avec Ỹ_abs = Y_abs - X × 1  (on déplace la constante à droite)

zero <- matrix(0, n_bureaux, n_listes)

X_aug <- rbind(cbind(X,    zero),   # équation Moudenc
               cbind(zero, X   ),   # équation Piquemal
               cbind(-X,  -X   ))   # équation abstention (après substitution)

y_aug <- c(Y_M, Y_P, Y_abs - X %*% rep(1, n_listes))


# ── 4. Mettre en forme pour le solveur QP ─────────────────────────────────────

# solve.QP minimise  (1/2) t(x) D x - t(d) x,  ce qui revient à minimiser
# la somme des carrés des erreurs  ||y_aug - X_aug × params||².
#
# D et d se calculent directement depuis le système augmenté.

n_params <- 2 * n_listes   # 20 inconnues : 10 beta_M + 10 beta_P

D <- 2 * t(X_aug) %*% X_aug   # matrice (20 × 20)
d <- 2 * t(X_aug) %*% y_aug   # vecteur (20,)


# ── 5. Définir les contraintes ─────────────────────────────────────────────────

# On impose trois groupes de contraintes sur les 20 inconnues :
#
#   (a)  beta_M[k] >= 0   et   beta_P[k] >= 0     → pas de taux négatif
#   (b)  beta_M[k] <= 1   et   beta_P[k] <= 1     → pas de taux > 100 %
#   (c)  beta_M[k] + beta_P[k] <= 1  pour tout k  → beta_abs[k] >= 0
#
# Sans (c), le solveur peut trouver une solution où la somme dépasse 100 %,
# ce qui donnerait une abstention négative — physiquement absurde.

A_c    <- -cbind(diag(n_listes), diag(n_listes))   # (10 × 20) pour contrainte (c)

A_ineq <- rbind(diag(n_params),    # (a) toutes les inconnues >= 0
                -diag(n_params),   # (b) toutes les inconnues <= 1
                A_c)               # (c) beta_M + beta_P <= 1 pour chaque liste

b_ineq <- c(rep( 0, n_params),   # seuils pour (a)
            rep(-1, n_params),   # seuils pour (b)
            rep(-1, n_listes))   # seuils pour (c)


# ── 6. Résoudre ────────────────────────────────────────────────────────────────

sol <- solve.QP(Dmat = D, dvec = d, Amat = t(A_ineq), bvec = b_ineq)

beta_M   <- sol$solution[1:n_listes]
beta_P   <- sol$solution[(n_listes + 1):n_params]
beta_abs <- 1 - beta_M - beta_P   # >= 0 garanti par la contrainte (c)


# ── 7. Afficher les résultats ──────────────────────────────────────────────────

cat("=== Taux de report estimés (modèle contraint, UnionGauche) ===\n\n")
resultat <- data.frame(
  liste      = colnames(X),
  Moudenc    = round(beta_M   * 100, 1),
  Piquemal   = round(beta_P   * 100, 1),
  Abstention = round(beta_abs * 100, 1)
)
print(resultat)
 
# Vérification : chaque ligne doit sommer à 100 %
cat("\nSomme par liste (doit être 100 %) :\n")
print(resultat$Moudenc + resultat$Piquemal + resultat$Abstention)

# Qualité d'ajustement
ss_tot   <- function(y) sum((y - mean(y))^2)
cat(sprintf("\nR²  Moudenc : %.3f  |  Piquemal : %.3f  |  Abstention : %.3f\n",
  1 - sum((Y_M   - X %*% beta_M  )^2) / ss_tot(Y_M),
  1 - sum((Y_P   - X %*% beta_P  )^2) / ss_tot(Y_P),
  1 - sum((Y_abs - X %*% beta_abs)^2) / ss_tot(Y_abs)))
