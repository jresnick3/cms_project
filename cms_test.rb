require "sinatra"

ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"

require_relative "./cms"

class CMSTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def test_file_display
    get "/"
    assert_equal(200, last_response.status)
    assert_equal("text/html;charset=utf-8", last_response["Content-Type"])
    assert_includes(last_response.body, 'about.txt')
    assert_includes(last_response.body, 'changes.txt')
    assert_includes(last_response.body, 'history.txt')
  end

  def test_content_display
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
end
