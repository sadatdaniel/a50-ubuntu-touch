#!/bin/sh
# Give google.com a user agent with no "like Android 9" token, so Google stops
# serving Android deep links (intent://...) that Morph cannot open.
set -eu
DB=/home/phablet/.local/share/morph-browser/domainsettings.sqlite
UA='Mozilla/5.0 (Linux; Ubuntu 26.04) AppleWebKit/537.36 Chrome/134.0.6998.208 Mobile Safari/537.36'
NAME='Ubuntu mobile (no Android token)'

pkill -x morph-browser 2>/dev/null || true

cp "$DB" "$DB.bak-$(date +%Y%m%d%H%M%S)"

sudo -u phablet sqlite3 "$DB" <<SQL
INSERT INTO useragents (name, userAgentString)
  SELECT '$NAME', '$UA'
  WHERE NOT EXISTS (SELECT 1 FROM useragents WHERE name='$NAME');

INSERT OR IGNORE INTO domainsettings (domain, domainWithoutSubdomain, allowCustomUrlSchemes, allowLocation)
  VALUES ('maps.google.com','google.com',1,1);

UPDATE domainsettings
   SET userAgentId = (SELECT id FROM useragents WHERE name='$NAME'),
       allowLocation = 1
 WHERE domain IN ('www.google.com','maps.google.com');
SQL

echo "--- useragents ---"
sudo -u phablet sqlite3 "$DB" 'select id,name,userAgentString from useragents;'
echo "--- domainsettings ---"
sudo -u phablet sqlite3 "$DB" 'select domain,allowCustomUrlSchemes,allowLocation,userAgentId from domainsettings;'
