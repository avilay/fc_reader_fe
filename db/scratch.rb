require 'feedzirra'

FEEDS_ROOT = File.expand_path(File.dirname(__FILE__) + "/seed_feeds")
Dir.chdir(FEEDS_ROOT)
Dir.glob("*.xml").each do |feed_file|
  parsed_feed = Feedzirra::Feed.parse(IO.read(feed_file))
  puts "***#{parsed_feed.title}***"
  parsed_feed.entries.each do |parsed_entry|
    puts parsed_entry.title
    if parsed_entry.respond_to? :url
      puts parsed_entry.url
    else
      puts "No link"
    end
  end
  puts
  puts "Enter to continue.."
  gets
end