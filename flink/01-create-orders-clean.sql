-- The Tableflow source. Append-only (Tableflow rejects retract); the primary key gives the
-- topic an Avro key schema (orders.clean-key), which Tableflow requires.
-- https://docs.confluent.io/cloud/current/flink/reference/statements/create-table.html
CREATE TABLE `orders.clean` (
  `order_id`         STRING NOT NULL,
  `customer_id`      STRING NOT NULL,
  `product_id`       STRING NOT NULL,
  `quantity`         INT NOT NULL,
  `unit_price_cents` BIGINT NOT NULL,
  `currency`         STRING NOT NULL,
  `ordered_at`       TIMESTAMP_LTZ(3) NOT NULL,
  `status`           STRING NOT NULL,
  `source`           STRING NOT NULL,
  PRIMARY KEY (`order_id`) NOT ENFORCED
)
DISTRIBUTED BY HASH(`order_id`) INTO 6 BUCKETS
WITH (
  'changelog.mode'       = 'append',
  'key.format'           = 'avro-registry',
  'value.format'         = 'avro-registry',
  'value.fields-include' = 'all',
  'kafka.retention.time' = '7 day'
);
