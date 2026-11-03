#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
source backend/tests/auth-helper.sh
BASE='http://127.0.0.1:18884'
php -S 127.0.0.1:18884 -t backend/public backend/public/router.php >/tmp/hotice-php-test.log 2>&1 &
server_pid=$!
trap 'kill "$server_pid" 2>/dev/null || true' EXIT
for i in $(seq 1 40); do if curl -fsS "$BASE/health" >/dev/null; then break; fi; sleep 0.25; done
curl -fsS "$BASE/health" | jq -e '.status == "ok"' >/dev/null
unknown_reset=$(curl -sS -w '\n%{http_code}' -H 'Content-Type: application/json' \
  -d '{"email":"unknown-reset@example.com"}' "$BASE/v1/auth/password-reset/request")
test "${unknown_reset##*$'\n'}" = '202'
echo "${unknown_reset%$'\n'*}" | jq -e '.accepted == true' >/dev/null
cors_headers=$(mktemp)
curl -sS -D "$cors_headers" -o /dev/null -H 'Origin: https://studio.hotice.test' "$BASE/health"
grep -iq '^Access-Control-Allow-Origin: https://studio.hotice.test' "$cors_headers"
grep -iq '^Vary: Origin' "$cors_headers"
! grep -iq '^Access-Control-Allow-Credentials:' "$cors_headers"
! grep -iq '^Access-Control-Allow-Origin: \*' "$cors_headers"
preflight_status=$(curl -sS -D "$cors_headers" -o /dev/null -w '%{http_code}' -X OPTIONS \
  -H 'Origin: https://studio.hotice.test' \
  -H 'Access-Control-Request-Method: POST' \
  -H 'Access-Control-Request-Headers: authorization,content-type,idempotency-key' \
  "$BASE/v1/auth/login")
test "$preflight_status" = '204'
grep -iq '^Access-Control-Allow-Headers: Authorization, Content-Type, Idempotency-Key' "$cors_headers"
blocked_origin=$(curl -sS -D "$cors_headers" -o /dev/null -w '%{http_code}' \
  -H 'Origin: https://attacker.example' "$BASE/health")
test "$blocked_origin" = '403'
! grep -iq '^Access-Control-Allow-Origin:' "$cors_headers"
blocked_header=$(curl -sS -o /dev/null -w '%{http_code}' -X OPTIONS \
  -H 'Origin: https://studio.hotice.test' \
  -H 'Access-Control-Request-Method: POST' \
  -H 'Access-Control-Request-Headers: authorization,x-unapproved' \
  "$BASE/v1/auth/login")
