ARG BASE_IMAGE=bioconductor/bioconductor_docker:devel
FROM ${BASE_IMAGE}


#================= Install gdrplatform packages
RUN mkdir -p /mnt/vol
COPY rplatform/dependencies.yaml rplatform/.github_access_token.txt* /mnt/vol
RUN Rscript -e 'BiocManager::install(c("gDRstyle", "gDRtestData", "gDRutils", "gDRimport", "gDRcore", "gDR"))'
RUN sudo rm -rf /mnt/vol/*
