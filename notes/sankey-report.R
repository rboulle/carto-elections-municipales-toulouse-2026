#!/usr/bin/env Rscript
# sankey-report.R
# Diagramme de Sankey des reports de voix entre les deux tours
# Toulouse Municipales 2026 — estimation MCO multi-output (284 bureaux)
#
# Usage : Rscript notes/sankey-report.R   (depuis la racine du dépôt)
#         Rscript sankey-report.R         (depuis notes/)
# Output: notes/sankey-report.svg

# ── Dépendances ───────────────────────────────────────────────────────────────
for (pkg in c("ggalluvial", "svglite")) {
  if (!requireNamespace(pkg, quietly = TRUE))
    install.packages(pkg, repos = "https://cloud.r-project.org")
}

suppressPackageStartupMessages({
  library(ggplot2)
  library(ggalluvial)
  library(svglite)
})

# ── Chemins ───────────────────────────────────────────────────────────────────
args <- commandArgs(trailingOnly = FALSE)
script_idx <- grep("--file=", args)
if (length(script_idx)) {
  script_dir <- dirname(normalizePath(sub("--file=", "", args[script_idx])))
} else {
  script_dir <- getwd()  # fallback RStudio : lancer depuis notes/
}
out_svg <- file.path(script_dir, "sankey-report.svg")

# ── 1. Données (totaux R1 + coefficients MCO) ────────────────────────────────
# Totaux R1 calculés depuis data.json (python3 -c "..." ou cf. adoc §9.1)
# Inscrits : 281 354 | Votants R1 : 158 977
# [beta_Moudenc, beta_Piquemal, beta_Abstention] — modèle multi-output en
# volumes absolus, estimé par numpy.linalg.lstsq sans constante
listes <- data.frame(
  nom     = c(
    "Briançon (PS)", "Scalli", "Adrada", "Menéndez", "Moudenc (DVD)",
    "Leonardelli (RN)", "Cottrel", "Meilhac", "Piquemal (LFI)", "Pedinotti",
    "Non-votants R1"
  ),
  votes   = c(39245, 438, 653, 290, 58462, 8447, 1953, 2648, 43274, 1611, 122377),
  bm      = c( 0.247, -0.640, -0.110, -0.960,  1.190,  1.120,  1.500,  0.810, -0.040, -0.100,  0.010),
  bp      = c( 0.674,  1.370,  0.360,  0.850, -0.070, -0.260, -0.050,  0.090,  1.060,  0.760,  0.090),
  ba      = c(-0.010,  0.190,  0.080,  0.700, -0.120,  0.160, -0.390,  0.050, -0.030,  0.560,  0.910),
  stable  = c(TRUE, FALSE, FALSE, FALSE, TRUE, TRUE, FALSE, TRUE, TRUE, FALSE, TRUE),
  couleur = c(
    "#d0237a",  # Briançon — PS
    "#aaaaaa",  # Scalli   — instable
    "#aaaaaa",  # Adrada   — instable
    "#aaaaaa",  # Menéndez — instable
    "#0055a0",  # Moudenc  — DVD
    "#002395",  # Leonardelli — RN
    "#aaaaaa",  # Cottrel  — instable
    "#7b2d8b",  # Meilhac
    "#c0392b",  # Piquemal — LFI
    "#aaaaaa",  # Pedinotti — instable
    "#cccccc"   # Non-votants R1
  ),
  stringsAsFactors = FALSE
)

# ── 3. Calcul des flux (contrainte [0, 1] + normalisation) ───────────────────
# Coefficients hors [0,1] → contraints pour rendre les flux représentables :
#   - valeurs négatives : ramenées à 0
#   - somme > 1         : normalisée à 1
#   - résidu (somme < 1): affecté à l'abstention
compute_flows <- function(bm, bp, ba, votes) {
  m <- max(0, min(1, bm))
  p <- max(0, min(1, bp))
  a <- max(0, min(1, ba))
  s <- m + p + a
  if (s > 1) { m <- m / s; p <- p / s; a <- a / s }
  else        { a <- max(a, 1 - m - p) }
  round(c(Moudenc = m, Piquemal = p, Abstention = a) * votes)
}

flux <- t(mapply(compute_flows, listes$bm, listes$bp, listes$ba, listes$votes))

# ── 4. Format long pour ggalluvial ───────────────────────────────────────────
dests <- c("Moudenc R2", "Piquemal R2", "Abstention R2")

df <- do.call(rbind, lapply(seq_len(nrow(listes)), function(i) {
  data.frame(
    source  = listes$nom[i],
    target  = dests,
    voix    = as.numeric(flux[i, ]),
    couleur = listes$couleur[i],
    stringsAsFactors = FALSE
  )
}))
df <- df[df$voix > 0, ]

# ggalluvial place le PREMIER niveau en HAUT du graphique.
# Ordre voulu (haut → bas) : Moudenc, Piquemal, Briançon, Leonardelli,
#                             petites listes, Non-votants
ordre_src <- c(
  "Moudenc (DVD)",                          # haut
  "Piquemal (LFI)",
  "Briançon (PS)",
  "Leonardelli (RN)",
  "Meilhac",
  "Cottrel",
  "Non-votants R1",
  "Pedinotti", "Adrada", "Scalli", "Menéndez"  # bas
)
df$source <- factor(df$source, levels = ordre_src)
df$target <- factor(df$target, levels = dests)  # Moudenc R2 en haut, Abstention en bas

