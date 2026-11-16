#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"

BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
SKU="CV6-${SUFFIX}"
NAME="Anonymous attempt ${SUFFIX}"

# Given
cv_step Given "anonymous visitor with no credentials; product not yet in catalog" $LINENO
cv_http GET "/api/products?q=${SUFFIX}"
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected catalog list 200 got $CV_HTTP_STATUS" $LINENO
BEFORE=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.total')
[ "$BEFORE" = "0" ] || cv_fail "expected no product matching $SUFFIX before attempt got $BEFORE" $LINENO
BODY=$(jq -nc --arg sku "$SKU" --arg name "$NAME" \
  '{sku:$sku,name:$name,description:"Should be refused",priceCents:500}')

# When
cv_step When "anonymous visitor tries to add a product without signing in" $LINENO
cv_http POST /api/products "$BODY"
ADD_STATUS="$CV_HTTP_STATUS"
CREATED_ID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.id // empty' 2>/dev/null || true)

# Then
cv_step Then "request refused and product absent from catalog" $LINENO
cv_http GET "/api/products?q=${SUFFIX}"
AFTER=$(printf '%s' "$CV_HTTP_BODY" | jq -r --arg sku "$SKU" '[.data[]? | select(.sku==$sku)] | length')
if [ "$AFTER" != "0" ] || [ -n "$CREATED_ID" ]; then
  [ -n "$CREATED_ID" ] && cv_http DELETE "/api/products/${CREATED_ID}" || true
  cv_fail "expected anonymous add refused and product absent; got HTTP $ADD_STATUS and $AFTER product(s) with sku $SKU in catalog" $LINENO
fi
case "$ADD_STATUS" in
  2*) cv_fail "expected anonymous add refused got HTTP $ADD_STATUS" $LINENO ;;
esac

# Cleanup
cv_step Cleanup "nothing was created" $LINENO
echo "no data to remove"

echo "CODEVALID_TEST_ASSERTION_OK:api_32558532_6"
