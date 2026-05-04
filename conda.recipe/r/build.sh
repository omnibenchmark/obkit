#!/usr/bin/env bash
set -eo pipefail

# Sync DESCRIPTION Version: with the conda package version. R packages
# don't accept .postN, so when OBKIT_VERSION carries a post suffix
# (non-tag main builds) we strip it for the in-package R Version field;
# the conda package version still records the post suffix.
R_VERSION="${PKG_VERSION%%.post*}"

mv DESCRIPTION DESCRIPTION.bak
sed "s/^Version:.*/Version: ${R_VERSION}/" DESCRIPTION.bak >DESCRIPTION
rm DESCRIPTION.bak

R CMD INSTALL --build .
