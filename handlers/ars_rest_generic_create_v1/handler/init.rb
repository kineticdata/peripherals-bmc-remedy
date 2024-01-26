# Require the dependencies file to load the vendor libraries
require File.expand_path(File.join(File.dirname(__FILE__), "dependencies"))

class ArsRestGenericCreateV1
  # Prepare for execution by building Hash objects for necessary values,
  # and validating the present state.  This method sets the following instance variables:
  # * @input_document - A REXML::Document object that represents the input Xml.
  # * @debug_logging_enabled - A Boolean value indicating whether logging should
  #   be enabled or disabled.
  # * @parameters - A Hash of parameter names to parameter values.
  # * @field_values - A Hash of User database field names
  #   to the values that will be set on the submission record.
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
	
    # Determine if debug logging is enabled. Value is set in the info.xml.
    @debug_logging_enabled = get_info_value(@input_document, 'enable_debug_logging') == 'Yes'
    puts("Logging enabled.") if @debug_logging_enabled

    # Store parameters from the node.xml in a hash attribute named @parameters.
    @parameters = {}
    REXML::XPath.match(@input_document, '/handler/parameters/parameter').each do |node|
      @parameters[node.attribute('name').value] = node.text
    end
    puts(format_hash("Handler Parameters:", @parameters)) if @debug_logging_enabled

    # Initialize an Array to track any errors that come up during validation.
    errors = []

    # If there are any errors in the errors Array, raise an exception that contains
    # all of the error messages.
    if errors.any?
      raise %|The following errors were found while validating the parameters:\n#{errors.join("\n")}|
    end
	
  end

  
  
  # Updates the value of the fields on the User record
  #
  # This is a required method that is automatically called by the Kinetic Task
  # Engine.
  #
  # ==== Returns
  # An Xml formatted String representing the return variable results.
  # No records returned by this handler
  def execute()
  
    error_message=""
	  results=""
    return_location = ""
	  newitem_request_id=""
    @error_handling  = @parameters["error_handling"]
	  api_username    = URI.encode(@info_values["api_username"])
    api_password    = @info_values["api_password"]
    api_server      = @info_values["api_server"]
    @field_values = JSON.parse(@parameters['field_values'])
	  puts(format_hash("Field Values:", @field_values)) if @debug_logging_enabled
    form = URI.encode(@parameters['form'])

    # get access token
    token = get_access_token(api_server, api_username, api_password)
    if token.length == 3  # for example 401 404 500...
      if @error_handling == "Raise Error"
        raise "HTTP ERROR #{token}"
      else  
        error_message = "HTTP ERROR #{token}"
        results="Failed"
      end
    else
      # format the headers with the token
      headers = {:content_type => 'application/json', :authorization => "AR-JWT "+token, :accept => @accept}
      puts(format_hash("Headers: ", headers)) if @debug_logging_enabled
      
      if error_message==""
      
        @field_values.reject!{|key,value|
          (value.nil? or value.empty?)
        }
        # walk the field values hash to check for a Null keyword - nil
        @field_values.each_key {|key|
          if (@field_values[key] == "nil")
            @field_values[key] = nil
          end
        }
        request = { "values" => @field_values}
        puts(format_hash("Body: ", request)) if @debug_logging_enabled
        request = request.to_json
      
        create_route = "#{api_server}/arsys/v1/entry/#{form}"
        puts("CREATE ROUTE: #{create_route}") if @debug_logging_enabled
      
        response = RestClient::Request.new({
          method: :post,
          url: "#{create_route}",
          payload: request,
          headers: headers
        }).execute do |response, request, result|
          puts (response.body)
          if response.code == 201
            results="Successful"
            # response.headers contains the url location of the newly created record
            puts(format_hash("Returned Headers: ", response.headers)) if @debug_logging_enabled
            return_location = response.headers[:location]
            puts("Return Location: #{return_location}") if @debug_logging_enabled
      
            #parse the record ID off the location
            location_details = return_location.split('/')
            newitem_request_id = location_details.last
            #get the record 
            #newitem_resource = RestClient::Resource.new(return_location)
            #newitem_reponse = newitem_resource.get(:authorization => "AR-JWT "+token)
            #newitem_parsed = JSON.parse(newitem_reponse)
            #puts("New Item: #{newitem_parsed}") if @debug_logging_enabled
          
          else	
            if @error_handling == "Raise Error"
              raise "ERROR: #{response.code} #{JSON.parse(response.body)[0]['messageText']}"
            else  
              error_message = "ERROR: #{response.code} #{JSON.parse(response.body)[0]['messageText']}"
              results="Failed"
            end
          end
        end
      end
    end

    # Return the results
    results = <<-RESULTS
    <results>
	  <result name="Handler Error Message">#{escape(error_message)}</result>
      <result name="Result">#{escape(results)}</result>
      <result name="Record Location">#{escape(return_location)}</result>
	  <result name="Record ID">#{escape(newitem_request_id)}</result>
    </results>
    RESULTS
    puts("Results: \n#{results}") if @debug_logging_enabled
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
          puts(result.body) if @debug_logging_enabled
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
 