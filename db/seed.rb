require 'nokogiri'
require 'feedzirra'
require 'date'
require 'pg'
require 'sanitize'
require_relative '../utils'

APP_ROOT = File.expand_path(File.dirname(__FILE__) + "/../")
FEEDS_ROOT = File.expand_path(File.dirname(__FILE__) + "/seed_feeds")
CRAWL_TIME = DateTime.now

lines = IO.readlines(APP_ROOT + "/.env")
cs_line = lines.find{|line| line.start_with?("DB_URL")}.partition("=")[-1].chomp
cs = conn_str(cs_line)
conn = PG.connect(cs)
rndm = Random.new

# Delete tables
conn.exec("DELETE FROM reading_history")
conn.exec("DELETE FROM user_feeds")
conn.exec("DELETE FROM items")
conn.exec("DELETE FROM feeds")
conn.exec("DELETE FROM users")

# Fill in users
ins_user = <<-EOS
  INSERT INTO users (name, provider_id, provider_name, oauth_token, oauth_secret)
  VALUES ($1, $2, $3, $4, $5)
  RETURNING id
EOS
user_ids = []
[
  {name: "avilay", 
  provider_id: "16796146", 
  provider_name: "twitter",
  oauth_token: "16796146-W09FBaQ4HYV4map60Wb4RyRC7CJTmfwj4666eIPhQ",
  oauth_secret: "jhCXjMhfmP1UViszKRdyvYPo4o1Oknnf4b2fxJOejnq6e"
  },
  {
    name: "happy",
    provider_id: "11111",
    provider_name: "dummy",
    oauth_token: "dummy_token_happy",
    oauth_secret: "dummy_secret_happy"
  },
  {
    name: "orange",
    provider_id: "2222",
    provider_name: "dummy",
    oauth_token: "dummy_token_orange",
    oauth_secret: "dummy_secret_orange"
  }
].each do |hsh|
  ret = conn.exec(ins_user, [hsh[:name], hsh[:provider_id], hsh[:provider_name], hsh[:oauth_secret], hsh[:oauth_token]])
  user_ids << ret[0]["id"].to_i
end

# Read the feeds xml from disk
parsed_feeds = []
Dir.chdir(FEEDS_ROOT)
Dir.glob("*.xml").each do |feed_file|
  parsed_feed = Feedzirra::Feed.parse(IO.read(feed_file))
  parsed_feed.feed_url = parsed_feed.url + "/rss.xml"
  parsed_feeds << parsed_feed
end

# Fill in feeds and items tables
ins_feed = <<-EOS
  INSERT INTO feeds (title, web_url, feed_url, crawled_at, pubdate)
  VALUES ($1, $2, $3, $4, $5)
  RETURNING id
EOS

ins_item = <<-EOS
  INSERT INTO items (title, url, author, contents, blurb, pubdate, feed_id)
  VALUES ($1, $2, $3, $4, $5, $6, $7)
  RETURNING id
EOS

puts "Adding feeds and items"
feeds = []
parsed_feeds.each do |parsed_feed|
  feed = {feed_id: -1, item_ids: []}
  title = parsed_feed.title
  puts "\nAdding feed #{title}"
  web_url = parsed_feed.url
  feed_url = parsed_feed.feed_url
  crawled_at = CRAWL_TIME
  pubdate = DateTime.now - rndm.rand(5)
  ret = conn.exec(ins_feed, [title, web_url, feed_url, crawled_at, pubdate])
  feed_id = ret[0]["id"].to_i
  feed[:feed_id] = feed_id
  parsed_feed.entries.each do |parsed_entry|
    item_title = parsed_entry.title
    url = parsed_entry.url
    author = parsed_entry.author
    if parsed_entry.respond_to?(:content) && parsed_entry.content 
      content = parsed_entry.content
    elsif parsed_entry.respond_to?(:summary) && parsed_entry.summary
      content = parsed_entry.summary
    else
      content = ""
    end
    blurb = Sanitize.clean(content).gsub(/\s+/, ' ').truncate(250)
    pubdate = parsed_entry.published || parsed_entry.updated
    ret2 = conn.exec(ins_item, [item_title, url, author, content, blurb, pubdate, feed_id])
    feed[:item_ids] << ret2[0]["id"].to_i
  end
  feeds << feed
  puts "Added feed #{feed[:feed_id]} #{title} with #{feed[:item_ids].length} items."
end


user_ids.each do |user_id|
  # Fill in user_feeds table
  user_feeds = []
  ins_uf = <<-EOS
    INSERT INTO user_feeds (added_on, num_unseen_items, user_id, feed_id)
    VALUES ($1, $2, $3, $4)
  EOS
  # Add 80% of existing feeds in the db to this user
  feeds.sample((feeds.length*0.8).to_i).each do |feed|
    added_on = DateTime.now - rndm.rand(10..50)
    num_unseen_items = rndm.rand(feed[:item_ids].length)
    feed_id = feed[:feed_id]
    puts "Unseen times for feed #{feed_id} is #{num_unseen_items}"
    conn.exec(ins_uf, [added_on, num_unseen_items, user_id, feed_id])
    user_feeds << {feed_id: feed_id, num_unseen_items: num_unseen_items}
  end

  # Fill in reading_history table
  ins_rh = <<-EOS
    INSERT INTO reading_history (is_seen, is_read, seen_at, user_id, item_id)
    VALUES ($1, $2, $3, $4, $5)
  EOS
  user_feeds.each do |user_feed|
    feed_id = user_feed[:feed_id]
    item_ids = feeds.find{|f| f[:feed_id] == feed_id}[:item_ids]
    num_seen_items = item_ids.length - user_feed[:num_unseen_items]
    item_ids.sample(num_seen_items).each do |item_id|
      is_seen = true
      seen_at = DateTime.now - rndm.rand(5)
      is_read = [true, false].sample
      conn.exec(ins_rh, [is_seen, is_read, seen_at, user_id, item_id])
    end
  end
end