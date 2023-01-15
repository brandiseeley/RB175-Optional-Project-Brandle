require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'
require 'pry-byebug'
require 'yaml'

configure do
  enable :sessions
  enable :reloader
end

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
  def guesses_in_table(guesses)
    rows = ""
    5.times do |index|
      if guesses[index]
        rows << "<tr>#{word_as_table_row(guesses[index])}</tr>"
      else
        rows << "<tr>#{word_as_table_row("_____")}</tr>"
      end
    end
    rows
  end

  def word_as_table_row(word)
    html_string = ""
    word.chars.each_with_index do |letter, index|
      letter_class = guess_letter_class(letter, index)
      html_string << "<td class=#{letter_class}>#{letter}</td>"
    end
    html_string
  end

  def letter_bank_class(letter)
    session[:letter_bank][letter]
  end

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
    guesses = session[:guesses]
    return false if guesses.include?(session[:word])
    return false if guesses.size > 4
    true
  end
end

### APP HELPERS ###

def new_game
  session[:word] = File.read("public/data/answers.txt").split.sample
  session[:letter_bank] = generate_letter_bank
  session[:guesses] = []
end

def generate_letter_bank
  qwerty = %w(Q W E R T Y U I O P A S D F G H J K L Z X C V B N M)
  qwerty.each_with_object({}) do |letter, hash|
    hash[letter] = "not-guessed"
  end
end

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
  if @guesses.size > 4 && !won?
    session[:message] = "You ran out of guesses! Try again."
  elsif @guesses.size <= 5 && won?
    session[:message] = "You won!"
  end
end

def won?
  letters_to_check = @guesses[-1].chars.uniq
  letters_to_check.each_with_index do |letter, index|
    return false if guess_letter_class(letter, index) != "correct"
  end
  true
end

def update_letter_bank(guess)
  if valid_guess?(guess)
    word = session[:word]
    letter_bank = session[:letter_bank]
    @guesses << guess
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
    update_letter_bank(guess)
    game_over?
    erb :guest_play
  else
    erb :guest_play
  end
end

get "/:username/play" do
  require_login(params[:username])
  erb :user_play
end

post "/:username/play" do
  require_login(params[:username])
  guess = params[:guess].upcase
  if valid_guess?(guess)
    update_letter_bank(guess)
    game_over?
    erb :user_play
  else
    erb :user_play
  end
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
