require 'logger'
require_relative 'feedreader_client'

ENV['DB_URL'] = "postgres://avilay:anuchiku@localhost:5432/fringecup"
$logger = Logger.new(STDOUT)

frc = FeedReaderClient.new(25)
frc.mark_as_seen([1589, 1592])

#*** Test setup
# empty the db

# create 1 user

# create 2 feeds

# add user to one of the feeds

#*** Test cases
# url is an atom feed; feed is not in the system

# url is a feed; feed is already added for this user

# url has a single linked rss feed; feed is already in the system, but not for this user

# url has multiple linked atom feeds

# url has no feeds linked to it

# url is dead

 