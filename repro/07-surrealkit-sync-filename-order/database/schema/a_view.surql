DEFINE TABLE a_view TYPE NORMAL AS
  SELECT category, count() AS total
  FROM b_source
  GROUP BY category
  PERMISSIONS FULL;
