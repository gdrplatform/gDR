#/bin/sh

echo "Executing $0"
echo "Environment: ${rp_env}"
echo "Working directory: `pwd`"
echo "Working directory contains: `ls | tr '\n' ' '`"

# exit when any command fails (including any in pipes)
set -eo pipefail

CORE_DIR=/mnt/vol
echo ">>>>> OWNER OF THE REPOSITORY"
# Fix for the access permissions issues with 'R CMD' when running Docker image with 'USER 1000'
sudo chown -R `id -u` $CORE_DIR

echo ">>>>>>>> RUNNING LINT"
Rscript -e "gDRstyle::lintPkgDirs('/mnt/vol')"

echo ">>>>> RUNNING UNIT TESTS"
Rscript -e "testthat::test_local(path = '/mnt/vol', stop_on_failure = TRUE) "

echo ">>>>> RUNNING CHECK"
# add _R_CHECK_FORCE_SUGGESTS_ as a FALSE, to prevend error in check
export _R_CHECK_FORCE_SUGGESTS_=0
R CMD build /mnt/vol 
R CMD check gDR_*.tar.gz --no-vignettes --no-examples --no-manual

echo ">>>>>>>> RUNNING CHECK DEPENDENCIES"
Rscript -e "gDRstyle::checkDependencies(desc_path='/mnt/vol/DESCRIPTION', dep_path='/mnt/vol/rplatform/dependencies.yaml')"
