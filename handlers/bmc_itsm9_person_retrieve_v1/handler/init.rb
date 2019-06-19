# Require the dependencies file to load the vendor libraries
require File.expand_path(File.join(File.dirname(__FILE__), "dependencies"))

class BmcItsm9PersonRetrieveV1
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

    # Retrieve all of the handler fields and store them in a hash variable named @fields.
    @fields = {}
    REXML::XPath.each(@input_document, "/handler/fields/field") do |item|
      @fields[item.attributes["name"]] = item.text.to_s.strip
    end
	puts(format_hash("Handler fields:", @fields)) if @debug_logging_enabled
	
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
    @error_handling  = @parameters["error_handling"]
	api_username    = URI.encode(@info_values["api_username"])
    api_password    = @info_values["api_password"]
    api_server      = @info_values["api_server"]
	query = "'Remedy Login ID' = \""+@parameters["remedy_login_id"]+"\""
    api_route = "#{api_server}/arsys/v1/entry/CTM:People?q="+URI.encode(query)

	puts("API ROUTE: #{api_route}") if @debug_logging_enabled

    resource = RestClient::Resource.new(api_route)
	
	token = get_access_token(api_server, api_username, api_password)

	headers = {:content_type => 'application/json', :authorization => "AR-JWT "+token}
	puts(format_hash("Headers: ", headers)) if @debug_logging_enabled
	 

	person_route = api_route 
	person_resource = RestClient::Resource.new(person_route)
	person_reponse = person_resource.get(:authorization => "AR-JWT "+token)
	person_parsed = JSON.parse(person_reponse)
	puts("Response: #{person_reponse}") if @debug_logging_enabled

	if person_parsed["entries"][0].nil?
	  raise "No Person Record Found"
	end
	
    personNumber = person_parsed["entries"][0]["values"]["Person ID"]  
	puts("Person Number: #{personNumber}") if @debug_logging_enabled
	
	
    # Build the results to be returned by this handler
    @results = "<results>"
	@results += "<result name='Remedy Login ID'>#{escape(person_parsed["entries"][0]["values"]['Remedy Login ID'])}</result>"
    @results += "<result name='Email'>#{escape(person_parsed["entries"][0]["values"]['Internet E-mail'])}</result>"
    @results += "<result name='First Name'>#{escape(person_parsed["entries"][0]["values"]['First Name'])}</result>"
    @results += "<result name='Middle Initial'>#{escape(person_parsed["entries"][0]["values"]['Middle Initial'])}</result>"
    @results += "<result name='Last Name'>#{escape(person_parsed["entries"][0]["values"]['Last Name'])}</result>"
    @results += "<result name='Job Title'>#{escape(person_parsed["entries"][0]["values"]['JobTitle'])}</result>"
     @results += "<result name='Nick Name'>#{escape(person_parsed["entries"][0]["values"]['Nick Name'])}</result>"
    @results += "<result name='Corporate ID'>#{escape(person_parsed["entries"][0]["values"]['Corporate ID'])}</result>"
     @results += "<result name='Profile Status'>#{escape(person_parsed["entries"][0]["values"]['Profile Status'])}</result>"
    @results += "<result name='Contact Type'>#{escape(person_parsed["entries"][0]["values"]['Contact Type'])}</result>"
    @results += "<result name='Client Sensitivity'>#{escape(person_parsed["entries"][0]["values"]['Client Sensitivity'])}</result>"
    @results += "<result name='VIP'>#{escape(person_parsed["entries"][0]["values"]['VIP'])}</result>"
    @results += "<result name='Support Staff'>#{escape(person_parsed["entries"][0]["values"]['Support Staff'])}</result>"
    @results += "<result name='Assignment Availability'>#{escape(person_parsed["entries"][0]["values"]['Assignment Availability'])}</result>"
    @results += "<result name='Company'>#{escape(person_parsed["entries"][0]["values"]['Company'])}</result>"
    @results += "<result name='Organization'>#{escape(person_parsed["entries"][0]["values"]['Organization'])}</result>"
    @results += "<result name='Department'>#{escape(person_parsed["entries"][0]["values"]['Department'])}</result>"
    @results += "<result name='Region'>#{escape(person_parsed["entries"][0]["values"]['Region'])}</result>"
    @results += "<result name='Site Group'>#{escape(person_parsed["entries"][0]["values"]['Site Group'])}</result>"
    @results += "<result name='Site'>#{escape(person_parsed["entries"][0]["values"]['Site'])}</result>"
    @results += "<result name='Desk Location'>#{escape(person_parsed["entries"][0]["values"]['Desk Location'])}</result>"
    @results += "<result name='Mail Station'>#{escape(person_parsed["entries"][0]["values"]['Mail Station'])}</result>"
    @results += "<result name='Phone Number Business'>#{escape(person_parsed["entries"][0]["values"]['Phone Number Business'])}</result>"
    @results += "<result name='Phone Number Mobile'>#{escape(person_parsed["entries"][0]["values"]['Phone Number Mobile'])}</result>"
    @results += "<result name='Phone Number Fax'>#{escape(person_parsed["entries"][0]["values"]['Phone Number Fax'])}</result>"
    @results += "<result name='Phone Number Pager'>#{escape(person_parsed["entries"][0]["values"]['Phone Number Pager'])}</result>"
    @results += "<result name='ACD Phone Num'>#{escape(person_parsed["entries"][0]["values"]['ACD Phone Num'])}</result>"
    @results += "<result name='Corporate E-Mail'>#{escape(person_parsed["entries"][0]["values"]['Corporate E-Mail'])}</result>"
    @results += "<result name='Accounting Number'>#{escape(person_parsed["entries"][0]["values"]['Accounting Number'])}</result>"
    @results += "<result name='ManagersName'>#{escape(person_parsed["entries"][0]["values"]['ManagersName'])}</result>"
    @results += "<result name='ManagerLoginID'>#{escape(person_parsed["entries"][0]["values"]['ManagerLoginID'])}</result>"
    @results += "<result name='Cost Center Code'>#{escape(person_parsed["entries"][0]["values"]['Cost Center Code'])}</result>"
	@results += "<result name='Handler Error Message'></result>"
    @results += "</results>"
	puts(@results) if @debug_logging_enabled	
	@results
	  rescue RestClient::Exception => error
	  puts error.response if @debug_logging_enabled
       error_message = JSON.parse(error.response)[0]
      if @error_handling == "Raise Error"
        raise error_message
      else
        @results = "<results>"
		@results += "	<result name='Remedy Login ID'></result>"
    @results += "	<result name='Email'></result>"
    @results += "	<result name='First Name'></result>"
    @results += "	<result name='Middle Initial'></result>"
    @results += "	<result name='Last Name'></result>"
    @results += "	<result name='Job Title'></result>"
     @results += " <result name='Nick Name'></result>"
    @results += "  <result name='Corporate ID'></result>"
     @results += " <result name='Profile Status'></result>"
    @results += "  <result name='Contact Type'></result>"
    @results += "  <result name='Client Sensitivity'></result>"
    @results += "  <result name='VIP'></result>"
    @results += "  <result name='Support Staff'></result>"
    @results += "  <result name='Assignment Availability'></result>"
    @results += "  <result name='Company'></result>"
    @results += "  <result name='Organization'></result>"
    @results += "  <result name='Department'></result>"
    @results += "  <result name='Region'></result>"
    @results += "  <result name='Site Group'></result>"
    @results += "  <result name='Site'></result>"
    @results += "  <result name='Desk Location'></result>"
    @results += "  <result name='Mail Station'></result>"
    @results += "  <result name='Phone Number Business'></result>"
    @results += "  <result name='Phone Number Mobile'></result>"
    @results += "  <result name='Phone Number Fax'></result>"
    @results += "  <result name='Phone Number Pager'></result>"
    @results += "  <result name='ACD Phone Num'></result>"
    @results += "  <result name='Corporate E-Mail'></result>"
    @results += "  <result name='Accounting Number'></result>"
    @results += "  <result name='ManagersName'></result>"
    @results += "  <result name='ManagerLoginID'></result>"
    @results += "  <result name='Cost Center Code'></result>"
        @results += "<result name='Handler Error Message'>#{error.http_code}: #{escape(error_message)} </result>"
        @results += "</results>"
       
		puts(@results) if @debug_logging_enabled	
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