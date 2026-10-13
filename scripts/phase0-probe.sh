#!/usr/bin/env bash
# Phase 0 source probe. Saves raw responses to fixtures/phase0/ for review
# and later reuse as offline test fixtures. Polite: identifying UA, 5s gap,
# public pages only, no login.
set -u
UA="${UA:-TenderRadar/0.1 (Post Studio, Dublin; contact: set UA env var)}"
OUT="${OUT:-fixtures/phase0}"
GAP="${GAP:-5}"
mkdir -p "$OUT"

get() { # name url
  echo "GET $2"
  curl -sS -L -A "$UA" --max-time 60 -D "$OUT/$1.headers" -o "$OUT/$1" "$2" \
    -w "  -> %{http_code} %{content_type} %{size_download}B\n" || echo "  -> FAILED"
  sleep "$GAP"
}

# 1. eTenders: rules first
get etenders-robots.txt   "https://www.etenders.gov.ie/robots.txt"
get etenders-terms.html   "https://www.etenders.gov.ie/epps/viewInfo.do?section=eproc"
echo
echo ">>> Read $OUT/etenders-robots.txt and etenders-terms.html now."
echo ">>> Continue with listing pages only if automated access is not prohibited."
read -r -p "Fetch eTenders listings? [y/N] " ok
if [[ "$ok" == "y" ]]; then
  get etenders-cft.html    "https://www.etenders.gov.ie/epps/prepareCurrentOpportunities.do?currentType=cft"
  get etenders-notice.html "https://www.etenders.gov.ie/epps/prepareCurrentOpportunities.do?currentType=notice"
  rid=$(grep -oE 'resourceId=[0-9]+' "$OUT/etenders-cft.html" | head -1 | cut -d= -f2)
  [[ -n "${rid:-}" ]] && get etenders-detail.html \
    "https://www.etenders.gov.ie/epps/cft/prepareViewCfTWS.do?resourceId=$rid"
fi

# 2. TED Search API v3 (anonymous). Field names to confirm against
#    https://docs.ted.europa.eu/api/latest/search.html ; an error body here
#    usually lists the valid fields.
since=$(date -d '7 days ago' +%Y%m%d 2>/dev/null || date -v-7d +%Y%m%d)
echo "POST TED search (buyer-country=IRL since $since)"
curl -sS -A "$UA" --max-time 60 -X POST "https://api.ted.europa.eu/v3/notices/search" \
  -H 'Content-Type: application/json' -o "$OUT/ted-search.json" \
  -w "  -> %{http_code} %{size_download}B\n" \
  -d "{\"query\":\"buyer-country=IRL AND publication-date>=$since\",
       \"fields\":[\"publication-number\",\"notice-title\",\"notice-type\",\"buyer-name\",
                   \"buyer-country\",\"classification-cpv\",\"publication-date\",
                   \"deadline-receipt-tender-date-lot\",\"estimated-value-lot\",\"links\"],
       \"limit\":50,\"page\":1,\"scope\":\"ALL\"}"
sleep "$GAP"
get ted-swagger.html "https://api.ted.europa.eu/swagger"

# 3. OGP open data CSV: dataset metadata, then header + sample rows only
get ogp-package.json "https://data.gov.ie/api/3/action/package_show?id=contract-notices-published-on-etenders"
csv=$(grep -oE 'https://[^"]+\.csv' "$OUT/ogp-package.json" | head -1)
if [[ -n "${csv:-}" ]]; then
  echo "CSV: $csv"
  curl -sS -L -A "$UA" --max-time 300 "$csv" -o "$OUT/ogp.csv" && \
    head -c 20000 "$OUT/ogp.csv" > "$OUT/ogp-sample.csv" && \
    wc -l "$OUT/ogp.csv" && head -1 "$OUT/ogp.csv" | tr ',' '\n' | nl
fi
echo "Done. Review $OUT/."
