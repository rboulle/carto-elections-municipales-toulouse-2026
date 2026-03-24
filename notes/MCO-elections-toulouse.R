#!/usr/bin/env Rscript
# MCO-elections-toulouse.R
# Régression écologique MCO multi-output — Toulouse Municipales 2026
#
# Usage : Rscript notes/MCO-elections-toulouse.R   (depuis la racine du dépôt)
#         Rscript MCO-elections-toulouse.R         (depuis notes/)

# ── Lire les données ──────────────────────────────────────────────────────────
# X : variables explicatives — voix R1 par liste + non-votants R1 (284 bureaux × 11 colonnes)
# Y : variables dépendantes  — voix R2 Moudenc, Piquemal, non-votants  (284 bureaux × 3 colonnes)
X <- as.matrix(read.csv("notes/X_bureaux_R1.csv", row.names = 1)[, -1])
Y <- as.matrix(read.csv("notes/Y_bureaux_R2.csv", row.names = 1)[, -1])

# ── Régression MCO sans constante ─────────────────────────────────────────────
# Le -1 supprime l'ordonnée à l'origine (équivalent de numpy.linalg.lstsq)
# Y peut avoir plusieurs colonnes : lm() estime une équation par colonne
fit <- lm(Y ~ X - 1)

# ── Résultats : coefficients en pourcentages ──────────────────────────────────
# coef(fit) renvoie une matrice (11 variables × 3 équations)
# On multiplie par 100 pour lire des pourcentages de report
beta <- coef(fit)
rownames(beta) <- colnames(X)   # lm() préfixe "X" automatiquement, on corrige
print(round(beta * 100, 1))
