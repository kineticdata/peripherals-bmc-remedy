# Require the dependencies file to load the vendor libraries
require File.expand_path(File.join(File.dirname(__FILE__), "dependencies"))

class BmcCmdb9MemoryCreateV1
  # Prepare for execution by building Hash objects for necessary values and
  # validating the present state.  This method sets the following instance
  # variables:
  # * @input_document - A REXML::Document object that represents the input Xml.
  # * @info_values - A Hash of info names to info values.
  # * @parameters - A Hash of parameter names to parameter values.
  #
  # This is a required method that is automatically called by the Kinetic Task
  # Engine.
  #
  # ==== Parameters
  # * +input+ - The String of Xml that was built by evaluating the node.xml
  #   handler template.
  def initialize(input)
    # Set the input document attribute
    @input_document = REXML::Document.new(input)
    
    # Retrieve all of the handler info values and store them in a hash variable named @info_values.
    @info_values = {}
    REXML::XPath.each(@input_document, "/handler/infos/info") do |item|
      @info_values[item.attributes["name"]] = item.text.to_s.strip
    end
	
	# Determine if debug logging is enabled.
    @debug_logging_enabled = get_info_value(@input_document, 'enable_debug_logging') == 'Yes'
    puts("Logging enabled.") if @debug_logging_enabled

    # Retrieve all of the handler parameters and store them in a hash variable named @parameters.
    @parameters = {}
    REXML::XPath.each(@input_document, "/handler/parameters/parameter") do |item|
      @parameters[item.attributes["name"]] = item.text.to_s.strip
    end
	puts(format_hash("Handler Parameters:", @parameters)) if @debug_logging_enabled
  end

  # The execute method gets called by the task engine when the handler's node is processed. It is
  # responsible for performing whatever action the name indicates.
  # If it returns a result, it will be in a special XML format that the task engine expects. These
  # results will then be available to subsequent tasks in the process.
  def execute
    @error_handling  = @parameters["error_handling"]
    api_username    = URI.encode(@info_values["api_username"])
    api_password    = @info_values["api_password"]
    api_server      = @info_values["api_server"]
	dataset  		= URI.encode(@parameters["dataset"])
	namespace  		= URI.encode(@parameters["namespace"])
	request = { "attributes" => { "Name"=> @parameters["name"] }}
	puts(format_hash("Body: ", request)) if @debug_logging_enabled
	request = request.to_json

    api_route = "#{api_server}/cmdb/v1/instance/#{dataset}/#{namespace}/BMC_Memory/"

	puts("API ROUTE: #{api_route}") if @debug_logging_enabled

    resource = RestClient::Resource.new(api_route)
	
	token = get_access_token(api_server, api_username, api_password)

	headers = {:content_type => 'application/json', :authorization => "AR-JWT "+token}
	puts(format_hash("Headers: ", headers)) if @debug_logging_enabled
	
    response = resource.post(request, headers)

	returnedHeaders = response.headers
	puts(format_hash("Returned Headers: ", returnedHeaders)) if @debug_logging_enabled
	returnedId = returnedHeaders[:location].gsub(api_route, "")
	puts("Results: #{returnedId}") if @debug_logging_enabled
    #submission = JSON.parse(response)      

    # Build the results to be returned by this handler
    @results = "<results>"
    @results += "<result name='Instance ID'>#{escape(returnedId)}</result>"
    @results += "</results>"

	  
	  rescue RestClient::Exception => error
	  puts error.response if @debug_logging_enabled
       error_message = JSON.parse(error.response)[0]
      if @error_handling == "Raise Error"
        raise error_message
      else
        @results = "<results>"
        @results += "<result name='Handler Error Message'>#{error.http_code}: #{escape(error_message)} </result>"
		@results += "<result name='Instance ID'></result>"
        @results += "</results>"
        @results
      end
  end

  def get_access_token(api_server, username, password)
    params = {
      'username' => username,
      'password' => password
    }
	puts('Logging in') if @debug_logging_enabled
	
	loginResource = RestClient::Resource.new(api_server+"/jwt/login")
    result = loginResource.post(params, :content_type => 'application/x-www-form-urlencoded')
	puts(result.body) if @debug_logging_enabled
    return result.body
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
  def format_hash(header, hash)
    # Staring with the "header" parameter string, concatenate each of the
    # parameter name/value pairs with a prefix intended to better display the
    # results within the Kinetic Task log.
    hash.inject(header) do |result, (key, value)|
      result << "\n    #{key}: #{value}"
    end
  end
  
  
  # This is a sample helper method that illustrates one method for retrieving
  # values from the input document.  As long as your node.xml document follows
  # a consistent format, these type of methods can be copied and reused between
  # handlers.
  def get_info_value(document, name)
    # Retrieve the XML node representing the desird info value
    info_element = REXML::XPath.first(document, "/handler/infos/info[@name='#{name}']")
    # If the desired element is nil, return nil; otherwise return the text value of the element
    info_element.nil? ? nil : info_element.text
  end
  
  def escape(string)
    # Globally replace characters based on the ESCAPE_CHARACTERS constant
    string.to_s.gsub(/[&"><]/) { |special| ESCAPE_CHARACTERS[special] } if string
  end
  # This is a ruby constant that is used by the escape method
  ESCAPE_CHARACTERS = {
    "&" => "&amp;",
    "<" => "&lt;",
    ">" => "&gt;",
    "'" => "&#39;",
    '"' => "&quot;",
    "/" => "&#47;",
    "#" => "&#35;",
    " " => "&nbsp;",
    "\\" => "&#92;",
    "\r" => "<br>",
    "\n" => "<br>"
  }
end