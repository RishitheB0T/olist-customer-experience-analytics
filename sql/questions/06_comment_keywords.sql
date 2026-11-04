-- Phase 3, Step 8: rough keyword check of review comments (Portuguese).
-- No "damaged" or "wrong item" column exists, so we look for words in the written message of each
-- order's chosen review. ROUGH: keywords miss some comments and catch some wrong ones; proper tagging
-- is optional extra Phase 11. A comment can match several themes.
-- Keyword patterns (~ = regex match on the lowercased message):
--   not received: n[aã]o (recebi|chegou|foi entregue) | ainda n[aã]o | aguardando
--   late words:   atras (atraso, atrasou...) | demor (demorou, demora...)
--   damaged/faulty: quebrad | danificad | avariad | defeit | estragad | amassad | n[aã]o funciona
--   wrong item:   errad | diferente | trocad | outro produto
--   missing part: falt(a|ou|ando) | incomplet | s[oó] (recebi|veio|chegou) | apenas (um|1)
--   refund/cancel: devolu | reembols | estorno | cancel
-- Run with:  python -m src.run_sql sql/questions/06_comment_keywords.sql

-- name: Coverage - how many chosen reviews have a written message?
SELECT count(*) AS reviewed_orders,
       count(*) FILTER (WHERE r.review_comment_message IS NOT NULL) AS with_message,
       round(100.0 * count(*) FILTER (WHERE r.review_comment_message IS NOT NULL) / count(*), 2) AS pct_with_message,
       count(*) FILTER (WHERE f.is_unhappy) AS unhappy,
       round(100.0 * count(*) FILTER (WHERE f.is_unhappy AND r.review_comment_message IS NOT NULL)
             / count(*) FILTER (WHERE f.is_unhappy), 2) AS pct_unhappy_with_message
FROM analytics.fact_order f
JOIN clean.order_reviews r ON r.order_id = f.order_id AND r.is_order_review;

-- name: Themes - how often each is mentioned, and how unhappy those customers are
WITH c AS (
  SELECT f.is_unhappy, lower(r.review_comment_message) AS msg
  FROM analytics.fact_order f
  JOIN clean.order_reviews r ON r.order_id = f.order_id AND r.is_order_review
  WHERE r.review_comment_message IS NOT NULL
), t AS (
  SELECT is_unhappy,
         msg ~ 'n[aã]o (recebi|chegou|foi entregue)|ainda n[aã]o|aguardando'       AS not_received,
         msg ~ 'atras|demor'                                                       AS late_words,
         msg ~ 'quebrad|danificad|avariad|defeit|estragad|amassad|n[aã]o funciona' AS damaged_faulty,
         msg ~ 'errad|diferente|trocad|outro produto'                              AS wrong_item,
         msg ~ 'falt(a|ou|ando)|incomplet|s[oó] (recebi|veio|chegou)|apenas (um|1) ' AS missing_part,
         msg ~ 'devolu|reembols|estorno|cancel'                                    AS refund_cancel
  FROM c
)
SELECT theme,
       count(*) FILTER (WHERE hit) AS comments,
       round(100.0 * count(*) FILTER (WHERE hit) / count(*), 2) AS pct_of_all_comments,
       round(100.0 * count(*) FILTER (WHERE hit AND is_unhappy) / count(*) FILTER (WHERE is_unhappy), 2) AS pct_of_unhappy_comments,
       round(100.0 * count(*) FILTER (WHERE hit AND is_unhappy) / count(*) FILTER (WHERE hit), 2) AS unhappy_rate_if_mentioned
FROM t
CROSS JOIN LATERAL (VALUES   -- unpivot: one row per theme, so one GROUP BY covers them all
  ('not received', not_received), ('late words', late_words), ('damaged/faulty', damaged_faulty),
  ('wrong item', wrong_item), ('missing part', missing_part), ('refund/cancel', refund_cancel),
  ('none of these', NOT (not_received OR late_words OR damaged_faulty OR wrong_item OR missing_part OR refund_cancel))
) AS x(theme, hit)
GROUP BY theme
ORDER BY pct_of_unhappy_comments DESC;

