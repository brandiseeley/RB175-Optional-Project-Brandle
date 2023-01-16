ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "minitest/reporters"
require "rack/test"

Minitest::Reporters.use!

require_relative "../brandle.rb"

### METHODS OVERRIDDEN FOR TESTING ###

def fetch_word_bank
  ['START', 'MARCH']
end

def fetch_allowed_words
  ['START', 'MARCH', 'MILKS', 'SILKS']
end

def load_stats(username)
  $test_user_stats
end

def overwrite_stats(new_stats)
  $test_user_stats.replace(new_stats)
end

### END METHODS OVERRIDDEN FOR TESTING ###

class BrandleTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def session
    last_request.env["rack.session"]
  end

  def test_user_logged_in
    { "rack.session" => { user: "janet" } }
  end

  def setup
    $test_user_stats = {
      "games" => 10,
      "won" => 6,
      "lost" => 4,
      "played" => ["MARCH"]
    }
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

  def test_invalid_word
    post "/play", guess: "frog"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "Guesses must be 5 letter words"

    post "/play", guess: "stairs"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "Guesses must be 5 letter words"

    post "/play", guess: "abcd!"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "Guesses must be 5 letter words"

    post "/play", guess: "aaaaa"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "AAAAA is not a valid guess"
  end
  
  def test_win_guest
    get "/play"
    word = session[:word]
    post "/play", guess: word
    
    assert_equal 200, last_response.status
    assert_includes last_response.body, "You won!"
  end
  
  def test_win_logged_in
    get "/janet/play", {}, test_user_logged_in
    assert_equal "START", session[:word]
    post "/play", guess: "start"
    
    assert_equal 200, last_response.status
    assert_includes last_response.body, "You won!"
    assert_equal 7, load_stats("_")["won"]
  end
  
  def test_lose_guest
    get "/play"
    6.times do |_|
      post "/play", guess: "milks"
    end
    
    assert_equal 200, last_response.status
    assert_includes last_response.body, "You ran out of guesses! Try again."
  end
  
  def test_lose_logged_in
    get "/janet/play", {}, test_user_logged_in
    assert_equal 4, load_stats("_")["lost"]
    6.times do |_|
      post "/janet/play", guess: "milks"
    end
    
    assert_equal 200, last_response.status
    assert_includes last_response.body, "You ran out of guesses! Try again."
    assert_equal 5, load_stats("_")["lost"]
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
