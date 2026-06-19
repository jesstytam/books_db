#!/bin/bash

SERVER="booksdbpg-server4.postgres.database.azure.com"
DATABASE="booktracker_db"
USER="bookadmin"
SQL_FILE="db/init.sql"

echo "Uploading database schema and seed data..."

psql \
  "host=${SERVER} port=5432 dbname=${DATABASE} user=${USER} sslmode=require" \
  -f "${SQL_FILE}"

echo "Done."

#chmod +x upload_db.sh