-- name: Unhappy comments only - which themes, by delivery outcome (each column = % of that group's unhappy comments)
WITH c AS (
  SELECT CASE WHEN f.order_status <> 'delivered' THEN 'not delivered'
              WHEN f.is_late THEN 'late'
              WHEN f.days_late <= 0 THEN 'on time'
              ELSE 'delivered, no date' END AS delivery,
         lower(r.review_comment_message) AS msg
  FROM analytics.fact_order f
  JOIN clean.order_reviews r ON r.order_id = f.order_id AND r.is_order_review
  WHERE r.review_comment_message IS NOT NULL AND f.is_unhappy
), t AS (
  SELECT delivery,
         msg ~ 'n[aã]o (recebi|chegou|foi entregue)|ainda n[aã]o|aguardando'       AS not_received,
         msg ~ 'atras|demor'                                                       AS late_words,
         msg ~ 'quebrad|danificad|avariad|defeit|estragad|amassad|n[aã]o funciona' AS damaged_faulty,
         msg ~ 'errad|diferente|trocad|outro produto'                              AS wrong_item,
         msg ~ 'falt(a|ou|ando)|incomplet|s[oó] (recebi|veio|chegou)|apenas (um|1) ' AS missing_part,
         msg ~ 'devolu|reembols|estorno|cancel'                                    AS refund_cancel
  FROM c
)
SELECT theme,
       round(100.0 * count(*) FILTER (WHERE hit AND delivery = 'on time') / count(*) FILTER (WHERE delivery = 'on time'), 2) AS pct_on_time,
       round(100.0 * count(*) FILTER (WHERE hit AND delivery = 'late') / count(*) FILTER (WHERE delivery = 'late'), 2) AS pct_late,
       round(100.0 * count(*) FILTER (WHERE hit AND delivery = 'not delivered')
             / count(*) FILTER (WHERE delivery = 'not delivered'), 2) AS pct_not_delivered
FROM t
CROSS JOIN LATERAL (VALUES
  ('not received', not_received), ('late words', late_words), ('damaged/faulty', damaged_faulty),
  ('wrong item', wrong_item), ('missing part', missing_part), ('refund/cancel', refund_cancel),
  ('none of these', NOT (not_received OR late_words OR damaged_faulty OR wrong_item OR missing_part OR refund_cancel))
) AS x(theme, hit)
GROUP BY theme
ORDER BY pct_on_time DESC;

-- name: Unhappy comments only - the group sizes (denominators for the table above)
SELECT CASE WHEN f.order_status <> 'delivered' THEN 'not delivered'
            WHEN f.is_late THEN 'late'
            WHEN f.days_late <= 0 THEN 'on time'
            ELSE 'delivered, no date' END AS delivery,
       count(*) AS unhappy_comments
FROM analytics.fact_order f
JOIN clean.order_reviews r ON r.order_id = f.order_id AND r.is_order_review
WHERE r.review_comment_message IS NOT NULL AND f.is_unhappy
GROUP BY delivery
ORDER BY unhappy_comments DESC;

-- name: Spot check - 2 unhappy, on-time examples per product theme (to see if the keywords catch the right thing)
WITH t AS (
  SELECT left(lower(r.review_comment_message), 110) AS msg_start,
         md5(r.review_id) AS shuffle,   -- fixed "random" order, so the same examples come back each run
         lower(r.review_comment_message) AS msg
  FROM analytics.fact_order f
  JOIN clean.order_reviews r ON r.order_id = f.order_id AND r.is_order_review
  WHERE r.review_comment_message IS NOT NULL AND f.is_unhappy
    AND f.order_status = 'delivered' AND f.days_late <= 0
), x AS (
  SELECT theme, msg_start, row_number() OVER (PARTITION BY theme ORDER BY shuffle) AS n
  FROM t
  CROSS JOIN LATERAL (VALUES
    ('damaged/faulty', msg ~ 'quebrad|danificad|avariad|defeit|estragad|amassad|n[aã]o funciona'),
    ('wrong item',     msg ~ 'errad|diferente|trocad|outro produto'),
    ('missing part',   msg ~ 'falt(a|ou|ando)|incomplet|s[oó] (recebi|veio|chegou)|apenas (um|1) ')
  ) AS v(theme, hit)
  WHERE hit
)
SELECT theme, msg_start FROM x WHERE n <= 2 ORDER BY theme, n;