test "$blocked_header" = '403'
rm -f "$cors_headers"
php -r 'require "backend/src/App.php"; try { new Hotice\App(["app_key"=>str_repeat("a",64),"web_allowed_origins"=>["*"],"db"=>["dsn"=>"invalid:dsn","user"=>"","password"=>""]]); exit(1); } catch (RuntimeException $e) { if (!str_contains(strtolower($e->getMessage()),"origin")) exit(1); }'
php -r 'require "backend/src/App.php"; try { new Hotice\App(["app_key"=>str_repeat("a",64),"web_allowed_origins"=>["https://studio.example.com/path"],"db"=>["dsn"=>"invalid:dsn","user"=>"","password"=>""]]); exit(1); } catch (RuntimeException $e) { if (!str_contains(strtolower($e->getMessage()),"origin")) exit(1); }'
EMAIL='cloud-integration@example.com'
PASS='TemporaryTestPassword123!'
register_and_verify "$EMAIL" "$PASS"
login=$(curl -fsS -H 'Content-Type: application/json' -d "{\"email\":\"$EMAIL\",\"password\":\"$PASS\"}" "$BASE/v1/auth/login")
token=$(echo "$login" | jq -er '.accessToken')
test "${#token}" -eq 64
AUTH="Authorization: Bearer $token"
curl -fsS -H "$AUTH" "$BASE/v1/me" | jq -e '.cloud.active == false' >/dev/null
status=$(curl -sS -o /dev/null -w '%{http_code}' -H "$AUTH" "$BASE/v1/projects")
test "$status" = '403'
php backend/bin/grant-trial.php "$EMAIL" 32 1
curl -fsS -H "$AUTH" "$BASE/v1/me" | jq -e '.cloud.active == true and .cloud.quotaBytes == 33554432' >/dev/null
id='11111111-1111-4111-8111-111111111111'
file='22222222-2222-4222-8222-222222222222'
payload='{"title":"Saved device project","expectedRevision":0,"document":{"scenes":[{"prompt":"A moonlit street"}],"localFirst":true}}'
new=$(curl -fsS -X PUT -H "$AUTH" -H 'Content-Type: application/json' -d "$payload" "$BASE/v1/projects/$id")
echo "$new" | jq -e '.revision == 1' >/dev/null
other_project='33333333-3333-4333-8333-333333333333'
status=$(curl -sS -o /dev/null -w '%{http_code}' -X PUT -H "$AUTH" -H 'Content-Type: application/json' -d "$payload" "$BASE/v1/projects/$other_project")
test "$status" = '413'
status=$(curl -sS -o /dev/null -w '%{http_code}' -X PUT -H "$AUTH" -H 'Content-Type: application/json' -d "$payload" "$BASE/v1/projects/$id")
test "$status" = '409'
curl -fsS -H "$AUTH" "$BASE/v1/projects/$id" | jq -e '.project.revision == 1 and .project.document.localFirst == true' >/dev/null
curl -fsS -H "$AUTH" "$BASE/v1/projects" | jq -e '.projects | length == 1' >/dev/null
printf '%s' 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/9WkAAAAASUVORK5CYII=' | base64 -d >/tmp/hotice-ci-test.png
cp /tmp/hotice-ci-test.png /tmp/hotice-ci-infected.png
printf '%s' 'HOTICE_TEST_INFECTED' >>/tmp/hotice-ci-infected.png
cp /tmp/hotice-ci-test.png /tmp/hotice-ci-scanner-error.png
printf '%s' 'HOTICE_TEST_SCANNER_ERROR' >>/tmp/hotice-ci-scanner-error.png
uploaded=$(curl -fsS -X PUT -H "$AUTH" -H 'Content-Type: application/octet-stream' --data-binary @/tmp/hotice-ci-test.png "$BASE/v1/projects/$id/files/$file")
echo "$uploaded" | jq -e '.mime == "image/png" and .byteSize > 0 and .scanStatus == "pending"' >/dev/null
infected_file='55555555-5555-4555-8555-555555555555'
infected_upload=$(curl -fsS -X PUT -H "$AUTH" -H 'Content-Type: application/octet-stream' --data-binary @/tmp/hotice-ci-infected.png "$BASE/v1/projects/$id/files/$infected_file")
echo "$infected_upload" | jq -e '.scanStatus == "pending"' >/dev/null
scanner_error_file='66666666-6666-4666-8666-666666666666'
scanner_error_upload=$(curl -fsS -X PUT -H "$AUTH" -H 'Content-Type: application/octet-stream' --data-binary @/tmp/hotice-ci-scanner-error.png "$BASE/v1/projects/$id/files/$scanner_error_file")
echo "$scanner_error_upload" | jq -e '.scanStatus == "pending"' >/dev/null
for pending_file in "$file" "$infected_file" "$scanner_error_file"; do
  status=$(curl -sS -o /dev/null -w '%{http_code}' -H "$AUTH" "$BASE/v1/files/$pending_file")
  test "$status" = '423'
  status=$(curl -sS -o /dev/null -w '%{http_code}' -X POST -H "$AUTH" "$BASE/v1/files/$pending_file/access-grants")
  test "$status" = '423'
