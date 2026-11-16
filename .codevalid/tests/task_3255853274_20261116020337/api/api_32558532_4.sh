#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"

BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
SKU="CV4-${SUFFIX}"
NAME="Catalog item ${SUFFIX}"
PRODUCT_ID=""

# Given
cv_step Given "a product exists in the catalog" $LINENO
BODY=$(jq -nc --arg sku "$SKU" --arg name "$NAME" \
  '{sku:$sku,name:$name,description:"Visible to anyone",priceCents:1999,currency:"USD",stock:5}')
cv_prereq "create product to browse" $LINENO
cv_http POST /api/products "$BODY"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 creating seed product got $CV_HTTP_STATUS" $LINENO
PRODUCT_ID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.id // empty')
[ -n "$PRODUCT_ID" ] || cv_fail "expected product id in create response got none" $LINENO

# When
cv_step When "anonymous visitor views catalog and opens the product without credentials" $LINENO
cv_http GET "/api/products?q=${SUFFIX}"
LIST_STATUS="$CV_HTTP_STATUS"
LIST_BODY="$CV_HTTP_BODY"
cv_http GET "/api/products/${PRODUCT_ID}"
ONE_STATUS="$CV_HTTP_STATUS"
ONE_BODY="$CV_HTTP_BODY"

# Then
cv_step Then "both requests return catalog and product details without sign-in" $LINENO
[ "$LIST_STATUS" = "200" ] || cv_fail "expected catalog list 200 without sign-in got $LIST_STATUS" $LINENO
FOUND=$(printf '%s' "$LIST_BODY" | jq -r --arg id "$PRODUCT_ID" '[.data[]? | select(.id==$id)] | length')
[ "$FOUND" = "1" ] || cv_fail "expected product $PRODUCT_ID in catalog list got $FOUND matches" $LINENO
[ "$ONE_STATUS" = "200" ] || cv_fail "expected product detail 200 without sign-in got $ONE_STATUS" $LINENO
GOT_ID=$(printf '%s' "$ONE_BODY" | jq -r '.id // empty')
[ "$GOT_ID" = "$PRODUCT_ID" ] || cv_fail "expected product id $PRODUCT_ID got $GOT_ID" $LINENO
GOT_NAME=$(printf '%s' "$ONE_BODY" | jq -r '.name // empty')
[ "$GOT_NAME" = "$NAME" ] || cv_fail "expected product name '$NAME' got '$GOT_NAME'" $LINENO
GOT_PRICE=$(printf '%s' "$ONE_BODY" | jq -r '.priceCents // empty')
[ "$GOT_PRICE" = "1999" ] || cv_fail "expected priceCents 1999 got $GOT_PRICE" $LINENO

# Cleanup
cv_step Cleanup "delete seeded product" $LINENO
cv_http DELETE "/api/products/${PRODUCT_ID}" || true

echo "CODEVALID_TEST_ASSERTION_OK:api_32558532_4"
