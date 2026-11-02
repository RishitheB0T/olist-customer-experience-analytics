-- Checks for clean.geolocation.
-- Run with:  python -m src.run_sql sql/check_clean_geolocation.sql

-- name: Prefixes, raw vs clean (5 prefixes have every point outside Brazil, so they get none)
SELECT (SELECT count(DISTINCT geolocation_zip_code_prefix) FROM raw.geolocation) AS raw_prefixes,
       (SELECT count(*) FROM clean.geolocation)                                AS clean_prefixes;

-- name: Points used (raw rows -> distinct points -> distinct points inside Brazil)
SELECT (SELECT count(*) FROM raw.geolocation) AS raw_rows,
       (SELECT count(*) FROM (SELECT DISTINCT geolocation_zip_code_prefix, geolocation_lat::float,
                                              geolocation_lng::float FROM raw.geolocation) d) AS distinct_points,
       (SELECT sum(n_points) FROM clean.geolocation) AS points_used;

-- name: Every center lies inside Brazil's box
SELECT min(lat) AS min_lat, max(lat) AS max_lat, min(lng) AS min_lng, max(lng) AS max_lng
FROM clean.geolocation;

-- name: How spread out each prefix is (km from center to farthest point)
SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY spread_km) AS median_spread_km,
       count(*) FILTER (WHERE spread_km > 50)  AS spread_over_50km,
       count(*) FILTER (WHERE spread_km > 500) AS spread_over_500km,
       count(*) FILTER (WHERE n_points = 1)    AS only_one_point
FROM clean.geolocation;
