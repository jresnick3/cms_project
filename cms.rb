require "sinatra"
require "pry"
require "sinatra/reloader"
require "tilt/erubis"
require "rack"
require "sinatra/content_for"
require "redcarpet"
require "yaml"
require "bcrypt"

configure do
  enable :sessions
  set :session_secret, 'super secret'
end

helpers do
  def load_file_content(path)
    content = File.read(path)
    case File.extname(path)
    when ".txt"
      headers["Content-Type"] = 'text/plain'
      content
    when ".md"
      render_markdown(content)
    end
  end

  def render_markdown(content)
    markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
    markdown.render(content)
  end

  def valid_name?(name)
    case
    when name.size == 0
      session[:message] = 'A name is required.'
      false
    when File.extname(name).empty?
      session[:message] = 'Please specify file type.'
      false
    else
      session[:message] = name + " was created."
    end
  end
end

def signed_in?
  session.key?(:username)
end

def require_signed_in_user
  unless signed_in?
    session[:message] = "You must be signed in to do that."
    redirect '/'
  end
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def load_user_credentials
  credentials_path = if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/users.yml", __FILE__)
  else
    File.expand_path("../users.yml", __FILE__)
  end
  YAML.load_file(credentials_path)
end

def valid_credentials?(username, password)
  users = load_user_credentials

  if users.key?(username)
    stored_password = BCrypt::Password.new(users[username])
    stored_password == password
  else
    false
  end
end

get '/' do
  pattern = File.join(data_path, "*")
  @content = Dir.glob(pattern).map do |path|
    File.basename(path)
  end
  erb :index, layout: :layout
end

get '/users/signin' do
  erb :signin
end

post '/users/signin' do
  username = params[:username]
  if valid_credentials?(username, params[:password])
    session[:username] = username
    session[:message] = "Welcome!"
    redirect '/'
  else
    status 422
    session[:message] = "Invalid Credentails"
    erb :signin
  end
end

post '/users/signout' do
  session.delete(:username)
  session[:message] = "You have been signed out."
  redirect '/'
end


get '/new' do
  require_signed_in_user
  erb :new_document, layout: :layout
end

post '/new' do
  require_signed_in_user
  name = params[:document_name]
  if valid_name?(name)
    pattern = File.join(data_path, name)
    File.write(pattern, '')
    redirect '/'
  else
    status 422
    erb :new_document
  end
end

get '/:file' do
  file_name = File.join(data_path, params[:file])
  if File.exist?(file_name)
    load_file_content(file_name)
  else
    session[:message] = (params[:file] + " does not exist.")
    redirect "/"
  end
end

get '/:file/edit' do
  require_signed_in_user
  @file_name = File.join(data_path, params[:file])
  @content = File.read(@file_name)
  erb :edit
end

post '/:file/edit' do
  require_signed_in_user
  file_name = File.join(data_path, params[:file])
  @new_content = params[:content]
  File.write(file_name, @new_content)
  session[:message] = "#{params[:file]} has been updated."
  redirect "/"
end

post '/:file/delete' do
  require_signed_in_user
  file_name = File.join(data_path, params[:file])
  File.delete(file_name)
  session[:message] = "#{params[:file]} was deleted."
  redirect '/'
end
