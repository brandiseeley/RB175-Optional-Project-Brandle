require "csv"

# Pull random word
# create alphabet hash, key :not_guessed (light grey)
                          # :correctly_guessed (green)
                          # :present_somewhere (yellow)
                          # :not_present (dark grey)
# prompt a guess
# 


class Brandle
  attr_reader :guesses, :letter_bank, :word

  def initialize
    @guesses = []
    @letter_bank = generate_letter_hash
    @word = generate_word
    @letters = @word.chars
  end

  def play
    puts "Welcome to Brandle. Make a guess"
    puts "the secret word is #{@word}"
    5.times do |_|
      # guess = gets.chomp
      # make_guess(guess)
      # puts @letter_bank
    end
  end



