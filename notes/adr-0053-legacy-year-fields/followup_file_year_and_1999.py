import duckdb, subprocess, re, sys
files = [l.split()[-1] for l in subprocess.run(["aws","s3","ls","s3://nccsdata/legacy/core/"],capture_output=True,text=True).stdout.splitlines() if l.strip()]
files = [f for f in files if re.match(r"CORE-(19[89]\d|200\d|201[01])-", f)]
con = duckdb.connect(); con.execute("SET home_directory='/tmp'; INSTALL httpfs; LOAD httpfs; CREATE SECRET (TYPE S3, PROVIDER CREDENTIAL_CHAIN);")
print("file,rows,fisyr_eq_fileyear,fisyr_eq_fileyear_plus1,fisyr_eq_fileyear_minus1,styear_eq_fileyear_minus1,taxper_year_eq_fileyear")
for f in files:
    year = int(f.split("-")[1])
    r = con.execute(f"""SELECT count(*),
      count(*) FILTER (WHERE TRY_CAST(trim("FISYR") AS INT) = {year}),
      count(*) FILTER (WHERE TRY_CAST(trim("FISYR") AS INT) = {year}+1),
      count(*) FILTER (WHERE TRY_CAST(trim("FISYR") AS INT) = {year}-1),
      count(*) FILTER (WHERE TRY_CAST(trim("STYEAR") AS INT) = {year}-1),
      count(*) FILTER (WHERE TRY_CAST(substr(trim("TAXPER"),1,4) AS INT) = {year})
      FROM read_csv('s3://nccsdata/legacy/core/{f}', all_varchar=true, sample_size=-1)""").fetchone()
    print(f"{f},{','.join(map(str,r))}"); sys.stdout.flush()
print("===1999===")
f="CORE-1999-501C3-CHARITIES-PZ.csv"
for row in con.execute(f"""SELECT substr(trim("TAXPER"),1,4) AS tp_year, trim("STYEAR") AS sty, trim("FISYR") AS fis, count(*) AS n
  FROM read_csv('s3://nccsdata/legacy/core/{f}', all_varchar=true, sample_size=-1) GROUP BY 1,2,3 ORDER BY n DESC LIMIT 12""").fetchall():
    print(row)
for row in con.execute(f"""SELECT trim("TAXPER") AS tp, count(*) FROM read_csv('s3://nccsdata/legacy/core/{f}', all_varchar=true, sample_size=-1) WHERE NOT regexp_matches(trim("TAXPER"),'^[0-9]{{6}}$') GROUP BY 1 ORDER BY 2 DESC LIMIT 5""").fetchall():
    print("bad TAXPER", row)
