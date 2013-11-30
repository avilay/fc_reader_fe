require 'date'
require 'pg'
require 'csv'
require 'open-uri'
require 'nokogiri'
require 'feedzirra'
require_relative './data_contract'
require_relative '../utils'

class Feed < DataContract
  attr_accessor :id, :title, :web_url, :feed_url, :crawled_at, :pubdate, :num_unseen_items, :added_on
  
  def initialize(params)
    @fields = %w[id title web_url feed_url crawled_at pubdate num_unseen_items added_on]
    super
  end

  def id=(feed_id)
    @id = feed_id.to_i
  end

  def crawled_at=(ca)
    @crawled_at = to_date(ca)
  end

  def pubdate=(pd)
    @pubdate = to_date(pd)
  end

  def num_unseen_items=(nui)
    @num_unseen_items = nui.to_i
  end

  def added_on=(ao)
    @added_on = to_date(ao)
  end
end

class Item < DataContract
  attr_accessor :id, :feed_id, :title, :url, :author, :blurb, :contents, :pubdate, :is_seen, :is_read, :seen_at, :feed_title
  
  def initialize(params)
    @fields = %w[id feed_id title url author blurb contents pubdate is_seen is_read seen_at feed_title]
    super    
  end

  def id=(item_id)
    @id = item_id.to_i
  end

  def feed_id=(fi)
    @feed_id = fi.to_i
  end  

  def pubdate=(pd)
    @pubdate = to_date(pd)
  end

  def is_seen=(is)
    @is_seen = is == "t"
  end

  def is_read=(ir)
    @is_read = ir == "t"
  end

  def seen_at=(sa)
    @seen_at = to_date(sa)
  end
end

class AddStatus < DataContract
  attr_accessor :code, :linked_feeds
  def initialize(params)
    @fields = %w[code linked_feeds]
    super
  end
end

