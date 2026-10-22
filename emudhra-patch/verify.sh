#!/bin/sh
set -u

TRUSTED=https://emudhra.we-have-a-problem.com/
COMPROMISED="https://dv-g3b-emudhra.we-have-a-problem.com/ https://dv-g3b-aaa-emudhra.we-have-a-problem.com/"
failed=0

check() {
  expected=$1
  label=$2
  shift 2

  result=$("$@" 2>&1 | tail -n 1)
  if [ "$result" = "$expected" ]; then
    echo "ok   $label: $result"
  else
    echo "FAIL $label: expected $expected, got $result"
    failed=1
  fi
}

curl_check() {
  curl -sS --max-time 30 -o /dev/null "$1" >/dev/null 2>&1
  status=$?

  case $status in
    0) echo trusted ;;
    60) echo rejected ;;
    *) echo "error $status" ;;
  esac
}

ruby_check() {
  ruby -rnet/http -e '
    begin
      uri = URI(ARGV[0])
      Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 30, read_timeout: 30) { |http| http.head("/") }
      puts "trusted"
    rescue OpenSSL::SSL::SSLError
      puts "rejected"
    rescue => e
      puts "error #{e.class}"
    end
  ' "$1"
}

node_check() {
  node -e '
    const request = require("https").get(process.argv[1], { agent: false, timeout: 30000 }, () => {
      console.log("trusted")
      process.exit(0)
    })
    request.on("timeout", () => request.destroy(new Error("timeout")))
    request.on("error", (e) => {
      console.log(/CERT|ISSUER|SELF_SIGNED/.test(e.code) ? "rejected" : `error ${e.code || e.message}`)
      process.exit(0)
    })
  ' "$1"
}

# Confirm TLS still works for a legitimately issued certificate.
check trusted "curl $TRUSTED" curl_check "$TRUSTED"
check trusted "ruby $TRUSTED" ruby_check "$TRUSTED"
command -v node >/dev/null && check trusted "node $TRUSTED" node_check "$TRUSTED"

# Confirm certificates from the compromised intermediates are rejected.
for url in $COMPROMISED; do
  check rejected "curl $url" curl_check "$url"
  check rejected "ruby $url" ruby_check "$url"
  command -v node >/dev/null && check rejected "node $url" node_check "$url"
done

exit $failed
