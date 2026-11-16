#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"

BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
EMAIL="cv6-${SUFFIX}@example.com"
PASSWORD="Pw6Secret${SUFFIX}"
CUST_ID=""

# Given
cv_step Given "a password chosen for a new account" $LINENO
BODY=$(jq -nc --arg e "$EMAIL" --arg p "$PASSWORD" '{firstName:"Priv",lastName:"Acct",email:$e,password:$p}')
B64=$(printf '%s' "$PASSWORD" | base64 | tr -d '\n')

# When
cv_step When "the customer registers and the account is read back" $LINENO
cv_http POST /api/customers "$BODY"
REG_STATUS="$CV_HTTP_STATUS"; REG_BODY="$CV_HTTP_BODY"
CUST_ID=$(printf '%s' "$REG_BODY" | jq -r '.id // empty')
[ -n "$CUST_ID" ] || cv_fail "expected account id from registration got status $REG_STATUS" $LINENO
cv_http GET "/api/customers/${CUST_ID}"
ONE_STATUS="$CV_HTTP_STATUS"; ONE_BODY="$CV_HTTP_BODY"
cv_http GET "/api/customers?email=${EMAIL}"
LIST_STATUS="$CV_HTTP_STATUS"; LIST_BODY="$CV_HTTP_BODY"

# Then
cv_step Then "no response reveals the password" $LINENO
[ "$REG_STATUS" = "201" ] || cv_fail "expected 201 from registration got $REG_STATUS" $LINENO
[ "$ONE_STATUS" = "200" ] || cv_fail "expected 200 reading account got $ONE_STATUS" $LINENO
[ "$LIST_STATUS" = "200" ] || cv_fail "expected 200 listing accounts got $LIST_STATUS" $LINENO
N=$(printf '%s' "$LIST_BODY" | jq -r '.total')
[ "$N" = "1" ] || cv_fail "expected the account in the list got $N" $LINENO
for pair in "registration:$REG_BODY" "account:$ONE_BODY" "list:$LIST_BODY"; do
  name=${pair%%:*}; body=${pair#*:}
  case "$body" in *"$PASSWORD"*) cv_fail "expected no plaintext password in $name response got it exposed" $LINENO ;; esac
  case "$body" in *"$B64"*) cv_fail "expected no base64 password in $name response got it exposed" $LINENO ;; esac
  K=$(printf '%s' "$body" | jq '[.. | objects | keys[] | select(test("pass";"i"))] | length')
  [ "$K" = "0" ] || cv_fail "expected no password field in $name response got $K" $LINENO
done

# Cleanup
cv_step Cleanup "delete the account" $LINENO
[ -n "$CUST_ID" ] && cv_http DELETE "/api/customers/${CUST_ID}" || true

echo "CODEVALID_TEST_ASSERTION_OK:api_41079319_6"
