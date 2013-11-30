require 'pg'
require_relative './data_contract'
require_relative '../utils'

class User < DataContract
  attr_reader :id, :name, :last_activity_at, :created_at, :provider_id, :provider_name, :oauth_token, :oauth_secret
  def initialize(params)
    @fields = %w[id name last_activity_at created_at provider_id provider_name oauth_token oauth_secret]
    super
  end
end

class UserClient
  def initialize
    @conn = PG.connect(conn_str)
  end

  def login(oauth_user)
    User.new(@conn.exec("SELECT * FROM users WHERE id = 25")[0])
  end

  def mock_login
    #User.new(@conn.exec("SELECT * FROM users LIMIT 1")[0])
    User.new(@conn.exec("SELECT * FROM users WHERE id = 27")[0])
  end
end