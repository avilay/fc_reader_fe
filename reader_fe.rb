require 'sinatra'
require 'sinatra/reloader'
require 'will_paginate'
require 'will_paginate/array'
require 'will_paginate-bootstrap'
require 'oauth'
require 'date'
require_relative './services/mock_service'
require_relative './services/feedreader_client'
require_relative './services/user_client'
require_relative './utils'

enable :sessions

configure do
  set :items_per_page, 10 
  set :twitter_consumer_key, ENV['TWITTER_CONSUMER_KEY']
  set :twitter_consumer_secret, ENV['TWITTER_CONSUMER_SECRET']
  set :host, ENV['HOSTNAME']
  set :oauth_callback_path, '/home/login_done'
  set :offline_mode, true
end

helpers do
  def reset_session(call_next)
    session[:authenticated] = false
    session[:call_next] = call_next
    redirect to('/home/login')  
  end

  def mock_login
    session[:user] = @user_svc.mock_login
    session[:authenticated] = true
    next_page = session[:call_next] || '/home/'  
    redirect to(next_page)
  end
end

before do
  $logger = logger
  @errors = []
  @warnings = []
  @infos = []
  @user_svc = UserClient.new
end

get %r{(home$)|(home/$)} do
  @user = session[:user] if session[:user]
  @home_active = "active"
  erb :home
end

get '/home/login' do
  key = settings.twitter_consumer_key
  secret = settings.twitter_consumer_secret
  oauth_callback = settings.host + settings.oauth_callback_path
  consumer = OAuth::Consumer.new(key, secret, {site: "https://api.twitter.com/"})
  request_token = consumer.get_request_token(oauth_callback: oauth_callback)
  session[:request_token] = request_token
  redirect to(request_token.authorize_url)
end

get '/home/login_done' do
  access_token = session[:request_token].get_access_token(oauth_verifier: params[:oauth_verifier])  
  session[:request_token] = nil
  user = {}
  user[:name] = access_token.params[:screen_name]
  user[:provider_id] = access_token.params[:user_id]
  user[:provider_name] = "twitter"
  user[:oauth_token] = access_token.params[:oauth_token]
  user[:oauth_secret] = access_token.params[:oauth_token_secret] 
  logger.info user.inspect 
  session[:user] = @user_svc.login(user) 
  session[:authenticated] = true
  next_page = session[:call_next] || '/home/'  
  redirect to(next_page)
end

# All paths starting with home, css, img, js, and __sinatra__ should be excluded from being authenticated
# All other paths will have this filter apply
before %r{^((?!/(home)|(css)|(img)|(js)|(__sinatra__)/).)*$} do
  redirect to('/home') if request.path_info == "/"
  if session[:authenticated]
    @user = session[:user]      
    @feedreader_svc = FeedReaderClient.new(@user.id)
    logger.info("User #{@user.id} #{@user.name} is logged in.")    
  else
    if settings.offline_mode
      mock_login
    else
      reset_session(request.path_info)
    end
  end    
end

get '/feeds/add_form' do
  @page_heading = "Add Feed"
  erb :'add/add_form', layout: :popup
end

get '/feeds/add' do
  @page_heading = "Add Feed"
  url = params["feed_url"]
  add_status = @feedreader_svc.add(url)
  case add_status.code
  when "ok"
    @added_feed_urls = [url]
    erb :'add/add_done', layout: :popup
  when "dead_url"
    @errors << "#{url} is not live. Please enter another url."
    erb :'add/add_form', layout: :popup
  when "not_a_feed"
    @errors << "#{url} does not have any feeds. Please enter another URL."
    erb :'add/add_form', layout: :popup
  when "multiple_links"
    @linked_feeds = add_status.linked_feeds
    erb :'add/add_linked', layout: :popup
  else
    raise 'Add failed!'
  end  
end

post '/feeds/add_linked' do
  @page_heading = "Add Feed"
  @added_feed_urls = []
  @failed_feed_urls = []
  params.keys.each do |url|
    add_status = @feedreader_svc.add(url)
    if add_status.code == "ok" 
      @added_feed_urls << url
    else
      @failed_feed_urls << url
    end
  end  
  erb :'add/add_done', layout: :popup
end

post '/feeds/bulk_add' do
  @page_heading = "Add Feed"
  @feedreader_svc.bulk_add(IO.read(params["opml_file"][:tempfile]))
  @infos << "You will be subscribed to any feeds in the file. Check back in a few minutes."
  erb :'add/add_done', layout: :popup
end

post '/feeds/remove' do
  if @feedreader_svc.added?(Integer(params[:feed_id]))
    @feedreader_svc.remove(Integer(params[:feed_id]))
    status 200
  else
    logger.warn("User #{@user.id} trying to remove unsubscribed feed #{params[:feed_id]}")
    status 401
  end
end

get '/feeds/items' do
  #TODO
  redirect to('/feeds/personalized/items')
end

get '/feeds/personalized/items' do
  @feeds = @feedreader_svc.feeds.sort{|f1, f2| f2.added_on <=> f1.added_on}
  logger.info "Returning #{@feeds.count} number of feeds"
  erb :under_construction
end

get '/feeds/:feed_id/items' do
  @reader_active = "active"
  @feeds = @feedreader_svc.feeds.sort{|f1, f2| f2.added_on <=> f1.added_on}
  @selected_feed = @feedreader_svc.added?(params[:feed_id].to_i)
  page_num = params[:page]
  num_items = settings.items_per_page
  if @selected_feed
    feed_items = @feedreader_svc.items(@selected_feed.id)
  else
    logger.warn("User #{@user.id} trying to view unsubscribed feed #{params[:feed_id]}")
    status 401
    erb :error
  end
  sorted_items = feed_items.sort{|x,y| y.pubdate <=> x.pubdate}
  @items = sorted_items.paginate(:page =>page_num, :per_page => num_items)
  @feedreader_svc.mark_as_seen(@items.map{|i| i.id})
  erb :items
end

get '/items/:item_id/read' do
  @feedreader_svc.mark_as_read(params[:item_id])
  status 200
end


