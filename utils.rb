class String
  def truncate(len)
    if self.length > len
      self[0..len-1] + "..."
    else
      self
    end
  end
end

def conn_str(str = nil)
  cs = str || ENV['DB_URL'] 
  matches = %r{(.*?)://(.*):(.*)@(.*):(.*)/(.*)}.match(cs)
  params = {}
  params[:user] = matches[2].strip
  params[:password] = matches[3].strip
  params[:host] = matches[4].strip
  params[:port] = matches[5].strip
  params[:dbname] = matches[6].strip
  params
end

def to_date(dt)
  begin
    if dt.kind_of? String
      DateTime.parse(dt)
    elsif dt.kind_of? Time
      dt
    else
      nil
    end
  rescue
    $logger.warn "Unable to parse date #{dt}"
    nil
  end
end