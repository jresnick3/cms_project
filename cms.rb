require "sinatra"
require "pry"
require "sinatra/reloader"
require "tilt/erubis"
require "rack"
require "sinatra/content_for"

configure do
  enable :sessions
  set :session_secret, 'super secret'
end

root = File.expand_path("..", __FILE__)

get '/' do
  @content = Dir.glob(root + "/data/*").map do |path|
    File.basename(path)
  end
  erb :files
end

get '/:file' do
  file_name = root + "/data/" + params[:file]
  if File.exist?(file_name)
    headers["Content-Type"] = 'text/plain'
    File.read(file_name)
  else
    session[:error] = (params[:file] + " does not exist.")
    redirect "/"
  end
end
