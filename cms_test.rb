require "sinatra"
require "fileutils"

ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"

require_relative "./cms"

class CMSTest < Minitest::Test
  include Rack::Test::Methods

  def setup
    FileUtils.mkdir_p(data_path)
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end

  def create_document(name, content = "")
    File.open(File.join(data_path, name), "w") do |file|
      file.write(content)
    end
  end

  def app
    Sinatra::Application
  end

  def session
    last_request.env["rack.session"]
  end

  def admin_session
    {"rack.session" => {username: "admin"}}
  end

  def test_file_display
    create_document "about.md"
    create_document "changes.txt"
    create_document "history.txt"
    get "/"
    assert_equal(200, last_response.status)
    assert_equal("text/html;charset=utf-8", last_response["Content-Type"])
    assert_includes(last_response.body, 'about.md')
    assert_includes(last_response.body, 'changes.txt')
    assert_includes(last_response.body, 'history.txt')
  end

  def test_content_display
    create_document("history.txt", "1993 - Yukihiro Matsumoto dreams up Ruby.")
    get "/history.txt"
    assert_equal(200, last_response.status)
    assert_equal('text/plain', last_response["Content-Type"])
    assert_includes(last_response.body, '1993 - Yukihiro Matsumoto dreams up Ruby.')
  end

  def test_invalid_file
    get "/hist.txt"
    assert_equal(302, last_response.status)
    assert_equal("hist.txt does not exist.", session[:message])
  end

  def test_markdown_display
    create_document("about.md", "<h1>Ruby is...</h1>")
    get '/about.md'
    assert_equal(200, last_response.status)
    refute_includes(last_response.body, '#')
    assert_includes(last_response.body, "<h1>Ruby is...</h1>")
    assert_equal("text/html;charset=utf-8", last_response["Content-Type"])
  end

  def test_edit_page
    create_document "changes.txt"
    get '/changes.txt/edit', {}, admin_session
    assert_equal(200, last_response.status)
    assert_includes(last_response.body, "Edit content of changes.txt")
  end


  def test_edit_content
    post '/changes.txt/edit', {content: "new content"}, admin_session
    assert_equal(302, last_response.status)
    assert_equal("changes.txt has been updated.", session[:message])

    get '/changes.txt'
    assert_equal(200, last_response.status)
    assert_includes(last_response.body, "new content", )
  end

  def test_new_doc_page
    get '/new', {}, admin_session
    assert_equal(200, last_response.status)
    assert_includes(last_response.body, '<input')
    assert_includes(last_response.body, 'type="submit"')
  end

  def test_adding_doc
    post '/new', {document_name: "test1.txt"}, admin_session
    assert_equal(302, last_response.status)
    assert_equal('test1.txt was created.', session[:message])

    get '/'
    assert_includes(last_response.body, 'test1.txt')
  end

  def test_adding_noname_doc
    post '/new', {document_name: ""}, admin_session
    assert_equal(422, last_response.status)
    assert_includes(last_response.body, 'A name is required.')
    assert_includes(last_response.body, 'Add a new document:')
  end

  def test_adding_noextension_doc
    post '/new', {document_name: "test1"}, admin_session
    assert_equal(422, last_response.status)
    assert_includes(last_response.body, 'Please specify file type.')
    assert_includes(last_response.body, 'Add a new document:')
  end

  def test_delete_file
    create_document('test.txt')
    post '/test.txt/delete', {}, admin_session
    assert_equal(302, last_response.status)
    assert_equal("test.txt was deleted.", session[:message])

    get '/'
    refute_includes(last_response.body, "test.txt</a>")
  end

  def test_signin_form
    get "/users/signin"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_signin
    post "/users/signin", username: "admin", password: "secret"
    assert_equal 302, last_response.status
    assert_equal("Welcome!", session[:message])
    assert_equal("admin", session[:username])

    get last_response["Location"]
    assert_includes last_response.body, "Signed in as admin"
  end

  def test_signin_with_bad_credentials
    post "/users/signin", username: "guest", password: "shhhh"
    assert_equal 422, last_response.status
    assert_nil(session[:username])
    assert_includes last_response.body, "Invalid Credentails"
  end

  def test_signout
    post "/users/signout", {}, admin_session
    assert_equal("You have been signed out.", session[:message])

    get last_response["Location"]
    assert_nil(session[:message])
    assert_includes last_response.body, "Sign In"
  end

  def test_signedout_edit
    create_document('test.txt')
    get '/test.txt/edit'
    assert_equal(302, last_response.status)
    assert_equal("You must be signed in to do that.", session[:message])
  end

  def test_signout_edit_post
    create_document('test.txt')
    post '/test.txt/edit'
    assert_equal(302, last_response.status)
    assert_equal("You must be signed in to do that.", session[:message])
  end

  def test_signout_new_doc_page
    get '/new'
    assert_equal(302, last_response.status)
    assert_equal("You must be signed in to do that.", session[:message])
  end

  def test_signout_new_doc_submit
    post '/new'
    assert_equal(302, last_response.status)
    assert_equal("You must be signed in to do that.", session[:message])
  end

  def test_signout_delete
    create_document('test.txt')
    post '/test.txt/delete'
    assert_equal(302, last_response.status)
    assert_equal("You must be signed in to do that.", session[:message])
  end
end
