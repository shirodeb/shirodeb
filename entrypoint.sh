#!/bin/bash
# This is docker entrypoint.
# !! DO NOT USE IT FOR OTHER USAGE !!

source $(dirname $0)/utils.sh

log.info "ShiroDEB Docker Entrypoint"

if [[ ! -f /recipe/build.sh ]]; then
    log.error "No build.sh found for recipe"
    log.info "Make sure you've add a recipe bind to \`/recipe\`"
    exit -1
fi

for i in /recipe/*; do
    ln -sf $i $(basename $i)
done

exec /bin/bash /shirodeb/shirodeb.sh "$@"
