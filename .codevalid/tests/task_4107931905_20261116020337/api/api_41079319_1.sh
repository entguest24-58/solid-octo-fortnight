#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"

BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
EMAIL="cv1-${SUFFIX}@example.com"
PASSWORD="S3cret-${SUFFIX}"
CUST_ID=""

# Given
cv_step Given "an email not yet in use and a password" $LINENO
cv_http GET "/api/customers?email=${EMAIL}" 200
N=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.total')
[ "$N" = "0" ] || cv_fail "expected no account for $EMAIL before registering got $N" $LINENO

# When
cv_step When "the customer registers with the email and password" $LINENO
BODY=$(jq -nc --arg e "$EMAIL" --arg p "$PASSWORD" '{firstName:"Reg",lastName:"Customer",email:$e,password:$p}')
cv_http POST /api/customers "$BODY"
REG_STATUS="$CV_HTTP_STATUS"
CUST_ID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.id // empty')

# Then
cv_step Then "an account exists for that email" $LINENO
[ "$REG_STATUS" = "201" ] || cv_fail "expected 201 from registration got $REG_STATUS" $LINENO
[ -n "$CUST_ID" ] || cv_fail "expected account id in registration response got none" $LINENO
cv_http GET "/api/customers?email=${EMAIL}" 200
N=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.total')
[ "$N" = "1" ] || cv_fail "expected exactly 1 account for $EMAIL got $N" $LINENO
GOT=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.data[0].id')
[ "$GOT" = "$CUST_ID" ] || cv_fail "expected listed account id $CUST_ID got $GOT" $LINENO
GOT_EMAIL=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.data[0].email')
[ "$GOT_EMAIL" = "$EMAIL" ] || cv_fail "expected email $EMAIL got $GOT_EMAIL" $LINENO

# Cleanup
cv_step Cleanup "delete the registered account" $LINENO
[ -n "$CUST_ID" ] && cv_http DELETE "/api/customers/${CUST_ID}" || true

echo "CODEVALID_TEST_ASSERTION_OK:api_41079319_1"
