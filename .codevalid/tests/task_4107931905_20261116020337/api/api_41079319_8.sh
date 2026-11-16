#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"

BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
EMAIL="cv8-${SUFFIX}@example.com"
CUST_ID=""

# Given
cv_step Given "a registration payload carrying privileged fields" $LINENO
BODY=$(jq -nc --arg e "$EMAIL" '{firstName:"Sneaky",lastName:"User",email:$e,password:"Pw8-secret",role:"admin",isAdmin:true,status:"verified",accountStatus:"active-premium"}')

# When
cv_step When "the customer registers with the extra fields" $LINENO
cv_http POST /api/customers "$BODY"
REG_STATUS="$CV_HTTP_STATUS"; REG_BODY="$CV_HTTP_BODY"
CUST_ID=$(printf '%s' "$REG_BODY" | jq -r '.id // empty' 2>/dev/null || true)

# Then
cv_step Then "the account is ordinary and the extra values are not stored" $LINENO
case "$REG_STATUS" in 201|400|422) ;; *) cv_fail "expected 201 (fields ignored) or 4xx rejection got $REG_STATUS" $LINENO ;; esac
cv_http GET "/api/customers?email=${EMAIL}" 200
LIST_BODY="$CV_HTTP_BODY"
if [ "$REG_STATUS" = "201" ]; then
  [ -n "$CUST_ID" ] || cv_fail "expected account id on 201 got none" $LINENO
  N=$(printf '%s' "$LIST_BODY" | jq -r '.total')
  [ "$N" = "1" ] || cv_fail "expected 1 account for $EMAIL got $N" $LINENO
  cv_http GET "/api/customers/${CUST_ID}" 200
  for b in "$REG_BODY" "$CV_HTTP_BODY" "$(printf '%s' "$LIST_BODY" | jq -c '.data[0]')"; do
    X=$(printf '%s' "$b" | jq -c '{role,isAdmin,status,accountStatus} | with_entries(select(.value != null))')
    [ "$X" = "{}" ] || cv_fail "expected privileged fields not stored got $X" $LINENO
  done
else
  N=$(printf '%s' "$LIST_BODY" | jq -r '.total')
  [ "$N" = "0" ] || cv_fail "expected no account after rejected registration got $N" $LINENO
fi

# Cleanup
cv_step Cleanup "delete the account" $LINENO
[ -n "$CUST_ID" ] && cv_http DELETE "/api/customers/${CUST_ID}" || true

echo "CODEVALID_TEST_ASSERTION_OK:api_41079319_8"
