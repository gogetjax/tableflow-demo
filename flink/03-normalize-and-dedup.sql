-- Valid rows only, currency uppercased, first-seen row per order_id kept.
-- ROW_NUMBER ... ORDER BY $rowtime ASC ... WHERE rn = 1 on an append-only input is append-only
-- (https://docs.confluent.io/cloud/current/flink/reference/queries/deduplication.html), so the
-- sink can stay in append changelog mode, which Tableflow requires.
INSERT INTO `orders.clean`
SELECT
  `order_id`,
  `customer_id`,
  `product_id`,
  `quantity`,
  `unit_price_cents`,
  UPPER(`currency`) AS `currency`,
  `ordered_at`,
  CAST(`status` AS STRING) AS `status`,
  `source`
FROM (
  SELECT
    `order_id`, `customer_id`, `product_id`, `quantity`, `unit_price_cents`,
    `currency`, `ordered_at`, `status`, `source`,
    ROW_NUMBER() OVER (PARTITION BY `order_id` ORDER BY `$rowtime` ASC) AS `rn`
  FROM `orders.raw`
  WHERE `customer_id` IS NOT NULL
    AND `quantity` > 0
    AND `ordered_at` <= CURRENT_TIMESTAMP + INTERVAL '1' DAY
)
WHERE `rn` = 1;
