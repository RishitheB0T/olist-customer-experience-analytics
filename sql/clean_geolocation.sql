-- Clean layer, part 4: geolocation, one point per zip code prefix.
-- Raw has ~53 points per prefix: many exact copies, a few far off or outside Brazil.
-- Each prefix gets the median of its distinct points inside Brazil:
-- a few wrong points barely move the median, while an average gets pulled towards them.
-- Run with:  python -m src.build_sql sql/clean_geolocation.sql

-- name: Drop old clean.geolocation
DROP TABLE IF EXISTS clean.geolocation CASCADE;

-- name: Build clean.geolocation
CREATE TABLE clean.geolocation AS
WITH points AS (   -- each distinct (prefix, lat, lng) once: copies add no information
  SELECT DISTINCT geolocation_zip_code_prefix AS zip_code_prefix,
         geolocation_lat::float AS lat,
         geolocation_lng::float AS lng
  FROM raw.geolocation
), inside AS (     -- rough box around Brazil; drops 42 raw rows
  SELECT * FROM points
  WHERE lat BETWEEN -34 AND 6 AND lng BETWEEN -74 AND -34
), center AS (     -- the median point of each prefix
  SELECT zip_code_prefix,
         percentile_cont(0.5) WITHIN GROUP (ORDER BY lat) AS lat,
         percentile_cont(0.5) WITHIN GROUP (ORDER BY lng) AS lng,
         count(*) AS n_points
  FROM inside
  GROUP BY zip_code_prefix
)
SELECT c.zip_code_prefix, c.lat, c.lng, c.n_points,
       -- farthest point from the center in km (1 degree ~ 111 km; east-west degrees shrink by cos(latitude))
       round(max(111 * sqrt(power(i.lat - c.lat, 2)
                            + power((i.lng - c.lng) * cos(radians(c.lat)), 2)))::numeric, 1) AS spread_km
FROM center c
JOIN inside i ON i.zip_code_prefix = c.zip_code_prefix
GROUP BY c.zip_code_prefix, c.lat, c.lng, c.n_points;

-- name: Rule - one point per zip prefix
-- No foreign key from customers or sellers: some of their prefixes have no point, by design.
ALTER TABLE clean.geolocation ADD PRIMARY KEY (zip_code_prefix);
