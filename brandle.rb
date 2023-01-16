require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'
require 'pry-byebug'
require 'yaml'

configure do
  enable :sessions
  enable :reloader
end

=begin
- Change user data to have list of 'unplayed' words instead of 'played'?
- Establish *where* session message should be set
  - within validation method or based on return value of validation method
  - A validation method should probably *only* validate, not validate and set a message
- There's a lot of duplication between guest_play.erb and user_play.erb
=end

before do
  if !game_started?
    new_game
  end
  @word = session[:word]
  @letter_bank = session[:letter_bank]
  @guesses = session[:guesses]
end

### VIEW HELPERS ###

helpers do

  ### HTML GENERATORS ###

  # output: HTML String
  # Returns 6 rows of table *body* populated with guesses
  def guesses_to_table(guesses)
    rows = ""
    6.times do |index|
      if guesses[index]
        rows << "<tr>#{word_as_table_row(guesses[index])}</tr>"
      else
        rows << "<tr>#{word_as_table_row("_____")}</tr>"
      end
    end
    rows
  end

  # output: HTML String
  # Returns 5 <td> elements populated with chars of given word
  # Elements will be assigned class (correct, present, not-present, blank)
  def word_as_table_row(word)
    html_string = ""
    word.chars.each_with_index do |letter, index|
      letter_class = guess_letter_class(letter, index)
      html_string << "<td class=#{letter_class}>#{letter}</td>"
    end
    html_string
  end
  
  # output: HTML String
  # Returns unordered list element populated with user statistics
  def stats_to_list(username)
    stats = load_stats(username)
    list = "<ul>"
    list << "<li>Wins: #{stats["won"]}</li> "
    list << "<li>Losses: #{stats["lost"]}</li> "
    list
  end

  ### END HTML GENERATORS ###

  # Returns class for *letter bank* letters
  def letter_bank_class(letter)
    session[:letter_bank][letter]
  end

  # Returns class for *guess table* letters
  def guess_letter_class(letter, index)
    word = session[:word]
    if letter == "_"
      "blank"
    elsif word[index] == letter
      "correct"
    elsif word.include?(letter)
      "present"
    else
      "not-present"
    end
  end

  def display_guess_form?
    !game_over?
  end
end

### APP HELPERS ###

def new_game
  session[:word] = fetch_new_word
  session[:letter_bank] = generate_letter_bank
  session[:guesses] = []
end

# Will return random word from bank if playing as guest
# Will return word that *hasn't* been played by user if logged in and update 'played' words
def fetch_new_word
  word = File.read("public/data/answers.txt").split.sample
  return word if session[:user].nil?
  already_played = load_played_words
  # Assumes user hasn't played most possible words 
  # Won't terminate if played all, very ineffecient if played most
  # ??? Create "unplayed" word bank for users instead of 'played'?
  loop do
    break unless already_played.include?(word)
    word = File.read("public/data/answers.txt").split.sample
  end
  stats = load_stats(session[:user])
  stats["played"] << word
  File.open("user_data/stats_#{session[:user]}.yml", "w") do |file|
    YAML.dump(stats, file)
  end
  word
end

# returns nil if no user logged in, otherwise an array of words that have been played
def load_played_words
  return nil if session[:user].nil?
  return load_stats(session[:user])["played"]
end

def generate_letter_bank
  qwerty = %w(Q W E R T Y U I O P A S D F G H J K L Z X C V B N M)
  qwerty.each_with_object({}) do |letter, hash|
    hash[letter] = "not-guessed"
  end
end

# ??? Implement invalid_guess_message ???
def valid_guess?(word)
  if word.count("a-zA-Z") != 5 || word.length != 5
    session[:message] = "Guesses must be 5 letter words"
    return false
  end
  allowed_bank = File.read("public/data/allowed.txt").split
  if !allowed_bank.include?(word)
    session[:message] = "#{word} is not a valid guess."
    return false
  end
  true
end

def game_started?
  session[:word]
end

def correct?(letter)
  session[:letter_bank][letter] == "correct"
end

def game_over?
  if @guesses.size > 5
    true
  elsif @guesses.size <= 6 && won?
    true
  else
    false
  end
end

def set_game_over_message
  if won?
    session[:message] = "You won!"
  else
    session[:message] = "You ran out of guesses! Try again."
  end
end

def won?
  return false if @guesses.empty?
  letters_to_check = @guesses[-1].chars
  letters_to_check.each_with_index do |letter, index|
    return false if guess_letter_class(letter, index) != "correct"
  end
  true
end

def update_guesses(guess)
  @guesses << guess
end

def update_letter_bank(guess)
  word = session[:word]
  letter_bank = session[:letter_bank]
  guess.chars.each_with_index do |letter, index|
    if word[index] == letter
      letter_bank[letter] = "correct"
    elsif word.include?(letter)
      if !correct?(letter)
        letter_bank[letter] = "present"
      end
    else
      letter_bank[letter] = "not-present"
    end
  end
end

def load_user_credentials
  path = File.expand_path("../user_data/users.yml", __FILE__)
  YAML.load_file(path)
end

def valid_login?(username, password)
  credentials = load_user_credentials
  return false unless credentials.key?(username)
  return true if credentials[username] == password
  false
end

def logged_in?(username)
  session[:user] == username
end

def require_login(username)
  if !logged_in?(username)
    session[:message] = "You must be logged in to access that page"
    redirect "/login"
  end
end

def load_stats(username)
  YAML.load_file("user_data/stats_#{username}.yml")
end

def update_stats
  stats = load_stats(session[:user])
  stats["games"] += 1
  stats["won"] += 1 if won?
  stats["lost"] +=1 if !won?
  File.open("user_data/stats_#{session[:user]}.yml", "w") do |file|
    YAML.dump(stats, file)
  end
end

### ROUTES ###

get "/" do
  erb :home
end

get "/play" do
  erb :guest_play
end

post "/play" do
  guess = params[:guess].upcase
  if valid_guess?(guess)
    update_guesses(guess)
    update_letter_bank(guess)
    set_game_over_message if game_over?
  end
  erb :guest_play
end

get "/:username/play" do
  require_login(params[:username])
  erb :user_play
end

post "/:username/play" do
  require_login(params[:username])
  guess = params[:guess].upcase
  if valid_guess?(guess)
    update_guesses(guess)
    update_letter_bank(guess)
    if game_over?
      set_game_over_message
      update_stats
    end
  end
  erb :user_play
end

get "/reset" do
  user = session[:user]
  session.clear
  if user.nil?
    redirect "/play"
  else
    session[:user] = user
    redirect "/#{user}/play"
  end
end

get "/login" do
  erb :login
end

post "/login" do
  session.clear
  username = params[:username]
  password = params[:password]

  if username.empty? || password.empty?
    session[:message] = "Missing Fields"
    redirect "/login"
  end

  if valid_login?(username, password)
    session[:user] = username
    redirect "/#{username}/play"
  end
  session[:message] = "Invalid Username and/or Password"
  redirect "/login"
end

get "/logout" do
  session.clear
  redirect "/"
end