class FeedReaderClient
  def initialize(userid)
    @user_id = userid
    @is_feeds_cache_stale = true
    @conn = PG.connect(conn_str)
    @feeds_cache = {}
    build_feeds_cache
  end

  def add(feed_url)
    $logger.info "Adding #{feed_url} for user #{@user_id}"
    begin
      raw = open(feed_url).read
      uri = URI.parse(feed_url)
      begin
        parsed_feed = Feedzirra::Feed.parse(raw)
        status = create_or_add_feed(parsed_feed)        
      rescue
        linked_feeds = extract_links(raw)
        if linked_feeds.count == 0
          status = AddStatus.new(code: "not_a_feed")
        elsif linked_feeds.count == 1
          status = create_or_add_feed(linked_feeds.first)
        else
          status = AddStatus.new(code: "multiple_links", linked_feeds: linked_feeds.to_a)
        end
      end
    rescue
      # open threw an exception, so it was a dead url
      status = AddStatus.new(code: "dead_url")
    ensure
      @is_feeds_cache_stale = true
      status  
    end  
  end

  def remove(feed_id)
    $logger.info("Removing feed #{feed_id} for user #{@user_id}")
    @conn.exec("DELETE FROM user_feeds WHERE user_id = #{@user_id} AND feed_id = #{feed_id}")    
  end

  def feeds
    build_feeds_cache if @is_feeds_cache_stale
    @feeds_cache.values
  end

  def added?(fid)
    build_feeds_cache if @is_feeds_cache_stale
    @feeds_cache[fid]
  end

  def bulk_add(opml)

  end

  def personalized_items
    raise "FeedReaderClient#personalized_items not implemented!!"
  end

  def items(fid)
    raise "Trying to access unsubscribed feed!" unless (feed = added?(fid))
    get_items = <<-EOS
      SELECT * FROM items
      WHERE feed_id = #{fid}
    EOS
    items = {}
    @conn.exec(get_items).each do |hsh|
      # Set id, feed_id, title, url, author, contents, pubdate
      item = Item.new(hsh)
      item.feed_title = feed.title
      items[item.id] = item
    end
    item_ids_csv = CSV.generate_line(items.keys).chomp
    get_rh = <<-EOS
      SELECT * FROM reading_history
      WHERE user_id = #{@user_id}
      AND item_id IN (#{item_ids_csv})
    EOS
    @conn.exec(get_rh).each do |hsh|
      item = items[hsh["item_id"].to_i]
      iid = hsh["item_id"].to_i
      $logger.debug "Looking for item id #{iid}"
      item.is_seen = hsh["is_seen"]
      item.is_read = hsh["is_read"]
      item.seen_at = hsh["seen_at"]
    end
    items.values
  end

  def mark_as_seen(item_ids)
    $logger.info "Marking #{item_ids.inspect} as seen for user #{@user_id}."
    item_ids.each do |item_id|
      # Check if this item was already seen, if so ignore it and move on to the next item
      num = @conn.exec("SELECT COUNT(*) AS count FROM reading_history WHERE item_id = #{item_id} AND user_id = #{@user_id}")[0]["count"].to_i
      next unless num == 0
      
      # Add this as a seen item to reading_history
      @conn.exec("INSERT INTO reading_history (is_seen, is_read, seen_at, user_id, item_id) VALUES (true, false, '#{DateTime.now}', #{@user_id}, #{item_id})")

      # Decrement the num_unseen_items for the feed to which this item belongs
      feed_id = @conn.exec("SELECT feed_id FROM items WHERE id = #{item_id}")[0]["feed_id"].to_i
      num_unseen_items = @conn.exec("SELECT num_unseen_items FROM user_feeds WHERE user_id = #{@user_id} AND feed_id = #{feed_id}")[0]["num_unseen_items"].to_i
      @conn.exec("UPDATE user_feeds SET num_unseen_items = #{num_unseen_items - 1} WHERE user_id = #{@user_id} AND feed_id = #{feed_id}")
      $logger.debug "Inital num_unseen_items: #{num_unseen_items}"
    end
  end

  def mark_as_read(item_id)
    $logger.info "Marking item #{item_id} as read for user #{@user_id}"
    @conn.exec("UPDATE reading_history SET is_read = true WHERE user_id = #{@user_id} AND item_id = #{item_id}")
  end

  private

  def build_feeds_cache
    get_feeds = <<-EOS
      SELECT * FROM feeds, user_feeds
      WHERE feeds.id = user_feeds.feed_id
      AND user_feeds.user_id = #{@user_id}
    EOS
    @conn.exec(get_feeds).each do |hsh|
      # Set the title, web_url, feed_url, crawled_at, pubdate, num_unseen_items, added_on
      feed = Feed.new(hsh)
      feed.id = hsh["feed_id"]
      @feeds_cache[feed.id] = feed
    end
    $logger.info "Built feeds cache for user #{@user_id} with #{@feeds_cache.count} feeds."
    @is_feeds_cache_stale = false
  end

  def add_user_to_feed(feed_id)
    num_items = @conn.exec("SELECT COUNT(*) AS count FROM items WHERE feed_id = #{feed_id}")[0]["count"].to_i
    ins_uf = <<-EOS
      INSERT INTO user_feeds (user_id, feed_id, added_on, num_unseen_items)
      VALUES (#{@user_id}, #{feed_id}, '#{DateTime.now}', #{num_items})
    EOS
    @conn.exec(ins_uf)
  end

  def add_feed(parsed_feed)
    ins_feed = <<-EOS
      INSERT INTO feeds (title, web_url, feed_url, crawled_at, pubdate)
      VALUES ($1, $2, $3, $4, $5)
      RETURNING id
    EOS

    ins_item = <<-EOS
      INSERT INTO items (title, url, author, contents, blurb, pubdate, feed_id)
      VALUES ($1, $2, $3, $4, $5, $6, $7)
    EOS

    title = parsed_feed.title
    web_url = parsed_feed.url
    feed_url = parsed_feed.feed_url
    crawled_at = DateTime.now
    pubdate = DateTime.now # TODO: Get the real pubdate here.
    feed_id = conn.exec(ins_feed, [title, web_url, feed_url, crawled_at, pubdate])[0]["id"].to_i
    # TODO: Do this asynchronously, not while the user is waiting for a response
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
      conn.exec(ins_item, [item_title, url, author, content, blurb, pubdate, feed_id])          
    end
    feed_id
  end

  def create_or_add_feed(parsed_feed)
    feed_id = @conn.exec("SELECT id FROM feeds WHERE title = #{parsed_feed.title}")[0]["id"].to_i
    feed_id = add_feed(parsed_feed) if feed_id == 0
    add_user_to_feed(feed_id) unless added? feed_id
    AddStatus.new(code: "ok")
  end

  def extract_links(raw)
    linked_feeds = Set.new
    doc = Nokogiri::HTML(raw)
    doc.xpath("html/head/link[@type='application/rss+xml']").each do |rss|
      linked_feeds.add(uri.merge(rss.attribute("href").value))
    end
    doc.xpath("html/head/link[@type='application/atom+xml']").each do |rss|
      linked_feeds.add(uri.merge(rss.attribute("href").value))
    end
    linked_feeds
  end
end