#!/usr/bin/env ruby
require 'json'
require 'sinatra'

get '/square/:number' do
  sleep 0.1
  [Integer(params[:number])**2].to_json
end

get '/cube/:number' do
  sleep 0.1
  [Integer(params[:number])**3].to_json
end