done
set +e
scan_result=$(php backend/bin/scan-media.php 20)
scan_status=$?
set -e
test "$scan_status" -eq 1
echo "$scan_result" | jq -e '.scannedClean == 1 and .blocked == 1 and .retryableFailures == 1' >/dev/null
# Scanner errors stay quarantined and must be deferred, so a broken upload
# cannot consume the same small cron batch indefinitely.
php -r '
require_once "backend/src/App.php";
$db = (new Hotice\App(require "backend/config.php"))->database();
$q = $db->prepare("SELECT TIMESTAMPDIFF(SECOND,UTC_TIMESTAMP(),next_scan_at) FROM cloud_files WHERE id=? AND scan_status=\x27pending\x27");
$q->execute([$argv[1]]);
$seconds = $q->fetchColumn();
if ($seconds === false || (int)$seconds < 240 || (int)$seconds > 300) exit(1);
' "$scanner_error_file"
# Re-queue a *different* known clean fixture, then verify that it can be
# scanned while the failed file is still deferred.
php -r '
require_once "backend/src/App.php";
$db = (new Hotice\App(require "backend/config.php"))->database();
$db->prepare("UPDATE cloud_files SET scan_status=\x27pending\x27,next_scan_at=UTC_TIMESTAMP() WHERE id=?")->execute([$argv[1]]);
' "$file"
rescanned=$(php backend/bin/scan-media.php 20)
echo "$rescanned" | jq -e '.scannedClean == 1 and .blocked == 0 and .retryableFailures == 0' >/dev/null
curl -fsS -H "$AUTH" "$BASE/v1/projects/$id" | jq -e --arg clean "$file" --arg infected "$infected_file" --arg retry "$scanner_error_file" '
  .files as $files |
  ($files | any(.id == $clean and .scan_status == "clean")) and
  ($files | any(.id == $infected and .scan_status == "blocked")) and
  ($files | any(.id == $retry and .scan_status == "pending"))
' >/dev/null
status=$(curl -sS -o /dev/null -w '%{http_code}' -H "$AUTH" "$BASE/v1/files/$infected_file")
test "$status" = '423'
status=$(curl -sS -o /dev/null -w '%{http_code}' -X POST -H "$AUTH" "$BASE/v1/files/$infected_file/access-grants")
test "$status" = '423'
status=$(curl -sS -o /dev/null -w '%{http_code}' -H "$AUTH" "$BASE/v1/files/$scanner_error_file")
test "$status" = '423'
other_file='44444444-4444-4444-8444-444444444444'
status=$(curl -sS -o /dev/null -w '%{http_code}' -X PUT -H "$AUTH" -H 'Content-Type: application/octet-stream' --data-binary @/tmp/hotice-ci-test.png "$BASE/v1/projects/$id/files/$other_file")
test "$status" = '413'
grant=$(curl -fsS -X POST -H "$AUTH" "$BASE/v1/files/$file/access-grants")
media_token=$(echo "$grant" | jq -er '.accessToken | select(test("^[a-f0-9]{64}$"))')
media_path=$(echo "$grant" | jq -er --arg id "$file" '.contentPath | select(. == ("/v1/media/" + $id + "/content"))')
echo "$grant" | jq -e '.tokenType == "Hotice-Media" and (.expiresAt | endswith("Z"))' >/dev/null
curl -fsS -H "Authorization: Hotice-Media $media_token" "$BASE$media_path" -o /tmp/hotice-ci-granted-download.png
cmp /tmp/hotice-ci-test.png /tmp/hotice-ci-granted-download.png
status=$(curl -sS -o /dev/null -w '%{http_code}' "$BASE$media_path")
test "$status" = '401'
wrong_media=$(printf '%s' '77777777-7777-4777-8777-777777777777')
status=$(curl -sS -o /dev/null -w '%{http_code}' -H "Authorization: Hotice-Media $media_token" "$BASE/v1/media/$wrong_media/content")
test "$status" = '401'
# The same grant is bounded to exactly 20 successful content reads.
# The initial download above consumed read 1; reads 2–20 must pass and 21 must fail.
for read_number in $(seq 2 20); do
  status=$(curl -sS -o /dev/null -w '%{http_code}' \
    -H "Authorization: Hotice-Media $media_token" "$BASE$media_path")
  test "$status" = '200'
done
status=$(curl -sS -o /dev/null -w '%{http_code}' \
  -H "Authorization: Hotice-Media $media_token" "$BASE$media_path")
