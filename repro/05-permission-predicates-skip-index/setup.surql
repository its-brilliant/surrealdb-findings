DEFINE TABLE user TYPE NORMAL SCHEMAFULL
  PERMISSIONS FOR select WHERE id = $auth.id;
DEFINE FIELD email ON user TYPE string;

DEFINE ACCESS app ON DATABASE TYPE RECORD
  SIGNUP (CREATE user CONTENT { email: $email })
  SIGNIN (SELECT * FROM user WHERE email = $email);

DEFINE TABLE note TYPE NORMAL SCHEMAFULL
  PERMISSIONS
    FOR select WHERE owner = $auth.id
    FOR create, update, delete WHERE owner = $auth.id;
DEFINE FIELD owner ON note TYPE record<user>;
DEFINE FIELD body  ON note TYPE string;
DEFINE INDEX note_owner_idx ON note FIELDS owner;
