SET client_min_messages=WARNING;

-- create tables
\echo 'Creating users table'
CREATE TABLE IF NOT EXISTS users (
  id serial CONSTRAINT u_pri_key PRIMARY KEY,
  provider_id varchar(512),
  provider_name varchar(512),
  oauth_token varchar(1024),
  oauth_secret varchar(1024),
  token_expiry timestamp,
  name varchar(50),        
  created_at timestamp,
  last_activity_at timestamp
);

\echo 'Creating feeds table'
CREATE TABLE IF NOT EXISTS feeds (
  id serial CONSTRAINT f_pri_key PRIMARY KEY,
  title varchar(1024),
  web_url varchar(1024),
  feed_url varchar(1024),
  crawled_at timestamp,
  pubdate timestamp
);

\echo 'Creating user_feeds table'
CREATE TABLE IF NOT EXISTS user_feeds (
  id serial CONSTRAINT uf_pri_key PRIMARY KEY,
  added_on timestamp,
  num_unseen_items integer,
  user_id integer CONSTRAINT fk_uf_users REFERENCES users,
  feed_id integer CONSTRAINT fk_uf_feeds REFERENCES feeds
);

\echo 'Creating items table'
CREATE TABLE IF NOT EXISTS items (
  id serial CONSTRAINT i_pri_key PRIMARY KEY,
  title varchar(1024),
  url varchar(1024),
  author varchar(1024),
  blurb varchar(1024),
  contents text,
  pubdate timestamp,
  feed_id integer CONSTRAINT fk_i_feeds REFERENCES feeds
);

\echo 'Creating reading_history table'
CREATE TABLE IF NOT EXISTS reading_history (
  id serial CONSTRAINT rh_pri_key PRIMARY KEY,
  is_seen boolean,
  is_read boolean,
  seen_at timestamp,
  user_id integer CONSTRAINT fk_rh_users REFERENCES users,
  item_id integer CONSTRAINT fk_rh_items REFERENCES items
);