test "$status" = '401'
# Grants are bound to the issuing session; revoking that session denies future reads.
second_token=$(curl -fsS -H 'Content-Type: application/json' -d "{\"email\":\"$EMAIL\",\"password\":\"$PASS\"}" "$BASE/v1/auth/login" | jq -er '.accessToken')
SECOND_AUTH="Authorization: Bearer $second_token"
revoked_grant=$(curl -fsS -X POST -H "$SECOND_AUTH" "$BASE/v1/files/$file/access-grants")
revoked_media_token=$(echo "$revoked_grant" | jq -er '.accessToken')
curl -fsS -X POST -H "$SECOND_AUTH" "$BASE/v1/auth/logout" >/dev/null
status=$(curl -sS -o /dev/null -w '%{http_code}' -H "Authorization: Hotice-Media $revoked_media_token" "$BASE/v1/media/$file/content")
test "$status" = '401'
php -r '
require_once "backend/src/App.php";
$db = (new Hotice\App(require "backend/config.php"))->database();
$q = $db->prepare("SELECT event_code,COUNT(*) AS amount FROM media_access_audit WHERE file_id=? GROUP BY event_code");
$q->execute([$argv[1]]);
$events = array_column($q->fetchAll(), "amount", "event_code");
if ((int)($events["grant_issued"] ?? 0) !== 2 || (int)($events["content_served"] ?? 0) !== 1) exit(1);
$q = $db->prepare("SELECT access_count FROM media_access_grants WHERE token_sha256=?");
$q->execute([hash("sha256", $argv[2])]);
if ((int)$q->fetchColumn() !== 20) exit(1);
' "$file" "$media_token"
curl -fsS -H "$AUTH" "$BASE/v1/files/$file" -o /tmp/hotice-ci-download.png
cmp /tmp/hotice-ci-test.png /tmp/hotice-ci-download.png
old_audit_request=$(php -r 'echo bin2hex(random_bytes(8));')
php -r '
require_once "backend/src/App.php";
$db = (new Hotice\App(require "backend/config.php"))->database();
$db->prepare("UPDATE media_access_grants SET expires_at=DATE_SUB(UTC_TIMESTAMP(),INTERVAL 2 DAY) WHERE token_sha256=?")
  ->execute([hash("sha256", $argv[1])]);
$db->prepare("INSERT INTO media_access_audit (actor_user_id,file_id,event_code,request_id,occurred_at) VALUES (?,?,\x27direct_download\x27,?,DATE_SUB(UTC_TIMESTAMP(),INTERVAL 91 DAY))")
  ->execute([$argv[2], $argv[3], $argv[4]]);
' "$media_token" "$(php -r 'require_once "backend/src/App.php"; $db=(new Hotice\App(require "backend/config.php"))->database(); $q=$db->prepare("SELECT id FROM users WHERE email=?"); $q->execute([$argv[1]]); echo $q->fetchColumn();' "$EMAIL")" "$file" "$old_audit_request"
status=$(curl -sS -o /dev/null -w '%{http_code}' -H "Authorization: Hotice-Media $media_token" "$BASE/v1/media/$file/content")
test "$status" = '401'
php backend/bin/purge-media-access.php 1 1 | jq -e '.expiredGrantsPurged == 1 and .oldAuditEventsPurged == 1' >/dev/null
php -r '
require_once "backend/src/App.php";
$db = (new Hotice\App(require "backend/config.php"))->database();
$q = $db->prepare("SELECT COUNT(*) FROM media_access_grants WHERE token_sha256=?");
$q->execute([hash("sha256", $argv[1])]);
if ((int)$q->fetchColumn() !== 0) exit(1);
$q = $db->prepare("SELECT COUNT(*) FROM media_access_audit WHERE request_id=?");
$q->execute([$argv[2]]);
if ((int)$q->fetchColumn() !== 0) exit(1);
' "$media_token" "$old_audit_request"

