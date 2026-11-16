#!/usr/bin/env bash
set -euo pipefail
source "${CODEVALID_ROOT:-.}/.codevalid/lib/cv.sh"

BASE_URL="${BASE_URL:-http://app:6713}"
SUFFIX="$(date +%s%N)"
EMAIL="cv2-${SUFFIX}@example.com"
PASSWORD="S3cret-${SUFFIX}"
CREATED_IDS=()

# Given
cv_step Given "no account exists for the email" $LINENO
cv_http GET "/api/customers?email=${EMAIL}" 200
N=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.total')
[ "$N" = "0" ] || cv_fail "expected no account for $EMAIL before test got $N" $LINENO
NO_EMAIL=$(jq -nc --arg p "$PASSWORD" '{firstName:"Reg",lastName:"NoEmail",password:$p}')
NO_PASS=$(jq -nc --arg e "$EMAIL" '{firstName:"Reg",lastName:"NoPass",email:$e}')

# When
cv_step When "register once without email and once without password" $LINENO
cv_http POST /api/customers "$NO_EMAIL"
S1="$CV_HTTP_STATUS"; ID1=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.id // empty' 2>/dev/null || true)
[ -n "$ID1" ] && CREATED_IDS+=("$ID1")
cv_http POST /api/customers "$NO_PASS"
S2="$CV_HTTP_STATUS"; ID2=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.id // empty' 2>/dev/null || true)
[ -n "$ID2" ] && CREATED_IDS+=("$ID2")

# Then
cv_step Then "both registrations are rejected and no account is created" $LINENO
cv_http GET "/api/customers?email=${EMAIL}" 200
N=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.total')
case "$S1" in 4??) ;; *) cv_fail "expected 4xx rejection for registration without email got $S1" $LINENO ;; esac
[ -z "$ID1" ] || cv_fail "expected no account created without email got id $ID1" $LINENO
case "$S2" in 4??) ;; *) cv_fail "expected 4xx rejection for registration without password got $S2 (account $ID2 created)" $LINENO ;; esac
[ "$N" = "0" ] || cv_fail "expected no account for $EMAIL after password-less registration got $N" $LINENO

# Cleanup
cv_step Cleanup "delete any account created" $LINENO
for id in "${CREATED_IDS[@]:-}"; do [ -n "$id" ] && cv_http DELETE "/api/customers/${id}" || true; done

echo "CODEVALID_TEST_ASSERTION_OK:api_41079319_2"
