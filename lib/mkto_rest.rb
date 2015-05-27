require_relative "mkto_rest/version"
require_relative "mkto_rest/http_utils"
require_relative "mkto_rest/lead"
require "json"

module MktoRest
  class Client
    attr_reader :host, :client_id, :client_secret, :token, :expires_in, :valid_until, :token_type, :scope, :last_request_id
    def initialize(options = {})
      @host = options[:host]
      @client_id = options[:client_id]
      @client_secret = options[:client_secret]
      @options = {}
      @token = ''
    end

    #sets / unsets debug mode
    def debug=(bool)
      MktoRest::HttpUtils.debug = bool
    end

    def authenticated?
      return !@token.empty? && token_valid?
    end

    def token_valid?
      @valid_until && Time.now < @valid_until
    end

    # used for testing only
    def __auth(token, validity = nil)
      @token = token
      @valid_until = validity || Time.now  + 3600
    end


    # \options:
    #    open_timeout - http open timeout
    #    read_timeout - http read timeout
    def authenticate(options = {})
      args = {
        grant_type: 'client_credentials',
        client_id: @client_id,
        client_secret: @client_secret
      }
      @options = options
      body = MktoRest::HttpUtils.get("https://#{@host}/identity/oauth/token", args, @options)
      raise RuntimeError.new("response empty.") if body.nil?
      data = JSON.parse(body, { symbolize_names: true })
      raise RuntimeError.new(data[:error_description]) if data[:error]
      @token = data[:access_token]
      @token_type = data[:token_type]
      @expires_in = data[:expires_in]
      @valid_until = Time.now + data[:expires_in]
      @scope = data[:scope]
    end

    def get_leads(filtr, values = [], fields = [], &block)
      self.authenticate unless self.authenticated?
      # values can be a string or an array
      values = values.split() unless values.is_a? Array
      args = {
        access_token: @token,
        filterType: filtr.to_s,
        filterValues: values.join(','),
      }
      args[:fields] = fields.join(',') unless fields.empty?
      body = MktoRest::HttpUtils.get("https://#{@host}/rest/v1/leads.json", args, @options)
      raise RuntimeError.new("response empty.") if body.nil?
      data = JSON.parse(body, { symbolize_names: true })
      @last_request_id = data[:requestId]
      raise RuntimeError.new(data[:errors].to_s) if data[:success] == false
      leads = []
      data[:result].each do |lead_attributes|
        l = Lead.new(self, lead_attributes)
        block.call l unless block.nil?
        leads << l
      end unless data[:result].empty?
      leads
    end

    def create_leads(leads, action="createOnly", partition=nil, lookupField=nil)
      # leads is an array of objects like:
      #   {
      #    "email":"kjashaedd-3@klooblept.com",
      #    "firstName":"Kataldar-3",
      #    "postalCode":"04828"
      #   }
      # maximium length of leads = 300

      self.authenticate unless self.authenticated?
      data = {
        action: action,
        input: leads
      }
      data[:partitionName] = partition if partition
      data[:lookupField] = lookupField if lookupField
      data = data.to_json
      post data
    end

    def update_lead_by_email(email, values)
      self.authenticate unless self.authenticated?
      data = {
        action: "updateOnly",
        lookupField: 'email',
        input: [
          {
            email: email,
            }.merge(values)
          ]
          }.to_json
      post data
    end

    def update_lead_by_id(id, values)
      self.authenticate unless self.authenticated?
      data = {
        action: "updateOnly",
        lookupField: 'id',
        input: [
          {
            id: id
            }.merge(values)
          ]
          }.to_json
      post data
    end

    def post(data)
      self.authenticate unless self.authenticated?
      headers = {
        "Authorization" => "Bearer #{@token}"
      }
      raise RuntimeError.new("client not authenticated.") unless self.authenticated?
      body = MktoRest::HttpUtils.post("https://#{@host}/rest/v1/leads.json" + "?", headers, data, @options)
      data = JSON.parse(body, { symbolize_names: true })
      raise RuntimeError.new(data[:errors].to_s) if data[:success] == false
      data
    end
  end
end
