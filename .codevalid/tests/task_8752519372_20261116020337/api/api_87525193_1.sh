#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"

BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
# The app defines no sign-in route or auth middleware (src/app.ts), so requests carry no credentials.
SKU="CV1-${SUFFIX}"
NAME="CV Widget ${SUFFIX}"
PID=""

# Given
cv_step Given "a product code not yet used in the catalog" $LINENO
cv_http GET "/api/products?q=${SUFFIX}&limit=100" 200
N=$(printf '%s' "$CV_HTTP_BODY" | jq --arg s "$SKU" '[.data[] | select(.sku == $s)] | length')
[ "$N" = "0" ] || cv_fail "expected no product with code $SKU before adding got $N" $LINENO

# When
cv_step When "the user adds a product with name, description, price and product code" $LINENO
BODY=$(jq -nc --arg s "$SKU" --arg n "$NAME" '{sku:$s,name:$n,description:"A test widget",priceCents:1999}')
cv_http POST /api/products "$BODY"
ADD_STATUS="$CV_HTTP_STATUS"
PID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.id // empty')

# Then
cv_step Then "the product is saved and appears in the full catalog and by its id" $LINENO
[ "$ADD_STATUS" = "201" ] || cv_fail "expected 201 from add product got $ADD_STATUS" $LINENO
[ -n "$PID" ] || cv_fail "expected product id in add response got none" $LINENO
cv_http GET "/api/products?limit=100&q=${SUFFIX}" 200
M=$(printf '%s' "$CV_HTTP_BODY" | jq -c --arg id "$PID" '[.data[] | select(.id == $id)]')
[ "$(printf '%s' "$M" | jq length)" = "1" ] || cv_fail "expected product $PID listed once in catalog got $M" $LINENO
[ "$(printf '%s' "$M" | jq -r '.[0].sku')" = "$SKU" ] || cv_fail "expected listed sku $SKU got $M" $LINENO
[ "$(printf '%s' "$M" | jq -r '.[0].name')" = "$NAME" ] || cv_fail "expected listed name $NAME got $M" $LINENO
cv_http GET "/api/products/${PID}" 200
[ "$(printf '%s' "$CV_HTTP_BODY" | jq -r '.sku')" = "$SKU" ] || cv_fail "expected sku $SKU by id got $CV_HTTP_BODY" $LINENO
[ "$(printf '%s' "$CV_HTTP_BODY" | jq -r '.name')" = "$NAME" ] || cv_fail "expected name $NAME by id got $CV_HTTP_BODY" $LINENO
[ "$(printf '%s' "$CV_HTTP_BODY" | jq -r '.description')" = "A test widget" ] || cv_fail "expected description by id got $CV_HTTP_BODY" $LINENO
[ "$(printf '%s' "$CV_HTTP_BODY" | jq -r '.priceCents')" = "1999" ] || cv_fail "expected priceCents 1999 by id got $CV_HTTP_BODY" $LINENO

# Cleanup
cv_step Cleanup "delete the created product" $LINENO
if [ -n "$PID" ]; then cv_http DELETE "/api/products/${PID}"; fi

echo "CODEVALID_TEST_ASSERTION_OK:api_87525193_1"
