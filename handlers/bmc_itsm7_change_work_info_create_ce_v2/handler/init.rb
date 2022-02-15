# Require the dependencies file to load the vendor libraries
require File.expand_path(File.join(File.dirname(__FILE__), 'dependencies'))

require 'rexml/document'
require 'ars_models'
require 'securerandom'

class BmcItsm7ChangeWorkInfoCreateCeV1
  # Prepare for execution by pre-loading Ars form definitions, building Hash
  # objects for necessary values, and validating the present state.  This method
  # sets the following instance variables:
  # * @input_document - A REXML::Document object that represents the input Xml.
  # * @debug_logging_enabled - A Boolean value indicating whether logging should
  #   be enabled or disabled.
  # * @parameters - A Hash of parameter names to parameter values.
  # * @field_values - A Hash of CHG:WorkLog database field names to the values to
  #   be used for the record.
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
    
    # Store the info values in a Hash of info names to values.
    @info_values = {}
    REXML::XPath.each(@input_document,"/handler/infos/info") { |item|
      @info_values[item.attributes['name']] = item.text.to_s.strip
    }

    # Determine if debug logging is enabled.
    @debug_logging_enabled = @info_values['enable_debug_logging'] == 'Yes'
    puts("Logging enabled.") if @debug_logging_enabled

    # Determine if caching is disabled.
    @disable_caching = @info_values['disable_caching'] == 'Yes'
    puts("Disable Caching: #{@disable_caching}.") if @debug_logging_enabled
    
    begin
      # Obtain a unchangable reference to the configuration (the @@config class
      # variable could be concurrently changed by other threads -- by defining the
      # @config instance variable, the execution of this handler is "locked in" to
      # using that config for the entire execution)
      preinitialize_on_first_load_remote(
        @input_document,
        ['CHG:WorkLog', 'CHG:Infrastructure Change']
      )
    rescue Exception => error
      @error = error
    end
	 
    # Store parameters in the node.xml in a hash attribute named @parameters.
    @parameters = {}
    REXML::XPath.match(@input_document, '/handler/parameters/parameter').each do |node|
      @parameters[node.attribute('name').value] = node.text.to_s.strip
    end
	
    @raise_error = @parameters["error_handling"] == "Raise Error"

    # Retrieve the list of field values
    @field_values = {}
    REXML::XPath.match(@input_document, '/handler/fields/field').each do |node|
      @field_values[node.attribute('name').value] = node.text.to_s.strip
    end

    # Validate the required field values that are set from node parameters
    # contain a value and raise an exception if one or more are missing.
    validate_presence_of_required_values!(@field_values, REQUIRED_FIELDS)
  end

  # Creates a record on the CHG:WorkLog with the @field_values hash.  If the
  # include_review_request parameter is configured to "Yes", it prepends the review
  # request URL to the 'Detailed Description'.  If the include_question_answers
  # parameter is configured to "Yes", it appends the question answer pairs formatted
  # string to the 'Detailed Description'.  Then for each attachment_question_menu_label
  # parameter with a value, it retrieves the associated attachment and adds it to
  # the @field_values hash.
  #
  # This is a required method that is automatically called by the Kinetic Task
  # Engine.
  #
  # ==== Returns
  # An Xml formatted String representing the return variable results.
  def execute
    space_slug = @parameters["space_slug"].empty? ? @info_values["space_slug"] : @parameters["space_slug"]
    if @info_values['api_server'].include?("${space}")
      @server = @info_values['api_server'].gsub("${space}", space_slug)
    elsif !space_slug.to_s.empty?
      @server = @info_values['api_server']+"/"+space_slug
    else
      @server = @info_values['api_server']
    end

    error_message = ""

    #Source Variables
    @api_username   = @info_values["api_username"]
    @api_password   = @info_values["api_password"]
    @submission_id  = @parameters["submission_id"]
    @submisson_values
    @field_names = Array.new
    @field_names.push(@parameters['attachment_field_1']) if !@parameters['attachment_field_1'].empty?
    @field_names.push(@parameters['attachment_field_2']) if !@parameters['attachment_field_2'].empty?
    @field_names.push(@parameters['attachment_field_3']) if !@parameters['attachment_field_3'].empty?
    @source_field_values = Array.new
    begin
      @source_field_values.push(JSON.parse(@parameters['attachment_json_1'])) if !@parameters['attachment_json_1'].empty?
      @source_field_values.push(JSON.parse(@parameters['attachment_json_2'])) if !@parameters['attachment_json_2'].empty?
      @source_field_values.push(JSON.parse(@parameters['attachment_json_3'])) if !@parameters['attachment_json_3'].empty?
    rescue Exception => error
      error_message = error
      raise error if @raise_error
    end
    
    # Headers for server: Authorization, Accept, Content-Type
    @headers = http_basic_headers(@api_username, @api_password)

    if @parameters['attachment_input_type'] == "Field"
      # Make sure the field values array is empty
      @source_field_values.clear
      # retrive submission to get field names
      get_submission_values()
      
      # Add field values to array if they are defined
      @field_names.each do |field_name|
        @source_field_values.push(@submisson_values[field_name][0])
      end
    end

    if (@error.to_s.empty? && error_message.nil?)
      if !@source_field_values.empty?
        begin
          get_field_values()
        ensure
          # Remove the temp directory along with the downloaded attachment
          FileUtils.rm_rf(@tempdir) if !@tempdir.nil?
        end
      else
        error_message = "No field values were found on submission '#{@submission_id}' or provided as inputs."
        raise error_message if @raise_error
      end
      
      # If parameter include_review_request is set to "Yes", prepend the review request
      # URL string to the 'Detailed Description' field.
      if @parameters['include_review_request'] == "Yes"
        @field_values['Detailed Description'].insert(0, "#{@server}/submissions/#{@submission_id}?review\n\n")
      end

      # If parameter include_question_answers is set to "Yes", prepend the question
      # answers formatted string to the 'Detailed Description' field.
      if @parameters['include_question_answers'] == "Yes"
        if @submisson_values.nil?
          get_submission_values()
        end
        
        results = "\n\nQuestion Answer Pairs:\n"
        @submisson_values.each {|question,answer|
          if answer.nil?
            results += "    " + question + ":  \n"
          elsif answer.kind_of?(Array)
            results += "    " + question + ":  " + escape(answer.join(" , ")) + "\n"
          else
            results += "    " + question + ":  " + escape(answer) + "\n"
          end
        }

        @field_values['Detailed Description'] << results
      end
        
      begin
        # Retrieve the CHG:Infrastructure Change entry that will be associated with
        # the CHG:WorkLog entry.  This entry is retrieved using the change_number
        # parameter and the request id of the entry is used.
        change_entry = get_remedy_form('CHG:Infrastructure Change').find_entries(
          :single,
          :conditions => [%|'Infrastructure Change ID' = "#{@parameters['change_number']}"|],
          :fields => []
        )
        if change_entry.nil?
          raise(%|Could not find entry on CHG:Infrastructure Change with 'Infrastructure Change ID'="#{@parameters['change_number']}"|)
        end
        @field_values['Infra. Change Entry ID'] = change_entry.id

        # Create the CHG:WorkLog record using the @field_values hash that was built
        # up.  Pass empty array to the fields argument because no fields are necessary
        # to build the results XML.
        entry = get_remedy_form('CHG:WorkLog').create_entry!(
          :field_values => @field_values,
          :fields       => []
        )
      rescue Exception => error
        error_message = error.inspect
        raise error if @raise_error
      end
    else
      error_message = @error if !@error.nil?
      raise @error if @raise_error
    end
    
    results = handle_results(entry ? entry.id : "", error_message)
    puts "Returning results: #{results}" if @debug_logging_enabled
    results
  end

  ##############################################################################
  # Validation Helpers
  ##############################################################################

  # Defines a hash of Remedy field names (for the 'CHG:ChangeInterface_Create'
  # form) to Kinetic Task node parameter names that are required to complete
  # this action.  This constant is used to validate that all required fields
  # were included as parameters and have a non-blank value.
  REQUIRED_FIELDS = {
    'Description' => 'Change Number',
    'Infra. Change Entry ID' => 'Work Info Summary'
  }

  # Iterates over the required hash (a mapping of required hash keys to the
  # display value to use for that hash key) and raises an exception if any of
  # the required keys map to a nil? or empty? value.
  #
  # ==== Parameters
  # * value_hash (Hash) - The hash of key to value pairs that should be checked
  #   for required values.
  # * required_hash (Hash) - A hash of keys that should be associated with a
  #   required value in the value_hash to the display value to use in the error
  #   message if the value associated with the key is nil? or empty?
  def validate_presence_of_required_values!(value_hash, required_hash)
    # Validate that all of the parameters have values
    missing_parameters = []
    # Validate that all of the required parameters have values
    required_hash.each do |field_name, parameter_name|
      if value_hash[field_name].nil? || value_hash[field_name].empty?
        missing_parameters << parameter_name
      end
    end

    # If there were any blank field values
    if missing_parameters.length > 0
      # Raise an exception
      raise "The following node parameters are required: #{missing_parameters.sort.join(', ')}"
    end
  end

  ##############################################################################
  # BMC_ITSM7_ChangeWorkInfo_Create handler utility functions
  ##############################################################################
  def get_submission_values()
    # Submission API Route
    source_submission_route = "#{@server}/app/api/v1/submissions/#{@submission_id}/?include=values"
    # Retrieve the submission and values
    res = http_get(source_submission_route, { "include" => "values" }, @headers)
    if !res.kind_of?(Net::HTTPSuccess)
      message = "Failed to retrieve source submission #{@submission_id}"
      return handle_net_http_exception(message, res)
    end
    submission = JSON.parse(res.body)["submission"]
    puts "Received source submission #{submission['id']}" if @debug_logging_enabled

    @submisson_values = submission["values"]
  end 

  def get_field_values() 
    # Process each attachment file
    @source_field_values.each_with_index do |attachment_info, index|
      tempfile = download_file_to_temp(attachment_info, index)

      # ArsModels does not support streaming file upload
      file = File.open(tempfile).read
      attachment_field = ArsModels::FieldValues::AttachmentFieldValue.new()
      attachment_field.name = attachment_info['name']
      attachment_field.base64_content = Base64.encode64(file)
      attachment_field.size = file.size

      @field_values["z2AF Work Log0#{index + 1}"] = attachment_field
    end
  end

  def download_file_to_temp(attachment_info, index)
      # The attachment file name is stored in the 'name' property
      attachment_name = attachment_info['name']

      # Temporary file to stream contents to
      @tempdir = "#{Dir.tmpdir}/#{SecureRandom.hex(8)}"
      tempfile = "#{@tempdir}/#{attachment_name}"
      FileUtils.mkdir_p(@tempdir)


      # Retrieve the attachment download link from the server
      puts "Retrieving attachment download link from source submission: #{attachment_name} for field #{@field_names[index]}" if @debug_logging_enabled

      # API route to get the generated attachment download link from Kinetic Request CE.
      download_link_api_route = "#{@server}/app/api/v1/#{attachment_info["link"].split("/", 3)[2]}/url"

      # Retrieve the URL to download the attachment from Kinetic Request CE.
      res = http_get(download_link_api_route, {}, @headers)
      if !res.kind_of?(Net::HTTPSuccess)
        message = "Failed to retrieve link for attachment #{attachment_name} from source submission"
        return handle_net_http_exception(message, res)
      end
      file_download_url = JSON.parse(res.body)['url']
      puts "Received link for attachment #{attachment_name} from source submission"  if @debug_logging_enabled


      # Inspect the attachment URL to determine if using FileHub or Agent
      attachment_uri = URI(file_download_url)
      query_params = CGI::parse(attachment_uri.query || "")
      # If url contains a signature query parameter, using FileHub (no authorization header)
      filestore_headers = query_params.has_key?("signature") && !query_params["signature"].empty? ? {} : @headers

      # Download the attachment from the source submission
      puts "Downloading attachment #{attachment_name} from #{file_download_url}" if @debug_logging_enabled
      res = stream_file_download(tempfile, file_download_url, {}, filestore_headers)
      if !res.kind_of?(Net::HTTPSuccess)
        message = "Failed to download attachment #{attachment_name} from the filestore server"
        return handle_net_http_exception(message, res)
      end

      return tempfile
  end

  ##############################################################################
  # General handler utility functions
  ##############################################################################

  # This method is an accessor for the @config[:forms] variable that caches
  # form definitions.  It checks to see if the specified form has been loaded
  # if so it returns it otherwise it needs to load the form and add it to the
  # cache.
  def get_remedy_form(form_name)
    if @config[:forms][form_name].nil?
      @config[:forms][form_name] = ArsModels::Form.find(form_name, :context => @config[:context])
    end
    if @config[:forms][form_name].nil?
      raise "Could not find form " + form_name
    end
    @config[:forms][form_name]
  end

  def preinitialize_on_first_load_remote(input_document, form_names)
    puts "Preinitializing ARS Models" if @debug_logging_enabled

    remedy_context = ArsModels::Context.new(
      :server         => @info_values['ars_server'],
      :username       => @info_values['ars_username'],
      :password       => @info_values['ars_password'],
      :port           => @info_values['ars_port'],
      :prognum        => @info_values['ars_prognum'],
      :authentication => @info_values['ars_authentication']
    )

    # Build up a new configuration
    if @disable_caching
      @config = {
        #:properties => properties,
        :context => remedy_context,
        :forms => form_names.inject({}) do |hash, form_name|
          hash.merge!(form_name => ArsModels::Form.find(form_name, :context => remedy_context))
        end
      }
    else
      @@config = {
        #:properties => properties,
        :context => remedy_context,
        :forms => form_names.inject({}) do |hash, form_name|
          hash.merge!(form_name => ArsModels::Form.find(form_name, :context => remedy_context))
        end
      }
    end

    puts "Models Initialized" if @debug_logging_enabled
  end
  
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

  def handle_results(entryId, error_msg)
    <<-RESULTS
    <results>
      <result name="Entry Id">#{ERB::Util.html_escape(entryId)}</result>
      <result name="Handler Error Message">#{ERB::Util.html_escape(error_msg)}</result>
    </results>
    RESULTS
  end
  
  def handle_net_http_exception(message, error)
    case error
    when Net::HTTPResponse
      begin
        content = JSON.parse(error.body)
        error_key = content["errorKey"] || error.code
        error_msg = content["error"] || ""
        error_message = "#{message}:\n\tError Key: #{error_key}\n\tError: #{error_msg}"
      rescue StandardError => e
        error_key = error.code
        error_message = "#{message}:\n\tError Code: #{error_key}\n\tError: #{error.body}"
      end
    when NilClass
      error_message = "0: No response from server"
    else
      error_message = "Unexpected error: #{error.inspect}"
    end
    raise error_message if @raise_error
    handle_results(nil, error_message, nil)
  end



  #-----------------------------------------------------------------------------
  # The following Http helper methods are provided within this handler because
  # task currently doesn't have a common http client module that handlers can
  # use. If these methods were packaged as a module within the dependencies.rb
  # file or within a gem/library, they would be under the same constraints as
  # other vendor gems, such as RestClient, where any handler that uses
  # RestClient is currently stuck using v1.6.7. Adding these methods
  # directly to the handler class gives the freedom to add/modify as needed
  # without affecting other handlers.
  #-----------------------------------------------------------------------------


  #-----------------------------------------------------------------------------
  # HTTP HEADERS
  #-----------------------------------------------------------------------------

  def http_json_headers
    {
      "Accept" => "application/json",
      "Content-Type" => "application/json"
    }
  end
  
  
  def http_basic_headers(username, password)
    http_json_headers.merge({
      "Authorization" => "Basic #{Base64.strict_encode64("#{username}:#{password}")}"
    })
  end


  #-----------------------------------------------------------------------------
  # REST ACTIONS
  #-----------------------------------------------------------------------------
  
  def http_get(url, parameters, headers, http_options={})
    uri = URI.parse(url)
    uri.query = URI.encode_www_form(parameters) unless parameters.empty?
    request = Net::HTTP::Get.new(uri, headers)
    send_request(request, http_options)
  end

  #-----------------------------------------------------------------------------
  # ATTACHMENT METHODS
  #-----------------------------------------------------------------------------

  def stream_file_download(file, url, parameters, headers, http_options={})
    uri = URI.parse(url)
    uri.query = URI.encode_www_form(parameters) unless parameters.empty?

    http = build_http(uri, http_options)
    request = Net::HTTP::Get.new(uri, headers)

    http.request(request) do |response|
      open(file, 'w') do |io|
        response.read_body do |chunk|
          io.write chunk
        end
      end
    end
  end

  #-----------------------------------------------------------------------------
  # LOWER LEVEL METHODS
  #-----------------------------------------------------------------------------

  def send_request(request, http_options={})
    uri = request.uri
    Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') do |http|
      configure_http(http, http_options)
      http.request(request)
    end
  end
  
  
  def build_http(uri, http_options={})
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl= true if (uri.scheme == 'https')
    configure_http(http, http_options)
    http
  end


  def configure_http(http, http_options={})
    http_options_sym = (http_options || {}).inject({}) { |h, (k,v)| h[k.to_sym] = v; h }
    http.verify_mode = http_options_sym[:ssl_verify] || OpenSSL::SSL::VERIFY_PEER if http.use_ssl?
    http.read_timeout= http_options_sym[:read_timeout] unless http_options_sym[:read_timeout].nil?
    http.open_timeout= http_options_sym[:open_timeout] unless http_options_sym[:open_timeout].nil?
  end
end