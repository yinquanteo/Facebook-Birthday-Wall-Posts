gem 'fb_graph', '1.9.1'
require 'sinatra'
require 'fb_graph'
set :port, 3000

CLIENT_ID   = "xxxx"
APP_SECRET  = "xxxx"
PERMISSIONS = "offline_access,read_stream"
HAPPY_BIRTHDAY_STRING = "happy b"

START_TIME = Time.utc(2011,"jun",30,23,59,59)
END_TIME   = Time.utc(2010,"jul",1,0,0,0)
MAX_FEED_CHUNK = 500

get '/sign_in' do
  redirect to(client.authorization_uri :scope => PERMISSIONS)
end

get '/' do
  last_failed_index = params[:failed_at].to_i
  @output = File.open("db/birthdays.txt", "a+")

  client.authorization_code = params[:code]
  access_token = client.access_token! :client_auth_body
  puts "Starting crawl with access_token #{access_token}"

  me = FbGraph::User.me(access_token).fetch
  me.friends.each_with_index do |friend,i|
    next if i < last_failed_index
    puts "#{i}: counting for #{friend.name} #{friend.identifier}"
    begin
      get_birthday_stats(friend)
    rescue Exception => e
      # retry stats gathering from the index it last failed at
      puts "FAILED #{e.to_s}"
      redirect url("/sign_in?failed_at=#{i}")
      break
    end
  end

  @output.close
  "done"
end

def get_birthday_stats(user)
  feed =  user.feed(:limit => MAX_FEED_CHUNK)
  return if feed.nil?

  count, total = count_birthday_posts(feed)
  print_string = "id:#{user.identifier}|username:#{user.name}|total:#{total}|count:#{count}|percent:#{count*1.0/total}"
  @output.puts print_string
  puts print_string
end

def count_birthday_posts(feed_chunk, birthday_posts = 0, total_posts = 0)
  puts "counting.. birthdaycounts: #{birthday_posts} totalcounts: #{total_posts} chunksize: #{feed_chunk.size}"
  return [birthday_posts, total_posts] if feed_chunk.size == 0
  feed_chunk.each do |post|
    unless post.message.blank?
      next   if post.updated_time > START_TIME
      return [birthday_posts, total_posts] if post.updated_time < END_TIME

      birthday_posts += 1 if post.message.downcase.include? HAPPY_BIRTHDAY_STRING
      total_posts    += 1
    end
  end
  count_birthday_posts(feed_chunk.next, birthday_posts, total_posts)
end

def client
  unless @client
    @client = FbGraph::Auth.new(CLIENT_ID, APP_SECRET).client
    @client.redirect_uri = redirect_url(params[:failed_at])
  end
  @client
end

def redirect_url failed_at
  fragment = failed_at ? "?failed_at=#{failed_at}" : ""
  url('/') + fragment
end
