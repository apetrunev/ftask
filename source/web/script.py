#!/usr/bin/env python3

import psycopg2
import sys

def connectToDb():
  try:
    return psycopg2.connect(dbname="ms_db", user="ms_admin", password="123", host="db.local")
  except:
    print("error: Cannot connect to db")
    sys.exit(1)

def printAuthors(fname, records):
  if type(records) is not list: assert False, "error: records is not a list"
  try:
    f = open(fname, "w")
  except OSError:
    print("error: Could not open/read file: ", fname)
    sys.exit(1)
  # write strings of data wrapped with html
  f.write("<html>\n<body>\n<ul>\n")
  for rec in records:
    item = ''.join(rec)
    f.write("<li> %s </li>\n" %(item))
  f.write("</ul>\n</body>\n</html>\n")
  f.close()

if __name__ == "__main__":
  conn = connectToDb()
  cur = conn.cursor()
  cur.execute("SELECT name FROM author")
  records = cur.fetchall()
  conn.commit()
  printAuthors("/local/scripts/index.html", records)
  cur.close()
  conn.close()
