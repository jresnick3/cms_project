require "sinatra"
require "pry"
require "sinatra/reloader"
require "tilt/erubis"
require "rack"
require "sinatra/content_for"
require "redcarpet"

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
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

get '/' do
  pattern = File.join(data_path, "*")
  @content = Dir.glob(pattern).map do |path|
    File.basename(path)
  end
  erb :files
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
  @file_name = File.join(data_path, params[:file])
  @content = File.read(@file_name)
  erb :edit
end

post '/:file/edit' do
  file_name = File.join(data_path, params[:file])
  @new_content = params[:content]
  File.write(file_name, @new_content)
  session[:message] = "#{params[:file]} has been updated."
  redirect "/"
end
