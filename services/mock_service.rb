require 'ostruct'

class MockSvc
  # Feed Manager
  def add(uid, feed_url)
    statuses = []
    statuses << OpenStruct.new(code: "ok")
    statuses << OpenStruct.new(code: "dead_url")
    statuses << OpenStruct.new(code: "not_a_feed")
    statuses << OpenStruct.new(code: "multiple_links", linked_feeds: ["http://feeds.feedburner.com/ommalik", "http://www.nytimes.com/services/xml/rss/nyt/HomePage.xml"])
    statuses[Random.new.rand(statuses.length)]
  end

  def feeds(uid)
    feeds = []    
    feeds << OpenStruct.new(id: 1, title: "Hacker News")
    feeds << OpenStruct.new(id: 2, title: "New York Times Headlines")
    feeds << OpenStruct.new(id: 3, title: "Scientific American")
    feeds << OpenStruct.new(id: 4, title: "Joel Spolsky's Blog")
    feeds << OpenStruct.new(id: 5, title: "Windows Azure Latest News Blogs & Tweets")
    feeds << OpenStruct.new(id: 6, title: "Venture Beat")
    feeds << OpenStruct.new(id: 7, title: "Techcrunch")
    feeds << OpenStruct.new(id: 8, title: "GigaOm Pro News")
    feeds
  end

  def added?(uid, fid)
    false
    #true
  end

  def bulk_add(opml)
  end

  def remove(uid, fid)
  end


  # Reader Service
  def personalized_items(uid)
    items(1)
  end

  def items(fid)
    blurb = "ipsum lorem lorem lorem ipsum ipsum ipsum set lorem lorem lorem set ipsum set ipsum lorem dolor dolor lorem lorem dolor dolor dolor ipsum ip"
    contents = <<-EOS
      ipsum lorem lorem lorem ipsum ipsum ipsum set lorem lorem lorem set ipsum set ipsum lorem dolor dolor lorem lorem dolor dolor dolor ipsum ipsum set ipsum ipsum set lorem lorem set set dolor lorem set ipsum set lorem set set set dolor ipsum set ipsum ipsum dolor set dolor set set set ipsum dolor lorem set set dolor set ipsum set lorem set set lorem dolor set lorem dolor ipsum lorem dolor ipsum lorem dolor ipsum ipsum ipsum ipsum ipsum dolor lorem dolor ipsum lorem set set dolor dolor dolor dolor set lorem lorem lorem ipsum dolor set lorem set lorem set lorem lorem ipsum lorem dolor ipsum dolor lorem lorem lorem set dolor lorem dolor lorem set dolor ipsum set ipsum set lorem lorem ipsum lorem set lorem lorem set ipsum ipsum dolor dolor dolor lorem dolor set
    EOS

    items = []
    items << OpenStruct.new(id: 1, title: "Item One Title", blurb: blurb, contents: contents)
    items << OpenStruct.new(id: 2, title: "Item Two Title", blurb: blurb, contents: contents)
    items << OpenStruct.new(id: 3, title: "Item Three Title", blurb: blurb, contents: contents)
    items << OpenStruct.new(id: 4, title: "Item Four Title", blurb: blurb, contents: contents)
    items << OpenStruct.new(id: 5, title: "Item Five Title", blurb: blurb, contents: contents)
    items << OpenStruct.new(id: 6, title: "Item Six Title", blurb: blurb, contents: contents)
    items << OpenStruct.new(id: 7, title: "Item Seven Title", blurb: blurb, contents: contents)
    items << OpenStruct.new(id: 8, title: "Item Eight Title", blurb: blurb, contents: contents)
    items << OpenStruct.new(id: 9, title: "Item Nine Title", blurb: blurb, contents: contents)
    items << OpenStruct.new(id: 10, title: "Item Nine Title", blurb: blurb, contents: contents)
    items << OpenStruct.new(id: 11, title: "Item Nine Title", blurb: blurb, contents: contents)
    items << OpenStruct.new(id: 12, title: "Item Nine Title", blurb: blurb, contents: contents)
    items << OpenStruct.new(id: 13, title: "Item Nine Title", blurb: blurb, contents: contents)
    items << OpenStruct.new(id: 14, title: "Item Nine Title", blurb: blurb, contents: contents)
    items << OpenStruct.new(id: 15, title: "Item Nine Title", blurb: blurb, contents: contents)
    items << OpenStruct.new(id: 16, title: "Item Nine Title", blurb: blurb, contents: contents)
    items
  end
  
  def mark_as_seen(uid, items)
    item_ids = items.map {|i| i.id}
    $logger.info "Marking #{item_ids.inspect} as seen for user #{uid}."
  end

  def mark_as_read(uid, iid)
    $logger.info "Marking item #{iid} as read for user #{uid}"
  end

  # User Manager
  def login(oauth_user)
    # FcUser = Struct.new(:name, :id)
    # FcUser.new(oauth_user.user_name, 1)
    OpenStruct.new(id: 1, name: oauth_user.user_name)
  end

end