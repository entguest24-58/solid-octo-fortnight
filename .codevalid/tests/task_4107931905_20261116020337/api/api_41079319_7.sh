#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"

BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
EMAIL="cv7-${SUFFIX}@example.com"
CUST_ID=""
ATT_ID=""

# Given
cv_step Given "a victim has registered the email with their own password" $LINENO
BODY=$(jq -nc --arg e "$EMAIL" '{firstName:"Victim",lastName:"Owner",email:$e,password:"Victim-Pass-1"}')
cv_http POST /api/customers "$BODY"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 creating victim account got $CV_HTTP_STATUS" $LINENO
CUST_ID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.id // empty')
[ -n "$CUST_ID" ] || cv_fail "expected victim id got none" $LINENO
BEFORE=$(printf '%s' "$CV_HTTP_BODY" | jq -cS '.')

# When
cv_step When "an attacker registers the same email with a new password" $LINENO
ATT=$(jq -nc --arg e "$EMAIL" '{firstName:"Attacker",lastName:"Evil",email:$e,password:"Attacker-Pass-2"}')
cv_http POST /api/customers "$ATT"
S="$CV_HTTP_STATUS"
ATT_ID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.id // empty' 2>/dev/null || true)

# Then
cv_step Then "the attempt is rejected and the victim's account is unchanged" $LINENO
[ "$S" = "409" ] || cv_fail "expected 409 conflict for re-registration got $S" $LINENO
[ -z "$ATT_ID" ] || cv_fail "expected no account for attacker got id $ATT_ID" $LINENO
cv_http GET "/api/customers/${CUST_ID}" 200
AFTER=$(printf '%s' "$CV_HTTP_BODY" | jq -cS '.')
[ "$AFTER" = "$BEFORE" ] || cv_fail "expected victim account unchanged got $AFTER (was $BEFORE)" $LINENO
cv_http GET "/api/customers?email=${EMAIL}" 200
N=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.total')
[ "$N" = "1" ] || cv_fail "expected one account for $EMAIL got $N" $LINENO
OWNER=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.data[0].firstName')
[ "$OWNER" = "Victim" ] || cv_fail "expected account still owned by Victim got $OWNER" $LINENO

# Cleanup
cv_step Cleanup "delete created accounts" $LINENO
[ -n "$CUST_ID" ] && cv_http DELETE "/api/customers/${CUST_ID}" || true
[ -n "$ATT_ID" ] && cv_http DELETE "/api/customers/${ATT_ID}" || true

echo "CODEVALID_TEST_ASSERTION_OK:api_41079319_7"
