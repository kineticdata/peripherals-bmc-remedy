# Require the dependencies file to load the vendor libraries
require File.expand_path(File.join(File.dirname(__FILE__), "dependencies"))

class ArsRestApiV1
  # ==== Parameters
  # * +input+ - The String of Xml that was built by evaluating the node.xml handler template.
  def initialize(input)
    # Set the input document attribute
    @input_document = REXML::Document.new(input)

    # Retrieve all of the handler info values and store them in a hash variable named @info_values.
    @info_values = {}
    REXML::XPath.each(@input_document, "/handler/infos/info") do |item|
      @info_values[item.attributes["name"]] = item.text.to_s.strip
    end
	
    # Retrieve all of the handler parameters and store them in a hash variable named @parameters.
    @parameters = {}
    REXML::XPath.each(@input_document, "/handler/parameters/parameter") do |item|
      @parameters[item.attributes["name"]] = item.text.to_s.strip
    end

    @debug_logging_enabled = ["yes","true"].include?(@info_values['enable_debug_logging'].downcase)
    @error_handling = @parameters["error_handling"]

    @api_server = @info_values["api_server"]
    
    #Remove the / if it exists@api_server
    @api_server.chomp!("/")
      
    @api_username = @info_values["api_username"]
    @api_password = @info_values["api_password"]

    @body = @parameters["body"].to_s.empty? ? {} : JSON.parse(@parameters["body"])
    @method = (@parameters["method"] || :get).downcase.to_sym
    @url = "#{@api_server}/arsys/v1/entry#{@parameters["path"]}"
    
    # Add a / to the beginning of the path if it was not provided.
    @url = "#{@api_server}/arsys/v1/entry/#{@parameters["path"]}" if !@parameters["path"].start_with?("/")

    @accept = :json
    @content_type = :json
  end
  
  def execute()
    # Initialize return data
    error_message = nil
    error_key = nil
    response_code = nil
    max_retries = 5
    retries = 0

    begin
      # get access token
      token = get_access_token(@api_server, @api_username, @api_password)
      if token.length == 3  # for example 401 404 500...
        if @error_handling == "Raise Error"
          raise "HTTP ERROR #{token}"
        else  
          error_message = "HTTP ERROR #{token}"
          results="Failed"
        end
      else
        api_route = "#{@url}"
        puts "API ROUTE: #{@method.to_s.upcase} #{api_route}" if @debug_logging_enabled
        puts "BODY: \n #{@body}" if @debug_logging_enabled

        response = RestClient::Request.execute \
          method: @method, \
          url: api_route, \
          payload: @body.to_json, \
          headers: {:content_type => 'application/json', :authorization => "AR-JWT "+token, :accept => @accept}
        response_code = response.code
    end
      rescue RestClient::Exception => e
        
      error = nil
        response_code = e.response.code

        # Attempt to parse the JSON error message.
        begin
          error = JSON.parse(e.response)
          error_message = error["error"]
          error_key = error["errorKey"] || ""
        rescue Exception
          puts "There was an error parsing the JSON error response" if @debug_logging_enabled
          error_message = e.inspect
        end

        # Raise the error if instructed to, otherwise will fall through to
        # return an error message.
        raise if @error_handling == "Raise Error"
    end
	
    # Return (and escape) the results that were defined in the node.xml
    <<-RESULTS
    <results>
      <result name="Response Body">#{escape(response.nil? ? {} : response.body)}</result>
      <result name="Response Code">#{escape(response_code)}</result>
      <result name="Handler Error Message">#{escape(error_message)}</result>
    </results>
    RESULTS
  end
  
  def get_access_token(api_server, api_username, api_password)
    params = {
      'username' => @api_username,
      'password' => @api_password
    }
    puts('Getting access token') if @debug_logging_enabled
    begin
      #this method will not raise an error if the call does not work.
      response = RestClient::Request.new({
        method: :post,
        url: "#{@api_server}/jwt/login",
        payload: params,
        headers: { :content_type => :'application/x-www-form-urlencoded' }
      }).execute do |response, request, result|
        #if sucessful code will be 200 and the body will be the token for further calls
        #if there is an error response.body will contain the errror in HTML
        if response.code == 200
          puts('Token successfully retrieved') if @debug_logging_enabled
          return response.body
        else
          return response.code.to_s
        end
      end
    rescue Errno::ECONNREFUSED
      return "408"
    end
  end

  ##############################################################################
  # General handler utility functions
  ##############################################################################

  # This is a template method that is used to escape results values (returned in
  # execute) that would cause the XML to be invalid.  This method is not
  # necessary if values do not contain character that have special meaning in
  # XML (&, ", <, and >), however it is a good practice to use it for all return
  # variable results in case the value could include one of those characters in
  # the future.  This method can be copied and reused between handlers.
  def escape(string)
    # Globally replace characters based on the ESCAPE_CHARACTERS constant
    string.to_s.gsub(/[&"><]/) { |special| ESCAPE_CHARACTERS[special] } if string
  end
  # This is a ruby constant that is used by the escape method
  ESCAPE_CHARACTERS = {'&'=>'&amp;', '>'=>'&gt;', '<'=>'&lt;', '"' => '&quot;'}
end
 