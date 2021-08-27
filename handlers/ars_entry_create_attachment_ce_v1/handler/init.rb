# Require the dependencies file to load the vendor libraries
require File.expand_path(File.join(File.dirname(__FILE__), "dependencies"))

class ArsEntryCreateAttachmentCeV1

  CORE_API_ROUTE = '/app/api/v1'

  # Prepare for execution by building Hash objects for necessary values,
  # and validating the present state.  This method sets the following instance variables:
  # * @input_document - A REXML::Document object that represents the input Xml.
  # * @debug_logging_enabled - A Boolean value indicating whether logging should
  #   be enabled or disabled.
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
	
    # Determine if debug logging is enabled. Value is set in the info.xml.
    @debug_logging_enabled = @info_values['enable_debug_logging'] == 'Yes'
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
    @error_message = ""
    @error_handling  = @parameters["error_handling"]

    # CORE configuration
    core_server =  @info_values['api_server'].chomp!("/")

   # ARS configuration
	  ars_username     = URI.encode(@info_values["ars_username"])
    ars_password     = @info_values["ars_password"]
    ars_server       = @info_values["ars_server"]
    ars_form         = URI.encode(@parameters['form'])
    ars_field_values = JSON.parse(@parameters['field_values'])

    # Handler Result Variables
	  ars_result = ""
    ars_record_location = ""
	  ars_request_id = ""

    # Download attachments from Kinetic Core and save as temp files
    file_attachment_1 = @parameters["attachment_field_1"].nil? ? nil :
      download_core_attachment(core_server, @parameters['submission_id'], @parameters["attachment_field_1"])
    file_attachment_2 = @parameters["attachment_field_2"].nil? ? nil :
      download_core_attachment(core_server, @parameters['submission_id'], @parameters["attachment_field_2"])
    file_attachment_3 = @parameters["attachment_field_3"].nil? ? nil :
      download_core_attachment(core_server, @parameters['submission_id'], @parameters["attachment_field_3"])


    begin
      puts(format_hash("Field Values:", ars_field_values)) if @debug_logging_enabled
    
      # Remove any empty or nil values
      ars_field_values.reject!{ |key,value| (value.nil? or value.empty?) }

      # Walk the field values hash to check for a Null keyword - nil,
      # indicating the null value should be sent
      ars_field_values.each_key { |key| ars_field_values[key] = nil if ars_field_values[key] == "nil" }

      # Create the request body that will consist of multiple parts for the 
      # form field values, and the attachments
      ars_request_body = {}

      # Add Ars attachment field names to file names
      ars_field_values[@parameters["ars_attachment_field_1"]] = 
          File.basename(file_attachment_1) if file_attachment_1
      ars_field_values[@parameters["ars_attachment_field_2"]] = 
          File.basename(file_attachment_1) if file_attachment_2
      ars_field_values[@parameters["ars_attachment_field_3"]] = 
          File.basename(file_attachment_1) if file_attachment_3

      # entry field values
      entry_file = File.join(Dir::tmpdir, "entry.json")
      File.open(entry_file, "w") { |f| f.write( { 
        "values" => ars_field_values, 
      }.to_json) }
      ars_request_body["entry"] = File.new(entry_file, 'r')

      # attachments
      ars_request_body["attach-#{@parameters["ars_attachment_field_1"]}"] = 
          File.new(file_attachment_1, 'rb') if file_attachment_1
      ars_request_body["attach-#{@parameters["ars_attachment_field_2"]}"] = 
          File.new(file_attachment_2, 'rb') if file_attachment_2
      ars_request_body["attach-#{@parameters["ars_attachment_field_3"]}"] = 
          File.new(file_attachment_3, 'rb') if file_attachment_3

      # Generate the URL to create the ARS entry
      ars_request_url = "#{ars_server}/arsys/v1/entry/#{ars_form}"
      puts("ARS Create URL: #{ars_request_url}") if @debug_logging_enabled

      # ars headers
      ars_request_headers = {
        :authorization => "AR-JWT #{ars_access_token(ars_server, ars_username, ars_password)}",
        :content_type => "multipart/form-data"
      }

      # Uncomment to add additional logging.  !!Warning token value will be save to log
      # RestClient.log = 'stdout' if @debug_logging_enabled

      # Build the HTTP request to create the ARS entry
      ars_request = RestClient::Request.new({
        method: :post,
        url: ars_request_url,
        payload: ars_request_body,
        headers: ars_request_headers
      })
      
      # execute request
      ars_response = ars_request.execute 

      ars_result = "Successful"
      puts(format_hash("ARS Response Headers: ", ars_response.headers)) if @debug_logging_enabled

      # Retrieve the ARS record URL from the location header
      ars_record_location = ars_response.headers[:location]
      puts("ARS Record Location: #{ars_record_location}") if @debug_logging_enabled

      # parse the record ID off the location
      ars_request_id = ars_record_location.split('/').last
    
    rescue RestClient::Exception => e
      @error_message = "Error creating ARS entry:" + 
      "\n\tResponse Code: #{e.response.code}\n\tResponse: #{e.response.body}"
      
      # Raise the error if instructed to, otherwise will fall through to
      # return an error message.
      raise if @error_handling == "Raise Error"
    rescue RestClient::RequestTimeout => e
      @error_message = "Timeout creating ARS entry: #{e}" 
      
      # Raise the error if instructed to, otherwise will fall through to
      # return an error message.
      raise if @error_handling == "Raise Error"
    rescue Exception => e
      @error_message = "Error creating ARS entry:\n\tException: #{e.inspect}"
      # Raise the error if instructed to, otherwise will fall through to
      # return an error message.
      raise if @error_handling == "Raise Error"
    ensure
      # Delete the entry values file
      delete_file(entry_file) if entry_file
      # Delete the attachment files that were downloaded with this handler
      delete_file(file_attachment_1) if file_attachment_1
      delete_file(file_attachment_2) if file_attachment_2
      delete_file(file_attachment_3) if file_attachment_3
    end

    # Return the results
    results = <<-RESULTS
    <results>
	  <result name="Handler Error Message">#{escape(@error_message)}</result>
      <result name="Result">#{escape(ars_result)}</result>
      <result name="Record Location">#{escape(ars_record_location)}</result>
	  <result name="Record ID">#{escape(ars_request_id)}</result>
    </results>
    RESULTS
    
    return results
  end


  ##############################################################################
  # Handler specific utility functions
  ##############################################################################

  def delete_file(filepath)
    begin
      File.delete(filepath) if filepath
      puts %|Deleted the downloaded file "#{filepath}"| if @debug_logging_enabled
    rescue Exception => e
      puts %|Failed to delete file "#{filepath}": #{e.inspect}|
    end
  end


  ##############################################################################
  # Kinetic Core utility functions
  ##############################################################################

  # downloads an attachment from core and saves the file
  # returns the file path
  def download_core_attachment(server, submission_id, field_name)
    filepath = nil

    # Call the Kinetic Request CE API
    begin
      # Submission API Route including Values
      # /{spaceSlug}/app/api/v1/submissions/{submissionId}}?include=...
      submission_api_route = "#{server}#{CORE_API_ROUTE}/submissions/#{URI.escape(submission_id)}/?include=values"
      puts("Core submission API Route: \n#{submission_api_route}") if @debug_logging_enabled
      
      # Retrieve the Submission Values
      submission_response = RestClient::Resource.new(
        submission_api_route,
        user: @info_values['api_username'],
        password: @info_values['api_password']
      ).get

      # If the submission exists
      unless submission_response.nil?
        puts("Core submission successfully retrieved") if @debug_logging_enabled
        submission = JSON.parse(submission_response)['submission']
        field_value = submission['values'][field_name]
        # If the attachment field value exists
        unless field_value.nil?
          # Attachment field values are stored as arrays we assume only one attachment per field
          file_info = field_value[0]
          attachment_name = file_info["name"]
          puts("Core attachment found: #{attachment_name}") if @debug_logging_enabled
          attachment_download_api_route = server +
            CORE_API_ROUTE +
            '/submissions/' + URI.escape(submission_id) +
            '/files/' + URI.escape(field_name) +
            '/' + '0' +
            '/' + URI.escape(attachment_name) +
            '/url'

          puts("Core attachment download URL: \n#{attachment_download_api_route}") if @debug_logging_enabled
          
          # Download file
          attachment_download_result = RestClient::Resource.new(
            attachment_download_api_route,
            user: @info_values['api_username'],
            password: @info_values['api_password']
          ).get()

          unless attachment_download_result.nil?
            # get the filehub url to download the file
            file_url = JSON.parse(attachment_download_result)['url']
            puts "Core downloading attachment: #{file_info['name']} from #{file_url}" if @debug_logging_enabled
            attachment_content = RestClient::Resource.new(
                  file_url,
                  user: @info_values['api_username'],
                  password: @info_values['api_password']
                ).get()

            # escape the attachment name - may need to add more characters?
            escaped_attachment_name = attachment_name.gsub(/[&"'%!@ ]/, "")
            # create a file in the temp directory with the downloaded content
            filepath = File.join(Dir::tmpdir, escaped_attachment_name)
            File.open(filepath, "w") { |f| f.write(attachment_content) }
          end
        end
      end
    # If the credentials are invalid
    rescue RestClient::Unauthorized
      raise StandardError, "(Unauthorized): You are not authorized"
    rescue RestClient::ResourceNotFound => error
      raise StandardError, error.response
    end
  
    if @debug_logging_enabled
      if filepath
        puts "Core attachment #{attachment_name} retrieved"
        puts "Saved to: #{filepath}"
      else
        puts "No Core attachment returned"
      end
    end

    return filepath
  end

  
  ##############################################################################
  # ARS utility functions
  ##############################################################################

  def ars_access_token(api_server, username, password)
    params = {
      'username' => username,
      'password' => password
    }
    puts('Getting ARS access token') if @debug_logging_enabled
    begin
      #this method will not raise an error if the call does not work.
      response = RestClient::Request.new({
        method: :post,
        url: "#{api_server}/jwt/login",
        payload: params,
        headers: { :content_type => :'application/x-www-form-urlencoded' }
      }).execute 
        
      return response.body
    rescue RestClient::Exception => e
      @error_message = "Error fetching token" + 
      "\n\tResponse Code: #{e.response.code}\n\tResponse: #{e.response.body}"
      
      # Raise the error if instructed to, otherwise will fall through to
      # return an error message.
      raise if @error_handling == "Raise Error"
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
end
 