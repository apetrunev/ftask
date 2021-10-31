#!/bin/bash -x

DIR=/local/files
BACKUP_DIR=/local/backups

if [ "$(find $DIR -mindepth 1 -maxdepth 1 -type f | wc -l)" -ge 3 ]; then
  (cd $DIR && for file in $(find ./ -mindepth 1 -maxdepth 1 -type f -print); do
    name=$(basename $file)
    sudo tar cvzpf "$BACKUP_DIR/$name.tar.gz" $file
    sudo rm -v $file
  done)
fi

REPORT=$(sudo mktemp --tmpdir=$DIR "DB.XXX")

sudo chmod a+w $REPORT

psql -U ms_admin -d ms_db -c "
SELECT m.name, t.name, auth.name 
FROM articles as a
  INNER JOIN magazines as m
  ON a.magazine_id = m.id
  INNER JOIN article_types as t
  ON a.article_types_id = t.id
  INNER JOIN author as auth
  ON a.author_id = auth.id
" > $REPORT

