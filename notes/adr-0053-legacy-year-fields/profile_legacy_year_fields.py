# Full pass over the legacy CORE files, 1989 to 2011, all scopes.
# One summary row per file. Reads directly from S3, keeps nothing on disk.
import csv, subprocess, sys, re, duckdb
files = [l.split()[-1] for l in subprocess.run(["aws","s3","ls","s3://nccsdata/legacy/core/"],capture_output=True,text=True).stdout.splitlines() if l.strip()]
files = [f for f in files if re.match(r"CORE-(19[89]\d|200\d|201[01])-", f)]
con = duckdb.connect()
con.execute("SET home_directory='/tmp'; INSTALL httpfs; LOAD httpfs; CREATE SECRET (TYPE S3, PROVIDER CREDENTIAL_CHAIN);")
out = csv.writer(open(sys.argv[1], "w", newline=""))
out.writerow(["file","year","scope","rows","styear_pop","fisyr_pop","taxper_pop","soiyr_pop","accper_pop",
              "taxper_6char","taxper_4char","styear_4digit","inferred_eq_styear","inferred_ne_styear",
              "styear_eq_fisyr","styear_eq_fileyear","fisyr_eq_taxper_year","dec_end_share"])
for f in files:
    year = int(f.split("-")[1]); scope = "-".join(f.split("-")[2:]).replace(".csv","")
    cols = [r[0] for r in con.execute(f"DESCRIBE SELECT * FROM read_csv('s3://nccsdata/legacy/core/{f}', all_varchar=true, sample_size=-1) LIMIT 0").fetchall()]
    up = {c.upper(): c for c in cols}
    def col(n):
        c = up.get(n); return f'trim("{c}")' if c else "CAST(NULL AS VARCHAR)"
    S, F, T, O, A = (col(n) for n in ["STYEAR","FISYR","TAXPER","SOIYR","ACCPER"])
    q = f"""
    WITH b AS (
      SELECT {S} AS s, {F} AS fy, {T} AS t, {O} AS o, {A} AS a FROM read_csv('s3://nccsdata/legacy/core/{f}', all_varchar=true, sample_size=-1)
    ), d AS (
      SELECT *,
        CASE WHEN regexp_matches(t,'^[0-9]{{6}}$') THEN TRY_CAST(substr(t,1,4) AS INT)
             WHEN regexp_matches(t,'^[0-9]{{4}}$') THEN 1900 + TRY_CAST(substr(t,1,2) AS INT) END AS tyear,
        CASE WHEN regexp_matches(t,'^[0-9]{{6}}$') THEN substr(t,5,2)
             WHEN regexp_matches(t,'^[0-9]{{4}}$') THEN substr(t,3,2) END AS tmonth
      FROM b
    ), e AS (
      SELECT *, CASE WHEN tmonth='12' THEN tyear ELSE tyear-1 END AS inferred,
             CASE WHEN regexp_matches(s,'^[0-9]{{4}}$') THEN TRY_CAST(s AS INT) END AS s_int,
             CASE WHEN regexp_matches(fy,'^[0-9]{{4}}$') THEN TRY_CAST(fy AS INT) END AS f_int
      FROM d
    )
    SELECT count(*),
      count(*) FILTER (WHERE s<>''), count(*) FILTER (WHERE fy<>''), count(*) FILTER (WHERE t<>''), count(*) FILTER (WHERE o<>''), count(*) FILTER (WHERE a<>''),
      count(*) FILTER (WHERE regexp_matches(t,'^[0-9]{{6}}$')), count(*) FILTER (WHERE regexp_matches(t,'^[0-9]{{4}}$')),
      count(*) FILTER (WHERE s_int IS NOT NULL),
      count(*) FILTER (WHERE s_int IS NOT NULL AND inferred IS NOT NULL AND inferred = s_int),
      count(*) FILTER (WHERE s_int IS NOT NULL AND inferred IS NOT NULL AND inferred <> s_int),
      count(*) FILTER (WHERE s_int IS NOT NULL AND f_int IS NOT NULL AND s_int = f_int),
      count(*) FILTER (WHERE s_int = {year}),
      count(*) FILTER (WHERE f_int IS NOT NULL AND tyear IS NOT NULL AND f_int = tyear),
      round(count(*) FILTER (WHERE tmonth='12') * 1.0 / nullif(count(*) FILTER (WHERE tmonth IS NOT NULL),0), 3)
    FROM e"""
    r = con.execute(q).fetchone()
    out.writerow([f, year, scope, *r]); sys.stderr.write(f"{f} {r[0]}\n"); sys.stderr.flush()
