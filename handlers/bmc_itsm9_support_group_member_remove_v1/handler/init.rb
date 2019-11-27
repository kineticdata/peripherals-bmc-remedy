# Require the dependencies file to load the vendor libraries
require File.expand_path(File.join(File.dirname(__FILE__), "dependencies"))

class BmcItsm9SupportGroupMemberRemoveV1
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

    # Retrieve the list of field values that will be written to the approval record
    @field_values = {}
    REXML::XPath.match(@input_document, '/handler/fields/field').each do |node|
      @field_values[node.attribute('name').value] = node.text
    end
    puts(format_hash("Field Values:", @field_values)) if @debug_logging_enabled

	
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
	
	@error_handling  = @parameters["error_handling"]
	api_username    = URI.encode(@info_values["api_username"])
    api_password    = @info_values["api_password"]
    api_server      = @info_values["api_server"]

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
  	  headers = {:content_type => 'application/json', :authorization => "AR-JWT "+token}
	  puts(format_hash("Headers: ", headers)) if @debug_logging_enabled
	
	  #get the People ID for the user
	  person_id = ""
	  query = "'Remedy Login ID' = \""+@parameters["assignee_id"]+"\""
      api_route = "#{api_server}/arsys/v1/entry/CTM:People?q="+URI.encode(query)

	  puts("API ROUTE: #{api_route}") if @debug_logging_enabled
	  person_login_id = ""
      # retreive the record by the search query to get the Request ID
	  user_reponse = RestClient::Request.new({
        method: :get,
        url: "#{api_route}",
	    headers: headers
      }).execute do |response, request, result|
        results = response.code
	    puts response.code
	    if response.code == 200
          puts(result.body) if @debug_logging_enabled
		  user_parsed = JSON.parse(response)
	      puts("People Response: #{response}") if @debug_logging_enabled
		  if user_parsed["entries"][0].nil?
	        if @error_handling == "Raise Error"
	          raise "No Record Found for #{@parameters["assignee_id"]}"
		    else  
              error_message = "No Record Found for #{@parameters["assignee_id"]}"
			  results="Failed"
		    end
	      else
	        puts("Person Login ID: #{user_parsed["entries"][0]["values"]["Person ID"]}") if @debug_logging_enabled
			person_id = user_parsed["entries"][0]["values"]["Person ID"]
	      end
	    else
		  puts (response.body)
          if @error_handling == "Raise Error"
	        raise result.body
		  else  
	        error_message = "ERROR #{response.code} while retreiving people record."
			results="Failed"
		  end
        end
      end
	
	
		
	  support_group_id = ""
	  support_query = "'Company' = \""+@parameters["support_company"]+"\" AND 'Support Organization' = \""+@parameters["support_org"]+"\" AND 'Support Group Name' = \""+@parameters["support_group_name"]+"\" "
      support_route = "#{api_server}/arsys/v1/entry/CTM:Support%20Group?q="+URI.encode(support_query)

	  puts("SUPPORT ROUTE: #{support_route}") if @debug_logging_enabled
	  
      # retreive the record by the search query to get the Request ID
      user_reponse = RestClient::Request.new({
        method: :get,
        url: "#{support_route}",
	    headers: headers
      }).execute do |response, request, result|
        results = response.code
	    puts response.code
	    if response.code == 200
          puts(result.body) if @debug_logging_enabled
		  support_parsed = JSON.parse(response)
	      puts("Support Response: #{response}") if @debug_logging_enabled
		  if support_parsed["entries"][0].nil?
	        if @error_handling == "Raise Error"
	          raise "No Record Found for 'Company' = '#{@parameters["support_company"]}' AND 'Support Organization' = '#{@parameters["support_org"]}' AND 'Support Group Name' = '#{@parameters["support_group_name"]}'"
		    else  
              error_message = "No Record Found for 'Company' = '#{@parameters["support_company"]}' AND 'Support Organization' = '#{@parameters["support_org"]}' AND 'Support Group Name' = '#{@parameters["support_group_name"]}'"
			  results="Failed"
		    end
	      else
            support_group_id = support_parsed["entries"][0]["values"]["Support Group ID"] 
	        puts("Support Group ID: #{support_parsed["entries"][0]["values"]["Support Group ID"]}") if @debug_logging_enabled
	      end
	    else
          if @error_handling == "Raise Error"
	        raise result.body
		  else  
	        error_message = "ERROR #{response.code} while retreiving support record."
			results="Failed"
		  end
        end
      end
	
	
	 # retreive the record by the search query to get the Request ID for the CTM:Support Group Association
	 
	  association_query = "'Support Group ID' = \""+support_group_id+"\" AND 'Person ID' = \""+person_id+"\""
      association_route = "#{api_server}/arsys/v1/entry/CTM:Support%20Group%20Association?q="+URI.encode(association_query)
	 
	  support_group_association_id = ""
	  user_reponse = RestClient::Request.new({
        method: :get,
        url: "#{association_route}",
	    headers: headers
      }).execute do |response, request, result|
        results = response.code
	    puts response.code
	    if response.code == 200
          puts(result.body) if @debug_logging_enabled
		  association_parsed = JSON.parse(response)
	      puts("People Response: #{response}") if @debug_logging_enabled
		  if association_parsed["entries"][0].nil?
	        if @error_handling == "Raise Error"
	          raise "No Record Found for #{@parameters["assignee_id"]}"
		    else  
              error_message = "No Record Found for #{@parameters["assignee_id"]}"
			  results="Failed"
		    end
	      else
	        puts("Support Group Association ID: #{association_parsed["entries"][0]["values"]["Support Group Association ID"]}") if @debug_logging_enabled
			support_group_association_id = association_parsed["entries"][0]["values"]["Support Group Association ID"]
	      end
	    else
		  puts (response.body)
          if @error_handling == "Raise Error"
	        raise result.body
		  else  
	        error_message = "ERROR #{response.code} while retreiving people record."
			results="Failed"
		  end
        end
      end
	
	
	
	
	
	
	
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
	
	  delete_route = "#{api_server}/arsys/v1/entry/CTM:Support%20Group%20Association/"+support_group_association_id
	  puts("DELETE ROUTE: #{delete_route}") if @debug_logging_enabled

      response = RestClient::Request.new({
        method: :delete,
        url: "#{delete_route}",
	    headers: headers
      }).execute do |response, request, result|
          
		if response.code == 204
		  results="Successful"
		  
	      puts(format_hash("Returned Headers: ", response.headers)) if @debug_logging_enabled
	      return_location = response.headers[:location]
	      puts("Return Location: #{return_location}") if @debug_logging_enabled
	

		else	
		  puts("Error Dump: #{response.body}") if @debug_logging_enabled
	      if @error_handling == "Raise Error"
            raise "ERROR: #{response.code} #{JSON.parse(response.body)[0]['messageText']}"
		  else  
	        error_message = "ERROR: #{response.code} #{JSON.parse(response.body)[0]['messageText']}"
		    results="Failed"
		  end
        end
      end
    end

    # Return the results
    results = <<-RESULTS
    <results>
	  <result name="Handler Error Message">#{escape(error_message)}</result>
      <result name="Result">#{escape(results)}</result>
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
      results = response.code
	  #if sucessful code will be 200 and the body will be the token for further calls
	  #if there is an error response.body will contain the errror in HTML
	  if response.code == 200
        puts(result.body) if @debug_logging_enabled
        return result.body
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
	#
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
 