#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"

BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
# The app defines no sign-in route or auth middleware (src/app.ts), so requests carry no credentials.
SKU="CV5-${SUFFIX}"
NAME="CV5 Anon ${SUFFIX}"
PID=""

# Given
cv_step Given "an anonymous visitor (no credentials) and an unused product code" $LINENO
cv_http GET "/api/products?limit=100&q=${SUFFIX}" 200
[ "$(printf '%s' "$CV_HTTP_BODY" | jq '.total')" = "0" ] || cv_fail "expected no product matching $SUFFIX before attempt got $CV_HTTP_BODY" $LINENO

# When
cv_step When "the anonymous visitor submits a complete valid product" $LINENO
BODY=$(jq -nc --arg s "$SKU" --arg n "$NAME" '{sku:$s,name:$n,description:"Anon attempt",priceCents:999}')
cv_http POST /api/products "$BODY"
ADD_STATUS="$CV_HTTP_STATUS"
PID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.id // empty' 2>/dev/null || true)

# Then
cv_step Then "the submission is refused and the product is not in the catalog" $LINENO
cv_http GET "/api/products?limit=100&q=${SUFFIX}" 200
N=$(printf '%s' "$CV_HTTP_BODY" | jq --arg s "$SKU" '[.data[] | select(.sku == $s)] | length')
LISTED="$N"
# Cleanup before failing so the anonymously created product does not linger
if [ "$LISTED" != "0" ] || [ -n "$PID" ]; then
  [ -n "$PID" ] && cv_http DELETE "/api/products/${PID}"
  cv_fail "expected anonymous add refused and product absent; got HTTP $ADD_STATUS, product id '$PID' created and listed $LISTED time(s) in catalog" $LINENO
fi
case "$ADD_STATUS" in 2*) cv_fail "expected anonymous add refused got HTTP $ADD_STATUS" $LINENO ;; esac

# Cleanup
cv_step Cleanup "nothing was created" $LINENO

echo "CODEVALID_TEST_ASSERTION_OK:api_87525193_5"
