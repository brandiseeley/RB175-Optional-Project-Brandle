require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'
require 'csv'
require 'pry-byebug'

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
    word.chars.map { |letter| "<td class=#{letter_bank_class(letter)}>#{letter}</td>" }.join
  end

  def letter_bank_class(letter)
    session[:letter_bank][letter]
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
  session[:word] = CSV.read("wordbank.csv").flatten.sample
  session[:letter_bank] = generate_letter_hash
  session[:guesses] = []
end

def generate_letter_hash  
  ('A'..'Z').each_with_object({}) do |letter, hash|
    hash[letter] = "not-guessed"
  end
end

def valid_guess?(word)
  word.count("a-zA-Z") == 5 && word.length == 5
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
  @letter_bank.count { |letter, state| state == "correct" } == 5
end

def update_letter_bank(guess)
  guess.upcase!
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
  else
    session[:message] = "Guesses must be 5 letter words"
  end
end

get "/" do
  erb :home
end

get "/play" do
  erb :play
end

post "/play" do
  guess = params[:guess]
  update_letter_bank(guess)
  game_over?
  erb :play
end

get "/reset" do
  session.clear
  redirect "/play"
end
