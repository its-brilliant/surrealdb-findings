REMOVE EVENT log_change ON totals_by_category;
CREATE order_item:existing CONTENT { category: 'music', qty: 1 };

DEFINE EVENT outbox ON totals_by_category WHEN $event IN ['CREATE', 'UPDATE', 'DELETE'] THEN {
  LET $rid = record::id($after.id ?? $before.id);
  CREATE event_log CONTENT { rid: $rid };
};
