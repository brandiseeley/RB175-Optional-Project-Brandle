ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "minitest/reporters"
require "rack/test"

Minitest::Reporters.use!

require_relative "../brandle.rb"

class BrandleTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def test_home
    get "/"
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<h1>Welcome to Brandle!</h1>"
    assert_includes last_response.body, "Play As Guest"
    assert_includes last_response.body, "Sign In"
  end
  
  def test_play_as_guest
    get "/play"
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<tr><td class=blank>_</td><td class=blank>_</td><td class=blank>_</td><td class=blank>_</td><td class=blank>_</td></tr><tr><td class=blank>_</td><td class=blank>_</td><td class=blank>_</td><td class=blank>_</td><td class=blank>_</td></tr><tr><td class=blank>_</td><td class=blank>_</td><td class=blank>_</td><td class=blank>_</td><td class=blank>_</td></tr><tr><td class=blank>_</td><td class=blank>_</td><td class=blank>_</td><td class=blank>_</td><td class=blank>_</td></tr><tr><td class=blank>_</td><td class=blank>_</td><td class=blank>_</td><td class=blank>_</td><td class=blank>_</td></tr>"
  end
  
  def test_user_play_without_login
    get "someuser/play"
    assert_equal 302, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    follow_redirect!
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "You must be logged in to access that page"
  end
end
