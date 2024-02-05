# Require the dependencies file to load the vendor libraries
require File.expand_path(File.join(File.dirname(__FILE__), "dependencies"))

class ArsRestGenericQueryRetrieveV1
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
	
    # Store parameters in the node.xml in a hash attribute named @parameters.
    @parameters = {}
    REXML::XPath.match(@input_document, '/handler/parameters/parameter').each do |node|
      @parameters[node.attribute('name').value] = node.text
    end
    puts(format_hash("Handler Parameters:", @parameters)) if @debug_logging_enabled
  end

  # The execute method gets called by the task engine when the handler's node is processed. It is
  # responsible for performing whatever action the name indicates.
  # If it returns a result, it will be in a special XML format that the task engine expects. These
  # results will then be available to subsequent tasks in the process.
  def execute
    error_message    = ""
    values          = ""
    @error_handling  = @parameters["error_handling"]
	  api_username     = URI.encode(@info_values["api_username"])
    api_password     = @info_values["api_password"]
    api_server       = @info_values["api_server"]
	  query            = @parameters["request_query"]
    form             = URI.encode(@parameters["form"])

    # get access token
    token = get_access_token(api_server, api_username, api_password)
    if token.length == 3  # for example 401 404 500...
      if @error_handling == "Raise Error"
        raise "HTTP ERROR #{token}"
      else  
        error_message = escape(token)
      end
    else
      # format the headers with the token
      headers = {:content_type => 'application/json', :authorization => "AR-JWT "+token, :accept => @accept}
      puts(format_hash("Headers: ", headers)) if @debug_logging_enabled
            
      create_route = "#{api_server}/arsys/v1/entry/#{form}?q="+URI.encode(query)
      puts("CREATE ROUTE: #{create_route}") if @debug_logging_enabled
    
      response = RestClient::Request.new({
        method: :get,
        url: "#{create_route}",
        payload: "",
        headers: headers
      }).execute do |response, request, result|
        puts("RESPONSE: #{response}") if @debug_logging_enabled
        if response.code == 200
          record_parsed = JSON.parse(response.body)
          if !record_parsed["entries"][0].nil?
            values = ""
            # Build the results to be returned by this handler
            # Build up a list of all field names and values for this record                
            field_values = record_parsed["entries"][0]["values"].each do |key, value|
              values += "<result name='#{escape(key)}'>#{escape(value)}</result>"
            end
          else  
            if @error_handling == "Raise Error"
              raise "No Matching Record Found"
            else
              error_message = "No Matching Record Found"
            end  
          end
        else	
          if @error_handling == "Raise Error"
            raise "ERROR: #{response.code} #{JSON.parse(response.body)[0]['messageText']}"
          else  
            error_message = "ERROR: #{response.code} #{JSON.parse(response.body)[0]['messageText']}"
          end
        end
      end
    end
    
    if error_message != ""
      result = "<result name='Handler Error Message'>#{escape(error_message)}</result>"
    else
      result = values
    end
 
    # Return the results    
    results = <<-RESULTS
      <results>
        #{result}
      </results>
    RESULTS
    puts("Results: \n#{values}") if @debug_logging_enabled
    return results 

  end

  def get_access_token(api_server, username, password)
    params = {
      'username' => username,
      'password' => password
    }
    puts('Logging in') if @debug_logging_enabled
    begin
      #this method will not raise an error if the call does not work.
      response = RestClient::Request.new({
        method: :post,
        url: "#{api_server}/jwt/login",
        payload: params,
        headers: { :content_type => :'application/x-www-form-urlencoded' }
      }).execute do |response, request, result|
        #if sucessful code will be 200 and the body will be the token for further calls
        #if there is an error response.body will contain the errror in HTML
        if response.code == 200
          puts(response.body) if @debug_logging_enabled
          return response.body
        else
          return response.code.to_s
        end
      end
    rescue Errno::ECONNREFUSED
      return "408"
    end
    #this way if there is a problem with the URL or server the command does not fail gracefully
	  #loginResource = RestClient::Resource.new(api_server+"/jwt/login")
    #result = loginResource.post(params, :content_type => 'application/x-www-form-urlencoded')
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

  # Builds a string that is formatted specifically for the Kinetic Task log file
  # by concatenating the provided header String with each of the provided hash
  # name/value pairs.  The String format looks like:
  #   HEADER
  #       KEY1: VAL1
  #       KEY2: VAL2
  # For example, given:
  #   field_values = {'Field 1' => "Value 1", 'Field 2' => "Value 2"}
  #   format_hash("Field Values:", field_values)
  # would produce:
  #   Field Values:
  #       Field 1: Value 1
  #       Field 2: Value 2
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

end