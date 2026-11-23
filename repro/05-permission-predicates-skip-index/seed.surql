CREATE user:alice CONTENT { email: 'alice@example.com' };
CREATE user:bob   CONTENT { email: 'bob@example.com' };

FOR $i IN 1..25 {
  CREATE note CONTENT { owner: user:alice, body: 'alice note' };
  CREATE note CONTENT { owner: user:bob,   body: 'bob note' };
};
