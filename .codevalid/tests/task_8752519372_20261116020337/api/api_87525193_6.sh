#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"

BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
# The app defines no sign-in route or auth middleware (src/app.ts), so requests carry no credentials.
SKU="CV6-${SUFFIX}"
NAME="CV6 Browse ${SUFFIX}"
PID=""

# Given
cv_step Given "a product exists in the catalog" $LINENO
BODY=$(jq -nc --arg s "$SKU" --arg n "$NAME" '{sku:$s,name:$n,description:"Browse me",priceCents:4500}')
cv_http POST /api/products "$BODY" 201
PID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.id // empty')
[ -n "$PID" ] || cv_fail "expected product id for seeded product got none" $LINENO

# When
cv_step When "an anonymous visitor views the full catalog and opens the product" $LINENO
cv_http GET "/api/products?limit=100&q=${SUFFIX}"
LIST_STATUS="$CV_HTTP_STATUS"; LIST_BODY="$CV_HTTP_BODY"
cv_http GET "/api/products/${PID}"
ONE_STATUS="$CV_HTTP_STATUS"; ONE_BODY="$CV_HTTP_BODY"

# Then
cv_step Then "both requests return the product data" $LINENO
[ "$LIST_STATUS" = "200" ] || cv_fail "expected 200 for anonymous catalog list got $LIST_STATUS" $LINENO
M=$(printf '%s' "$LIST_BODY" | jq -c --arg id "$PID" '[.data[] | select(.id == $id)]')
[ "$(printf '%s' "$M" | jq length)" = "1" ] || cv_fail "expected product $PID in anonymous catalog list got $M" $LINENO
[ "$(printf '%s' "$M" | jq -r '.[0].name')" = "$NAME" ] || cv_fail "expected listed name $NAME got $M" $LINENO
[ "$ONE_STATUS" = "200" ] || cv_fail "expected 200 for anonymous product view got $ONE_STATUS" $LINENO
[ "$(printf '%s' "$ONE_BODY" | jq -r '.sku')" = "$SKU" ] || cv_fail "expected sku $SKU got $ONE_BODY" $LINENO
[ "$(printf '%s' "$ONE_BODY" | jq -r '.priceCents')" = "4500" ] || cv_fail "expected priceCents 4500 got $ONE_BODY" $LINENO

# Cleanup
cv_step Cleanup "delete the seeded product" $LINENO
if [ -n "$PID" ]; then cv_http DELETE "/api/products/${PID}"; fi

echo "CODEVALID_TEST_ASSERTION_OK:api_87525193_6"
