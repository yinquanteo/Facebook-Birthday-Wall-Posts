class FacebookController < ApplicationController
  CLIENT_ID = "xxxx"
  APP_SECRET = "xxxx"
  PERMISSIONS = "offline_access,read_stream"
  HAPPY_BIRTHDAY_STRING = "happy b"
  
  def sign_in
    redirect_to client.authorization_uri :scope => PERMISSIONS
  end

  def index
    last_failed_index = 0
    last_failed_index = params[:failed_at].to_i unless params[:failed_at].blank?
    @output = File.open("db/birthdays.txt", "a+")

    client.authorization_code = params[:code]
    access_token = client.access_token!
    puts "access_token #{access_token}"

    user = FbGraph::User.me(access_token).fetch
    my_friends = user.friends
    puts "STARTING"
    
    my_friends.each_with_index do |friend,i|
      next if i < last_failed_index
      puts "#{i}: counting for #{friend.name} #{friend.identifier}"
      begin
        get_birthday_stats(friend)
      rescue Exception => e
        puts "FAILED #{e.to_s}"
        redirect_to sign_in_path(:failed_at => i )
        break
      end
    end

    @output.close
  end

  private
  
  def get_birthday_stats(user)
    feed =  user.feed(:limit => 400)
    return if feed.nil? 
    
    count = 0
    total = 0
    continue_looping = true
    start_time = Time.utc(2011,"jun",30,23,59,59)
    end_time = Time.utc(2010,"jul",1,0,0,0)
    
    while continue_looping 
      feed.each do |item|
        unless item.message.blank?
          next if item.updated_time > start_time
          
          if item.updated_time < end_time 
            continue_looping = false
            break
          end
          count += 1 if item.message.downcase.include? HAPPY_BIRTHDAY_STRING
          total += 1
        end
        puts total if total % 50 == 0
      end
      continue_looping = false if feed.size < 400
      feed = feed.next if continue_looping
    end
    print_string = "id:#{user.identifier}|username:#{user.name}|total:#{total}|count:#{count}|percent:#{count*1.0/total}"
    @output.puts print_string
    puts print_string
  end

  def client
    unless @client
      @client = FbGraph::Auth.new(CLIENT_ID, APP_SECRET).client
      @client.redirect_uri = root_url(:failed_at => params[:failed_at])
    end
    @client
  end
end
