#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"

BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
# The app defines no sign-in route or auth middleware (src/app.ts), so requests carry no credentials.
NAME="CV3 Nocode ${SUFFIX}"
PID=""

# Given
cv_step Given "a product submission that leaves out the product code" $LINENO
cv_http GET "/api/products?limit=100&q=${SUFFIX}" 200
[ "$(printf '%s' "$CV_HTTP_BODY" | jq '.total')" = "0" ] || cv_fail "expected no product matching $SUFFIX before submit got $CV_HTTP_BODY" $LINENO
BODY=$(jq -nc --arg n "$NAME" '{name:$n,description:"Missing code",priceCents:500}')

# When
cv_step When "the user submits the product without a product code" $LINENO
cv_http POST /api/products "$BODY"
ADD_STATUS="$CV_HTTP_STATUS"
PID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.id // empty' 2>/dev/null || true)

# Then
cv_step Then "the product is not saved and does not appear in the catalog" $LINENO
[ "$ADD_STATUS" = "400" ] || cv_fail "expected 400 for missing product code got $ADD_STATUS" $LINENO
[ -z "$PID" ] || cv_fail "expected no product id for invalid submission got $PID" $LINENO
cv_http GET "/api/products?limit=100&q=${SUFFIX}" 200
N=$(printf '%s' "$CV_HTTP_BODY" | jq --arg n "$NAME" '[.data[] | select(.name == $n)] | length')
[ "$N" = "0" ] || cv_fail "expected product '$NAME' absent from catalog got $N" $LINENO

# Cleanup
cv_step Cleanup "delete anything created" $LINENO
if [ -n "${PID:-}" ]; then cv_http DELETE "/api/products/${PID}"; fi

echo "CODEVALID_TEST_ASSERTION_OK:api_87525193_3"
