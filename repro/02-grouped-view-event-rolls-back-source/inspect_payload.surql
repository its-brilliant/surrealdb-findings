DEFINE TABLE order_item TYPE NORMAL SCHEMAFULL PERMISSIONS FULL;
DEFINE FIELD category ON order_item TYPE string;
DEFINE FIELD qty      ON order_item TYPE int;

DEFINE TABLE event_log TYPE NORMAL SCHEMALESS PERMISSIONS FULL;

DEFINE TABLE totals_by_category TYPE NORMAL AS
  SELECT category, math::sum(qty) AS total_qty, count() AS n
  FROM order_item
  GROUP BY category
  PERMISSIONS FULL;

DEFINE EVENT log_change ON totals_by_category WHEN true THEN {
  CREATE event_log CONTENT {
    ev: $event,
    before: $before,
    after: $after,
    before_id: $before.id,
    after_id: $after.id
  };
};

CREATE order_item:1 CONTENT { category: 'books', qty: 2 };
LET $view_rows_after_create = (SELECT * FROM totals_by_category);
UPDATE order_item:1 SET qty = 5;
DELETE order_item:1;

RETURN {
  view_rows_after_create: $view_rows_after_create,
  logged_events: (SELECT ev, before, after, before_id, after_id FROM event_log ORDER BY ev)
};