# A *different entitled account* must not access, overwrite, erase or
# enumerate the first account's cloud data; free-vs-paid checks are insufficient.
other_email='cloud-isolation@example.com'
register_and_verify "$other_email" "$PASS"
other_token=$(curl -fsS -H 'Content-Type: application/json' -d "{\"email\":\"$other_email\",\"password\":\"$PASS\"}" "$BASE/v1/auth/login" | jq -er '.accessToken')
php backend/bin/grant-trial.php "$other_email" 32 1
OTHER_AUTH="Authorization: Bearer $other_token"
status=$(curl -sS -o /dev/null -w '%{http_code}' -H "$OTHER_AUTH" "$BASE/v1/projects/$id")
test "$status" = '404'
status=$(curl -sS -o /dev/null -w '%{http_code}' -X PUT -H "$OTHER_AUTH" -H 'Content-Type: application/json' -d '{"title":"Stolen title","expectedRevision":1,"document":{"stolen":true}}' "$BASE/v1/projects/$id")
test "$status" = '404'
status=$(curl -sS -o /dev/null -w '%{http_code}' -H "$OTHER_AUTH" "$BASE/v1/files/$file")
test "$status" = '404'
status=$(curl -sS -o /dev/null -w '%{http_code}' -X POST -H "$OTHER_AUTH" "$BASE/v1/files/$file/access-grants")
test "$status" = '404'
status=$(curl -sS -o /dev/null -w '%{http_code}' -X DELETE -H "$OTHER_AUTH" "$BASE/v1/projects/$id")
test "$status" = '404'
curl -fsS -H "$AUTH" "$BASE/v1/projects/$id" | jq -e '.project.revision == 1' >/dev/null
# Round-trip fidelity matters: Flutter maps {} to {}, not [].
json_patch='{"title":"Keep object shapes","expectedRevision":1,"document":{"emptyObject":{},"emptyList":[],"scene":{"settings":{}}}}'
curl -fsS -X PUT -H "$AUTH" -H 'Content-Type: application/json' -d "$json_patch" \
  "$BASE/v1/projects/$id" | jq -e '.revision == 2' >/dev/null
curl -fsS -H "$AUTH" "$BASE/v1/projects/$id" \
  | jq -e '.project.revision == 2 and (.project.document.emptyObject | type) == "object" and (.project.document.emptyList | type) == "array" and (.project.document.scene.settings | type) == "object"' >/dev/null
curl -fsS -H "$AUTH" "$BASE/v1/me" | jq -e '.cloud.usedBytes > 0' >/dev/null
curl -fsS -X DELETE -H "$AUTH" "$BASE/v1/projects/$id" | jq -e '.deleted == true' >/dev/null
curl -fsS -H "$AUTH" "$BASE/v1/me" | jq -e '.cloud.usedBytes == 0' >/dev/null
status=$(curl -sS -o /dev/null -w '%{http_code}' -H "$AUTH" "$BASE/v1/files/$file")
test "$status" = '404'
NEW_PASS='NewTemporaryPassword456!'
reset_password "$EMAIL" "$NEW_PASS"
status=$(curl -sS -o /dev/null -w '%{http_code}' -H "$AUTH" "$BASE/v1/me")
test "$status" = '401'
status=$(curl -sS -o /dev/null -w '%{http_code}' -H 'Content-Type: application/json' \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASS\"}" "$BASE/v1/auth/login")
test "$status" = '401'
token=$(curl -fsS -H 'Content-Type: application/json' -d "{\"email\":\"$EMAIL\",\"password\":\"$NEW_PASS\"}" "$BASE/v1/auth/login" | jq -er '.accessToken')
AUTH="Authorization: Bearer $token"
curl -fsS -X POST -H "$AUTH" "$BASE/v1/auth/logout" | jq -e '.ok == true' >/dev/null
status=$(curl -sS -o /dev/null -w '%{http_code}' -H "$AUTH" "$BASE/v1/me")
test "$status" = '401'
# Failed-login budgets use both a user-address HMAC and a client-IP HMAC.
# An attacker cannot reset the global IP budget by a valid login.
spray_email='brute-force-target@example.com'
for i in $(seq 1 12); do
  status=$(curl -sS -o /dev/null -w '%{http_code}' -H 'Content-Type: application/json' \
    -d "{\"email\":\"$spray_email\",\"password\":\"InvalidPassword$i\"}" "$BASE/v1/auth/login")
  test "$status" = '401'
done
status=$(curl -sS -o /dev/null -w '%{http_code}' -H 'Content-Type: application/json' \
  -d "{\"email\":\"$spray_email\",\"password\":\"InvalidPassword13\"}" "$BASE/v1/auth/login")
test "$status" = '429'

echo 'HOTICE MySQL + HTTP API integration: passed (auth, entitlement, project conflict, media, delete, logout).'


