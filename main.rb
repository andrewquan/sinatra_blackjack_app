require 'rubygems'
require 'sinatra'
require 'pry'

use Rack::Session::Cookie, :key => 'rack.session',
                           :path => '/',
                           :secret => 'secret_string' 

BLACKJACK_AMOUNT = 21
DEALER_HIT_MIN = 17
STARTING_POT_AMOUNT = 500

helpers do
  def calculate_total(cards)
    arr = cards.map {|card| card[1]}

    total = 0
    arr.each do |value|
      if value == 'A'
        total += 11
      else
        total += (value.to_i == 0 ? 10 : value.to_i)
      end
    end

    arr.select {|value| value == 'A'}.count.times do
      break if total <= BLACKJACK_AMOUNT
      total -= 10
    end

    total
  end

  def card_image(card)
    suit = case card[0]
      when 'H' then 'hearts'
      when 'D' then 'diamonds'
      when 'C' then 'clubs'
      when 'S' then 'spades'
    end

    value = card[1]
    if ['J', 'Q', 'K', 'A'].include?(value)
      value = case card[1]
        when 'J' then 'jack'
        when 'Q' then 'queen'
        when 'K' then 'king'
        when 'A' then 'ace'
      end
    end

    "<img src='/images/cards/#{suit}_#{value}.jpg' class='card_image'>"
  end

  def winner!(msg)
    @winner = "<strong>#{session[:player_name]} wins!</strong> #{msg}"
    session[:player_pot] += session[:player_bet]
    @play_again = true
  end

  def loser!(msg)
    @loser = "<strong>#{session[:player_name]} loses!</strong> #{msg}"
    session[:player_pot] -= session[:player_bet]
    if session[:player_pot] == 0
      @broke = true
    else
      @play_again = true
    end
  end

  def tie!(msg)
    @tie = "<strong>It's a tie! #{msg}</strong>"
    @play_again = true
  end
end

before do
  @show_hit_or_stay_buttons = true
  @show_flop = true
end

get '/' do
  session[:player_pot] = STARTING_POT_AMOUNT
  erb :new_game
end

post '/new_game' do
  if params[:player_name].empty?
    @error = "Name is required."
    halt erb :new_game
  end
  session[:player_name] = params[:player_name]
  redirect '/bet'
end

get '/bet' do
  session[:player_pot]
  erb :bet
end

post '/bet' do
  if params[:bet_amount].empty? || params[:bet_amount].to_i == 0
    @error = "Please enter an amount to bet."
    halt erb :bet
  elsif params[:bet_amount].to_i > session[:player_pot]
    @error = "#{session[:player_name]} doesn't have that much money to bet!"
    halt erb :bet
  else
    session[:player_bet] = params[:bet_amount].to_i
  end
  redirect '/game'
end

get '/game' do
  suits = ['H', 'D', 'C', 'S']
  values = ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'A']
  session[:deck] = suits.product(values).shuffle!

  session[:dealer_cards] = []
  session[:player_cards] = []
  session[:dealer_cards] << session[:deck].pop
  session[:player_cards] << session[:deck].pop
  session[:dealer_cards] << session[:deck].pop
  session[:player_cards] << session[:deck].pop

  if calculate_total(session[:player_cards]) == BLACKJACK_AMOUNT
    winner!("#{session[:player_name]} hit Blackjack!")
    @show_hit_or_stay_buttons = false
    @info = false
  end

  erb :game
end

post '/game/player/hit' do
  session[:player_cards] << session[:deck].pop
  if calculate_total(session[:player_cards]) == BLACKJACK_AMOUNT
    winner!("#{session[:player_name]} hit Blackjack!")
    @show_hit_or_stay_buttons = false
    @show_dealer_total = true
    @show_flop = false
  elsif calculate_total(session[:player_cards]) > BLACKJACK_AMOUNT
    loser!("#{session[:player_name]} busted!")
    @show_hit_or_stay_buttons = false
    @show_dealer_total = true
    @show_flop = false
  end

  erb :game, layout: false
end

post '/game/player/stay' do
  @success = "You chose to stay."
  @show_hit_or_stay_buttons = false
  redirect '/game/dealer'
end

get '/game/dealer' do
  @show_hit_or_stay_buttons = false
  @show_dealer_total = true
  @show_flop = false

  dealer_total = calculate_total(session[:dealer_cards])
  if dealer_total == BLACKJACK_AMOUNT
    loser!("The Dealer hit Blackjack.")
  elsif dealer_total > BLACKJACK_AMOUNT
    winner!("The Dealer busted!")
  elsif dealer_total >= DEALER_HIT_MIN
    #dealer stays
    redirect '/game/compare'
  else
    #dealer hits
    @show_dealer_hit_button = true
  end
  erb :game, layout: false
end

post '/game/dealer/hit' do
  session[:dealer_cards] << session[:deck].pop

  redirect '/game/dealer'
end

get '/game/compare' do
  @show_hit_or_stay_buttons = false
  @show_dealer_total = true
  @show_flop = false

  player_total = calculate_total(session[:player_cards])
  dealer_total = calculate_total(session[:dealer_cards])

  if player_total > dealer_total
    winner!("#{session[:player_name]} ended at #{player_total} and the Dealer ended at #{dealer_total}.")
  elsif player_total < dealer_total
    loser!("#{session[:player_name]} ended at #{player_total} and the Dealer ended at #{dealer_total}.")
  else
    tie!("Both #{session[:player_name]} and the Dealer ended at #{player_total}.")
  end

  erb :game, layout: false
end

get '/game_over' do
  erb :game_over
end













