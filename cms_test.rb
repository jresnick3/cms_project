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
    assert_equal("text/html;charset=utf-8", last_response["Content-Type"])

    get last_response["Location"]
    assert_equal(200, last_response.status)
    assert_includes(last_response.body, "hist.txt does not exist.")

    get '/'
    refute_includes(last_response.body, "hist.txt does not exist.")
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
    get '/changes.txt/edit'
    assert_equal(200, last_response.status)
    assert_includes(last_response.body, "Edit content of changes.txt")
  end


  def test_edit_content
    post '/changes.txt/edit', content: "new content"
    assert_equal(302, last_response.status)

    get last_response["Location"]
    assert_equal(200, last_response.status)
    assert_includes(last_response.body, "changes.txt has been updated")

    get '/changes.txt'
    assert_equal(200, last_response.status)
    assert_includes(last_response.body, "new content", )
  end

  def test_new_doc_page
    get '/new'
    assert_equal(200, last_response.status)
    assert_includes(last_response.body, '<input')
    assert_includes(last_response.body, 'type="submit"')
  end

  def test_adding_valid_doc
    post '/new', document_name: "test1.txt"
    assert_equal(302, last_response.status)

    get last_response["Location"]
    assert_equal(200, last_response.status)
    assert_includes(last_response.body, 'test1.txt was created.')

    get '/'
    assert_includes(last_response.body, 'test1.txt')
  end

  def test_adding_noname_doc
    post '/new', document_name: ""
    assert_equal(422, last_response.status)
    assert_includes(last_response.body, 'A name is required.')
    assert_includes(last_response.body, 'Add a new document:')
  end

  def test_adding_noextension_doc
    post '/new', document_name: "test1"
    assert_equal(422, last_response.status)
    assert_includes(last_response.body, 'Please specify file type.')
    assert_includes(last_response.body, 'Add a new document:')
  end
end
