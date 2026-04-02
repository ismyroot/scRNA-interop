# scRNA-interop：格式互转、reticulate、极化/UpSet/共识聚类/杂项可视化 + DecontX（对应 singlecell_image_plan.md §七 singlecell-interop）。
# 典型工具：scRNA_creatH5toseurat.qmd、scRNARDStoSamplematrixAnalysis.qmd、single_cell_polarization_analysis.qmd、
#           consensus_clustering_analysis.qmd、scRNA_upsetRmulticelltype.qmd
#
# 包来源概览：
#   CRAN：hdf5r、R.utils、reticulate、colorRamps、UpSetR、Hmisc、gt
#   Bioconductor：ConsensusClusterPlus、SingleCellExperiment、celda
#   GitHub：SeuratDisk（mojaveazure/seurat-disk）、scupa（bsml320/Scupa）、loomR（CRAN 已存档，用 mojaveazure/loomR）、
#           DoubletFinder（plot1cell 依赖）、plot1cell（HaojiaWu/plot1cell，会拉取大量 Bioc/CRAN 依赖）
# 未预装：openai、devtools（方案中标注为默认不建议）
#
# 系统库：libhdf5-dev（hdf5r/loom）；libxml2-dev、libcurl（biomaRt/GEOquery 等常见需求）；python3-minimal（reticulate 可发现解释器）。
#
# 构建示例：
#   cd /home/ubuntu/zhaoyiran/TOOL-Dockerfile/singlecell/scRNA-interop
#   docker build --build-arg R_INSTALL_NCPUS=8 -t quay.io/1733295510/scrna-interop:v1 .

FROM quay.io/1733295510/scrna-base:v1

LABEL maintainer="1733295510 <1733295510@qq.com>"
LABEL org.opencontainers.image.title="scRNA-interop"
LABEL org.opencontainers.image.description="hdf5r, SeuratDisk, reticulate, scupa, ConsensusClusterPlus, SingleCellExperiment, celda, UpSetR, plot1cell, Hmisc, gt (+ heavy plot1cell deps)."

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

ARG R_INSTALL_NCPUS=4
ENV R_INSTALL_NCPUS=${R_INSTALL_NCPUS}

USER root
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    libhdf5-dev \
    libxml2-dev \
    libcurl4-openssl-dev \
    python3-minimal \
 && rm -rf /var/lib/apt/lists/*

# CRAN：方案列出的非 GitHub 包（hdf5r 需上层 libhdf5-dev）
RUN R -e "nc <- suppressWarnings(as.integer(Sys.getenv('R_INSTALL_NCPUS', '4'))); \
  nc <- if (is.na(nc) || nc < 1L) 1L else nc; \
  options(Ncpus = nc); \
  install.packages(c(\
    'hdf5r', \
    'R.utils', \
    'reticulate', \
    'colorRamps', \
    'UpSetR', \
    'Hmisc', \
    'gt'\
  ), repos = 'https://cloud.r-project.org', ask = FALSE, Ncpus = nc)"

# loomR：plot1cell / Seurat 生态仍引用；CRAN 已存档，从 GitHub 安装
RUN R -e "options(repos = BiocManager::repositories()); \
  remotes::install_github('mojaveazure/loomR', upgrade = 'never', dependencies = TRUE)"

# Bioconductor：共识聚类
RUN R -e "nc <- suppressWarnings(as.integer(Sys.getenv('R_INSTALL_NCPUS', '4'))); \
  nc <- if (is.na(nc) || nc < 1L) 1L else nc; \
  options(Ncpus = nc); \
  BiocManager::install('ConsensusClusterPlus', ask = FALSE, update = FALSE, Ncpus = nc)"

# Bioconductor：DecontX 相关依赖（celda + SingleCellExperiment）
RUN R -e "nc <- suppressWarnings(as.integer(Sys.getenv('R_INSTALL_NCPUS', '4'))); \
  nc <- if (is.na(nc) || nc < 1L) 1L else nc; \
  options(Ncpus = nc); \
  BiocManager::install(c('SingleCellExperiment', 'celda'), ask = FALSE, update = FALSE, Ncpus = nc)"

# SeuratDisk：h5Seurat / 与 AnnData 互转（依赖 hdf5r）
RUN R -e "options(repos = BiocManager::repositories()); \
  remotes::install_github('mojaveazure/seurat-disk', upgrade = 'never', dependencies = TRUE)"

# scupa：免疫极化（仓库名为 Scupa，包名 scupa）
RUN R -e "options(repos = BiocManager::repositories()); \
  remotes::install_github('bsml320/Scupa', upgrade = 'never', dependencies = TRUE)"

# plot1cell 依赖 DoubletFinder（GitHub）；先装可减少 plot1cell 解析失败
RUN R -e "options(repos = BiocManager::repositories()); \
  remotes::install_github('chris-mcginnis-ucsf/DoubletFinder', upgrade = 'never', dependencies = TRUE)"

# plot1cell：依赖链重（ComplexHeatmap、biomaRt、EnsDb、GEOquery、simplifyEnrichment、plotly 等）
RUN R -e "nc <- suppressWarnings(as.integer(Sys.getenv('R_INSTALL_NCPUS', '4'))); \
  nc <- if (is.na(nc) || nc < 1L) 1L else nc; \
  options(Ncpus = nc); \
  options(repos = BiocManager::repositories()); \
  remotes::install_github('HaojiaWu/plot1cell', upgrade = 'never', dependencies = TRUE)"

RUN R -e "\
  suppressPackageStartupMessages({\
    library(hdf5r);\
    library(SeuratDisk);\
    library(R.utils);\
    library(reticulate);\
    library(scupa);\
    library(colorRamps);\
    library(ConsensusClusterPlus);\
    library(SingleCellExperiment);\
    library(celda);\
    library(UpSetR);\
    library(plot1cell);\
    library(Hmisc);\
    library(gt);\
  });\
  cat('scRNA-interop OK: SeuratDisk', as.character(packageVersion('SeuratDisk')), \
      ' plot1cell', as.character(packageVersion('plot1cell')), \
      ' celda', as.character(packageVersion('celda')), '\n')\
"

WORKDIR /work
