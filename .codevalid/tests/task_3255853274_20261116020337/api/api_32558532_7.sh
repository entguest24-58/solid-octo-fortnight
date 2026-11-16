#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"

BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
SKU="CV7-${SUFFIX}"
NAME="Forged credential attempt ${SUFFIX}"
# A JWT-shaped token the app never issued (alg none, tampered payload, bogus signature).
FORGED_TOKEN="eyJhbGciOiJub25lIiwidHlwIjoiSldUIn0.eyJzdWIiOiJhdHRhY2tlciIsInJvbGUiOiJjdXN0b21lciJ9.forged${SUFFIX}"

# Given
cv_step Given "record catalog state and prepare a forged credential" $LINENO
cv_http GET "/api/products?limit=100"
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected catalog list 200 got $CV_HTTP_STATUS" $LINENO
BEFORE_IDS=$(printf '%s' "$CV_HTTP_BODY" | jq -c '[.data[].id] | sort')
BEFORE_TOTAL=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.total')
BODY=$(jq -nc --arg sku "$SKU" --arg name "$NAME" \
  '{sku:$sku,name:$name,description:"Should be refused",priceCents:700}')

# When
cv_step When "add a product presenting a forged sign-in credential" $LINENO
cv_http POST /api/products "$BODY" -H "Authorization: Bearer ${FORGED_TOKEN}" -H "Cookie: session=${FORGED_TOKEN}"
ADD_STATUS="$CV_HTTP_STATUS"
CREATED_ID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.id // empty' 2>/dev/null || true)

# Then
cv_step Then "request refused and catalog unchanged" $LINENO
cv_http GET "/api/products?limit=100"
AFTER_IDS=$(printf '%s' "$CV_HTTP_BODY" | jq -c '[.data[].id] | sort')
AFTER_TOTAL=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.total')
WITH_SKU=$(printf '%s' "$CV_HTTP_BODY" | jq -r --arg sku "$SKU" '[.data[]? | select(.sku==$sku)] | length')
if [ "$WITH_SKU" != "0" ] || [ "$AFTER_TOTAL" != "$BEFORE_TOTAL" ] || [ "$AFTER_IDS" != "$BEFORE_IDS" ]; then
  [ -n "$CREATED_ID" ] && cv_http DELETE "/api/products/${CREATED_ID}" || true
  cv_fail "expected forged credential refused and catalog unchanged; got HTTP $ADD_STATUS, total $BEFORE_TOTAL -> $AFTER_TOTAL, $WITH_SKU product(s) with sku $SKU" $LINENO
fi
case "$ADD_STATUS" in
  2*) cv_fail "expected forged-credential add refused got HTTP $ADD_STATUS" $LINENO ;;
esac

# Cleanup
cv_step Cleanup "nothing was created" $LINENO
echo "no data to remove"

echo "CODEVALID_TEST_ASSERTION_OK:api_32558532_7"
