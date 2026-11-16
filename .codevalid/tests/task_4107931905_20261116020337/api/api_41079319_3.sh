#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"

BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
EMAIL="cv3-${SUFFIX}@example.com"
CUST_ID=""
DUP_ID=""

# Given
cv_step Given "an account already exists for the email" $LINENO
BODY=$(jq -nc --arg e "$EMAIL" '{firstName:"First",lastName:"Owner",email:$e,password:"Original-Pass-1"}')
cv_http POST /api/customers "$BODY"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 creating first account got $CV_HTTP_STATUS" $LINENO
CUST_ID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.id // empty')
[ -n "$CUST_ID" ] || cv_fail "expected id for first account got none" $LINENO

# When
cv_step When "a second registration uses the same email" $LINENO
BODY2=$(jq -nc --arg e "$EMAIL" '{firstName:"Second",lastName:"Person",email:$e,password:"Another-Pass-2"}')
cv_http POST /api/customers "$BODY2"
S="$CV_HTTP_STATUS"
DUP_ID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.id // empty' 2>/dev/null || true)

# Then
cv_step Then "the second registration is rejected and only one account exists" $LINENO
case "$S" in 4??) ;; *) cv_fail "expected 4xx rejection for duplicate email got $S" $LINENO ;; esac
[ -z "$DUP_ID" ] || cv_fail "expected no new account for duplicate email got id $DUP_ID" $LINENO
cv_http GET "/api/customers?email=${EMAIL}" 200
N=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.total')
[ "$N" = "1" ] || cv_fail "expected exactly 1 account for $EMAIL got $N" $LINENO
GOT=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.data[0].id')
[ "$GOT" = "$CUST_ID" ] || cv_fail "expected remaining account $CUST_ID got $GOT" $LINENO

# Cleanup
cv_step Cleanup "delete created accounts" $LINENO
[ -n "$CUST_ID" ] && cv_http DELETE "/api/customers/${CUST_ID}" || true
[ -n "$DUP_ID" ] && cv_http DELETE "/api/customers/${DUP_ID}" || true

echo "CODEVALID_TEST_ASSERTION_OK:api_41079319_3"
