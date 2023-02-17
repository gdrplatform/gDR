ARG BASE_IMAGE=marcinkam/gdrshiny:0.11
FROM ${BASE_IMAGE}

# temporary fix
# GitHub token for downloading private dependencies
ARG GITHUB_TOKEN

#================= Install dependencies
RUN mkdir -p /mnt/vol
COPY rplatform/dependencies.yaml rplatform/.github_access_token.txt* /mnt/vol
COPY rplatform/install_all_deps.R /mnt/vol/install_all_deps.R
RUN echo "$GITHUB_TOKEN" >> /mnt/vol/.github_access_token.txt
RUN R -f /mnt/vol/install_all_deps.R

#================= Check & build package
COPY ./ /tmp/gDR/
COPY rplatform/install_repo.R /mnt/vol
RUN R -f /mnt/vol/install_repo.R 

#================= Clean up
RUN sudo rm -rf /mnt/vol/* /tmp/gDR/
