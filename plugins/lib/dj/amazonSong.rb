require 'vacuum' # amazon
require_relative '../logging'
require 'pp'

class AmazonSong < Song
  include Logging

  attr_reader :asin

  # Example URLs:
  # http://www.amazon.com/dp/B000SXKPYU/ref=dm_ws_tlw_trk1
  # http://www.amazon.com/gp/product/B007T2XCIY/
  def initialize(
      properties = {}
  )
    super
    @id   = properties['id']
  end

  def auth(key, secret)
    @auth = {
      :key => key,
      :secret => secret
    }
  end

  def process(url)

    amazon = Vacuum::Request.new

    amazon.configure(
        aws_access_key_id: @auth[:key],
        aws_secret_access_key: @auth[:secret],
        associate_tag: 'tag'
    )

    itemid = _itemid(url)

    resp_hash = Hash.new

    begin
      response = amazon.item_lookup(
          query: {
              :ItemId => itemid,
              :ResponseGroup => %w(RelatedItems Small).join(','),
              :RelationshipType => 'Tracks'
          }
      )

      resp_hash = response.to_h
      if resp_hash['ItemLookupResponse']['Items']['Request']['Errors']
        raise resp_hash['ItemLookupResponse']['Items']['Request']['Errors']['Error']['Message']
      end
    rescue Exception => e
      # TODO: log this error somewhere
      logger.warn("Amazon request failed: #{e.message}.")
      raise("Amazon request failed: #{e.message}.")
    end

    item = resp_hash['ItemLookupResponse']['Items']['Item']

    @id = item['ASIN']

    self.title  = item['ItemAttributes']['Title']
    self.artist = item['ItemAttributes']['Creator']['__content__']
    self.album  = item['RelatedItems']['RelatedItem']['Item']['ItemAttributes']['Title']
    self.url    = item['DetailPageURL']

    return true

  end

  def to_h
    super.merge(
    {
        :id => @id
    })
  end

  def to_json(*a)
    {
        :json_class => self.class.name,
        :data => self.to_h
    }.to_json(*a)
  end

  def self.json_create(*o)
    new(
        o[0]['data']

    )
  end

  private

  # @param [URI] url
  def _itemid(url)
    item_id = nil
    parts = URI(url).path.split('/')
    parts.each_with_index do |url_part, i|
      case url_part
        when 'dp'
          item_id = parts[i+1] || nil
          return item_id
        when 'product'
          item_id = parts[i+1] || nil
          return item_id
        else
          # do nothing
      end

    end

    item_id
  end

end