# ── 5. Lookups de voix officielles (étiquettes gauche et droite) ─────────────
voix_r1 <- setNames(listes$votes, listes$nom)


# Votants R2 : 175 994 | Exprimés R2 : 171 073 | Inscrits : 281 355
voix_r2 <- c(
  "Moudenc R2"    = 92151,
  "Piquemal R2"   = 78922,
  "Abstention R2" = 105361   # inscrits − votants R2
)

# ── 6. Couleurs ───────────────────────────────────────────────────────────────
couleurs_src    <- setNames(listes$couleur, listes$nom)
couleurs_target <- c(
  "Moudenc R2"    = "#0055a0",
  "Piquemal R2"   = "#c0392b",
  "Abstention R2" = "#9e9e9e"
)
all_couleurs <- c(couleurs_src, couleurs_target)

# ── 6. Graphique ──────────────────────────────────────────────────────────────
fmt <- function(x) format(round(x), big.mark = "\u00a0", scientific = FALSE, trim = TRUE)

p <- ggplot(df, aes(y = voix, axis1 = source, axis2 = target)) +

  # Rubans
  geom_alluvium(
    aes(fill = source),
    alpha    = 0.5,
    width    = 1 / 6,
    knot.pos = 0.35
  ) +

  # Rectangles des strates
  geom_stratum(
    aes(fill = after_stat(stratum)),
    width     = 1 / 6,
    color     = "white",
    linewidth = 0.3
  ) +

  # Étiquettes gauche (axis1 = source) : nom + voix sur deux lignes
  geom_text(
    stat    = "stratum",
    aes(label = ifelse(
      as.integer(after_stat(x)) == 1L,
      {
        v <- voix_r1[as.character(after_stat(stratum))]
        f <- format(v, big.mark = "\u00a0", scientific = FALSE, trim = TRUE)
        ifelse(v >= 8000,
          paste0(after_stat(stratum), "\n", f),          # 2 lignes
          ifelse(v >= 500,
            paste0(after_stat(stratum), "  ", f),        # 1 ligne
            as.character(after_stat(stratum))            # nom seul
          )
        )
      },
      ""
    )),
    hjust      = 1,
    nudge_x    = -0.09,
    size       = 2.8,
    lineheight = 0.9,
    color      = "#444444"
  ) +

  # Étiquettes droite (axis2 = target) : nom + vrais résultats R2
  geom_text(
    stat     = "stratum",
    aes(
      label = ifelse(
        as.integer(after_stat(x)) == 2L,
        paste0(after_stat(stratum), "\n",
               format(voix_r2[as.character(after_stat(stratum))],
                      big.mark = "\u00a0", scientific = FALSE, trim = TRUE)),
        ""
      ),
      color = after_stat(stratum)
    ),
    hjust      = 0,
    nudge_x    = 0.09,
    size       = 3.0,
    lineheight = 0.9,
    fontface   = "bold"
  ) +

  scale_fill_manual(values = all_couleurs, guide = "none") +

  scale_color_manual(
    values = c(couleurs_target, setNames(rep("#444444", nrow(listes)), listes$nom)),
    guide  = "none"
  ) +

  scale_x_discrete(
    limits = c("source", "target"),
    labels = c("1er tour", "2nd tour"),
    expand = c(0.38, 0.25)   # espace pour les étiquettes externes
  ) +

  scale_y_continuous(labels = fmt, name = NULL, expand = c(0, 0)) +

  labs(
    title    = "Reports estimés des voix \u2014 Toulouse Municipales 2026",
    subtitle = "Estimation par r\u00e9gression \u00e9cologique MCO multi-output (284 bureaux de vote)",
    caption  = paste0(
      "Flux estim\u00e9s par MCO multi-output (voix absolus). ",
      "Coefficients hors [\u202f0\u202f;\u202f1\u202f] contraints : n\u00e9gatifs \u2192 0, sommes > 1 normalis\u00e9es.\n",
      "Listes en gris : instables (faible volume, coefficients non interpr\u00e9tables). ",
      "Non-votants R1 (122\u00a0377) inclus."
    )
  ) +

  theme_minimal(base_size = 11, base_family = "") +
  theme(
    plot.title    = element_text(face = "bold", size = 13, hjust = 0.5, margin = margin(b = 4)),
    plot.subtitle = element_text(color = "grey45", size = 9, hjust = 0.5, margin = margin(b = 8)),
    plot.caption  = element_text(color = "grey60", size = 7.5, hjust = 0.5, lineheight = 1.3),
    legend.position  = "none",
    panel.background = element_blank(),
    panel.grid       = element_blank(),
    axis.text.x      = element_text(face = "bold", size = 11),
    axis.text.y      = element_text(size = 8, color = "grey50"),
    plot.margin      = margin(10, 10, 10, 10)
  )

# ── 7. Export ─────────────────────────────────────────────────────────────────
ggsave(out_svg, plot = p, width = 12, height = 9, device = "svg")
message("Sankey export\u00e9 : ", out_svg)
