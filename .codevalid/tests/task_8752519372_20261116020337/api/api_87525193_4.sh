#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"

BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
# The app defines no sign-in route or auth middleware (src/app.ts), so requests carry no credentials.
SKU="CV4-${SUFFIX}"
ORIG_NAME="CV4 Original ${SUFFIX}"
DUP_NAME="CV4 Rejected ${SUFFIX}"
PID=""; DUP_ID=""

# Given
cv_step Given "an original product and a rejected duplicate submission with its code" $LINENO
BODY=$(jq -nc --arg s "$SKU" --arg n "$ORIG_NAME" '{sku:$s,name:$n,description:"Original",priceCents:1200}')
cv_http POST /api/products "$BODY" 201
PID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.id // empty')
[ -n "$PID" ] || cv_fail "expected id for original product got none" $LINENO
DUP=$(jq -nc --arg s "$SKU" --arg n "$DUP_NAME" '{sku:$s,name:$n,description:"Duplicate",priceCents:3400}')
cv_prereq "submit duplicate product code" $LINENO
cv_http POST /api/products "$DUP"
DUP_ID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.id // empty' 2>/dev/null || true)
[ "$CV_HTTP_STATUS" = "409" ] || cv_fail "expected duplicate submission rejected with 409 got $CV_HTTP_STATUS" $LINENO

# When
cv_step When "the full catalog is viewed" $LINENO
cv_http GET "/api/products?limit=100&q=${SUFFIX}" 200

# Then
cv_step Then "only the original product with that code is listed" $LINENO
M=$(printf '%s' "$CV_HTTP_BODY" | jq -c --arg s "$SKU" '[.data[] | select(.sku == $s)]')
[ "$(printf '%s' "$M" | jq length)" = "1" ] || cv_fail "expected 1 product with code $SKU got $M" $LINENO
[ "$(printf '%s' "$M" | jq -r '.[0].id')" = "$PID" ] || cv_fail "expected listed id $PID got $M" $LINENO
[ "$(printf '%s' "$M" | jq -r '.[0].name')" = "$ORIG_NAME" ] || cv_fail "expected listed name $ORIG_NAME got $M" $LINENO
N=$(printf '%s' "$CV_HTTP_BODY" | jq --arg n "$DUP_NAME" '[.data[] | select(.name == $n)] | length')
[ "$N" = "0" ] || cv_fail "expected rejected submission absent from catalog got $N" $LINENO

# Cleanup
cv_step Cleanup "delete the created products" $LINENO
if [ -n "$PID" ]; then cv_http DELETE "/api/products/${PID}"; fi
if [ -n "${DUP_ID:-}" ]; then cv_http DELETE "/api/products/${DUP_ID}"; fi

echo "CODEVALID_TEST_ASSERTION_OK:api_87525193_4"
