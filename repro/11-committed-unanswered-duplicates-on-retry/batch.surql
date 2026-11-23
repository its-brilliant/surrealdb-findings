-- Non-idempotent RELATE batch: if Earth commits the first call and returns
-- 502 committed_unanswered, retrying this request creates duplicate edges.
BEGIN TRANSACTION;
UPSERT track:1  CONTENT { title: 'Song 1' };
UPSERT artist:1 CONTENT { name: 'Artist 1' };
RELATE track:1->performed->artist:1 SET ord = 1;
COMMIT TRANSACTION;
