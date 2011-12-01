#!/usr/bin/env ruby
require 'rubygems'
require 'net/http'
require 'json'


class TweetDownloader
  attr_reader :user, :tweet_dir

  # twitter wants 150 requests per hour at max, we're being nice, so we sleep about 30 seconds before doing a new request
  SLEEPY_TIME = 3600 / 120

  def initialize(username, directory)
    raise "username is incorrect: #{username.inspect}" if username.nil? or username.empty?
    @user = username
    @tweet_dir = directory
  end

  # I just realized that I don't know for sure if status ids are increasing...
  def since_id
    Dir.glob("#{tweet_dir}/*.json").map { |f| File.basename(f, ".json").to_i rescue 1 }.max
  end

  def download_tweets(options = {})
    options[:since_id] ||= since_id
    options[:count] ||= 100
    tweets = fetch_page(options)
    STDERR.puts "#{tweets.size} tweets"
    save_tweets(tweets)
    unless tweets.empty?
      sleep (SLEEPY_TIME)
      # twitter starts counting pages at 1 (not a zero)
      download_tweets(options.merge(:page => (options[:page] || 1) + 1))
    end
  end

  def filename(tweet)
    "#{tweet_dir}/#{tweet["id"]}.json"
  end

  def save_tweets(tweets)
    tweets.each do |tweet|
      next if File.exists?(filename(tweet))
      File.open(filename(tweet), 'w') { |f| f.puts tweet.to_json }
      STDERR.puts "#{tweet["created_at"]}\t#{tweet["text"]}"
    end
  rescue
    STDERR.puts tweets.inspect
    raise
  end

  def page_path(options = {})
    path = "/statuses/user_timeline/#{@user}.json"
    unless options.empty?
      opts = options.map do |k,v|
        next if v.nil?
        "#{k}=#{v}"
      end
      "#{path}?#{opts.join("&")}"
    end
  end

  def fetch_page(options = {})
    STDERR.puts "Fetching page... #{options.inspect}"
    json = ""
    req = Net::HTTP.start('twitter.com') do |http|
      http.read_timeout = 600
      response = http.get(page_path(options))
      json = JSON.parse(response.body)
    end
    json
  end
end

