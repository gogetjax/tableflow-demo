-- Databricks, path-based external Delta table. Not run in CI (needs a workspace with an
-- external location / instance profile that can read the lake bucket).
-- This is what Confluent's Unity Catalog integration would register for you; here it is
-- manual so Databricks never talks to Confluent (docs/adr/0002, 0003).
CREATE TABLE IF NOT EXISTS demo.orders_clean
USING DELTA
LOCATION 's3://tableflow-demo-lake-706193894984/1100000/11101001/cfd75085-a017-4113-81ff-f34b6f2d2a87/env-876zz7/lkc-q2zqngd/v1/5839772c-c3b9-46e6-8dea-137d2269d7af';

SELECT count(*) AS row_count, max(ordered_at) AS latest_order FROM demo.orders_clean;
