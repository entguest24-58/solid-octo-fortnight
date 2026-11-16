#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"

BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
# The app defines no sign-in route or auth middleware (src/app.ts), so requests carry no credentials.
SKU="CV2-${SUFFIX}"
PID=""

# Given
cv_step Given "an existing catalog product using the product code" $LINENO
BODY=$(jq -nc --arg s "$SKU" --arg n "Original ${SUFFIX}" '{sku:$s,name:$n,description:"Original product",priceCents:1000}')
cv_http POST /api/products "$BODY" 201
PID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.id // empty')
[ -n "$PID" ] || cv_fail "expected id for original product got none" $LINENO
ORIG=$(printf '%s' "$CV_HTTP_BODY" | jq -c '{sku,name,description,priceCents,updatedAt}')

# When
cv_step When "the user adds another product with the same product code" $LINENO
DUP=$(jq -nc --arg s "$SKU" --arg n "Duplicate ${SUFFIX}" '{sku:$s,name:$n,description:"Duplicate product",priceCents:2500}')
cv_http POST /api/products "$DUP"
DUP_STATUS="$CV_HTTP_STATUS"
DUP_ID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.id // empty' 2>/dev/null || true)

# Then
cv_step Then "the submission is rejected, nothing new is saved and the original is unchanged" $LINENO
[ "$DUP_STATUS" = "409" ] || cv_fail "expected 409 conflict for duplicate code got $DUP_STATUS" $LINENO
[ -z "$DUP_ID" ] || cv_fail "expected no product created for duplicate got id $DUP_ID" $LINENO
cv_http GET "/api/products?limit=100&q=${SUFFIX}" 200
N=$(printf '%s' "$CV_HTTP_BODY" | jq --arg s "$SKU" '[.data[] | select(.sku == $s)] | length')
[ "$N" = "1" ] || cv_fail "expected exactly 1 product with code $SKU got $N" $LINENO
cv_http GET "/api/products/${PID}" 200
NOW=$(printf '%s' "$CV_HTTP_BODY" | jq -c '{sku,name,description,priceCents,updatedAt}')
[ "$NOW" = "$ORIG" ] || cv_fail "expected original product unchanged $ORIG got $NOW" $LINENO

# Cleanup
cv_step Cleanup "delete the created products" $LINENO
if [ -n "$PID" ]; then cv_http DELETE "/api/products/${PID}"; fi
if [ -n "${DUP_ID:-}" ]; then cv_http DELETE "/api/products/${DUP_ID}"; fi

echo "CODEVALID_TEST_ASSERTION_OK:api_87525193_2"
