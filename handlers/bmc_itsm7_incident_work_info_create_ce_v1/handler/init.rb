# Require the dependencies file to load the vendor libraries
require File.expand_path(File.join(File.dirname(__FILE__), 'dependencies'))

require 'rexml/document'
require 'ars_models'

class BmcItsm7IncidentWorkInfoCreateCeV1
  # Prepare for execution by pre-loading Ars form definitions, building Hash
  # objects for necessary values, and validating the present state.  This method
  # sets the following instance variables:
  # * @input_document - A REXML::Document object that represents the input Xml.
  # * @debug_logging_enabled - A Boolean value indicating whether logging should
  #   be enabled or disabled.
  # * @parameters - A Hash of parameter names to parameter values.
  # * @field_values - A Hash of HPD:WorkLog database field names to the values to
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

    # Determine if debug logging is enabled.
    @debug_logging_enabled = get_info_value(@input_document, 'enable_debug_logging') == 'Yes'
    puts("Logging enabled.") if @debug_logging_enabled

    # Determine if caching is disabled.
    @disable_caching = get_info_value(@input_document, 'disable_caching') == 'Yes'
    puts("Disable Caching: #{@disable_caching}.") if @debug_logging_enabled

    begin
      # Obtain a unchangable reference to the configuration (the @@config class
      # variable could be concurrently changed by other threads -- by defining the
      # @config instance variable, the execution of this handler is "locked in" to
      # using that config for the entire execution)
      @config = preinitialize_on_first_load_remote(
        @input_document,
        ['HPD:WorkLog', 'HPD:Help Desk']
      )
    rescue Exception => error
      @error = error
    end

    # Store the info values in a Hash of info names to values.
    @info_values = {}
    REXML::XPath.each(@input_document,"/handler/infos/info") do |item|
      @info_values[item.attributes['name']] = item.text
    end
    

    # Store parameters in the node.xml in a hash attribute named @parameters.
    @parameters = {}
    REXML::XPath.match(@input_document, '/handler/parameters/parameter').each do |node|
      @parameters[node.attribute('name').value] = node.text.to_s.strip
    end
    puts(format_hash("Handler Parameters:", @parameters)) if @debug_logging_enabled

    # Retrieve the list of field values
    @field_values = {}
    REXML::XPath.match(@input_document, '/handler/fields/field').each do |node|
      @field_values[node.attribute('name').value] = node.text
    end
    puts(format_hash("Field Values:", @field_values)) if @debug_logging_enabled

    # Validate the required field values that are set from node parameters
    # contain a value and raise an exception if one or more are missing.
    validate_presence_of_required_values!(@field_values, REQUIRED_FIELDS)
  end

  # Creates a record on the HPD:WorkLog with the @field_values hash.  If the
  # include_review_request parameter is configured to Yes, it prepends the review
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
    error_handling = @parameters["error_handling"]
    error_message = nil
    entry_id = nil

    space_slug = @parameters["space_slug"].empty? ? @info_values["space_slug"] : @parameters["space_slug"]
    if @info_values['api_server'].include?("${space}")
      server = @info_values['api_server'].gsub("${space}", space_slug)
    elsif !space_slug.to_s.empty?
      server = @info_values['api_server']+"/"+space_slug
    else
      server = @info_values['api_server']
    end
    server = "#{server}/" if !server.end_with?("/")


    if (@error.to_s.empty?)
      begin
        # For attachment_question_menu_label 1, 2, and 3: if there is a value, retrieve
        # the attachment with the get_attachment() method and store the attachment in
        # @field_values.
        if @parameters['attachment_input_type'] == "Field"
          @field_values['z2AF Work Log01'] = create_attachment_from_field(@parameters['attachment_field_1'], server) if !@parameters['attachment_field_1'].empty?
          @field_values['z2AF Work Log02'] = create_attachment_from_field(@parameters['attachment_field_2'], server) if !@parameters['attachment_field_2'].empty?
          @field_values['z2AF Work Log03'] = create_attachment_from_field(@parameters['attachment_field_3'], server) if !@parameters['attachment_field_3'].empty?
        else
          @field_values['z2AF Work Log01'] = create_attachment_from_json(@parameters['attachment_json_1']) if !@parameters['attachment_json_1'].empty?
          @field_values['z2AF Work Log02'] = create_attachment_from_json(@parameters['attachment_json_2']) if !@parameters['attachment_json_2'].empty?
          @field_values['z2AF Work Log03'] = create_attachment_from_json(@parameters['attachment_json_3']) if !@parameters['attachment_json_3'].empty?
        end

        # If parameter include_review_request is set to "Yes", prepend the review request
        # URL string to the 'Detailed Description' field, using the review_request_string()
        # method to build the URL.
        if @parameters['include_review_request'] == "Yes"
          @field_values['Detailed Description'].insert(0, review_request_string(
              @parameters['submission_id'], server))
        end

        # If parameter include_question_answers is set to "Yes", prepend the question
        # answers formatted string to the 'Detailed Description' field, using the
        # question_answers_string() method to build the question answer pairs string.
        if @parameters['include_question_answers'] == "Yes"
          @field_values['Detailed Description'] << question_answers_string(
            @parameters['submission_id'], server)
        end


        # Retrieve the HPD:Help desk entry that will be associated with the HPD:WorkLog
        # entry.  This entry is retrieved using the incident_number parameter and the
        # request id of the entry is used.
        #incident_entry = @@remedy_forms_remote['HPD:Help Desk'].find_entries(
        incident_entry = get_remedy_form('HPD:Help Desk').find_entries(
          :single,
          :conditions => [%|'Incident Number' = "#{@parameters['incident_number']}"|],
          :fields     => []
        )
        if incident_entry.nil?
          raise(%|Could not find entry on HPD:Help Desk with 'Incident Number'="#{@parameters['incident_number']}"|)
        end
        @field_values['Incident Entry ID'] = incident_entry.id

        # Log the final values that will be used to create the CHG:WorkLog record.
        puts(format_hash("Field Values:", @field_values)) if @debug_logging_enabled

        # Create the HPD:WorkLog record using the @field_values hash that was built
        # up.  Pass empty array to the fields argument because no fields are necessary
        # to build the results XML.
        @field_values.delete_if {|key, value| value.nil? }
        #entry = @@remedy_forms_remote['HPD:WorkLog'].create_entry!(
        entry = get_remedy_form('HPD:WorkLog').create_entry!(
          :field_values => @field_values,
          :fields       => []
        )
        entry_id = entry.id
      rescue Exception => error
        error_message = error.inspect
        raise error if error_handling == "Raise Error"
      end
    else
      error_message = @error
      raise @error if error_handling == "Raise Error"
    end

    # Build the results xml that will be returned by this handler.
    results = <<-RESULTS
    <results>
      <result name="Handler Error Message">#{escape(error_message)}</result>
      <result name="Entry Id">#{escape(entry_id)}</result>
    </results>
    RESULTS
    puts("Results: \n#{results}") if @debug_logging_enabled

    # Return the results String
    return results
  end

  ##############################################################################
  # Validation Helpers
  ##############################################################################

  # Defines a hash of Remedy field names (for the 'CHG:ChangeInterface_Create'
  # form) to Kinetic Task node parameter names that are required to complete
  # this action.  This constant is used to validate that all required fields
  # were included as parameters and have a non-blank value.
  REQUIRED_FIELDS = {
    'Incident Number' => 'Incident Number',
    'Description' => 'Work Info Summary'
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
  # BMC_ITSM7_IncidentWorkInfo_Create handler utility functions
  ##############################################################################
  def create_attachment_from_json(json)
    field_values = JSON.parse(json)
    puts("Using File URL: \n#{field_values[0]["url"]}") if @debug_logging_enabled
    puts("Using File Name: \n#{field_values[0]["name"]}") if @debug_logging_enabled
    attachment = RestClient::Resource.new(field_values[0]["url"],
                                    user: @info_values['api_username'],
                                    password: @info_values['api_password']).get

    attachment_field = ArsModels::FieldValues::AttachmentFieldValue.new()
    attachment_field.name = field_values[0]["name"]
    attachment_field.base64_content = Base64.encode64(attachment.body)
    attachment_field.size = attachment.body.size()

    return attachment_field
  end

  def create_attachment_from_field(field_name, server)
    # Call the Kinetic Request CE API
    begin
      # Submission API Route including Values
      # /{spaceSlug}/app/api/v1/submissions/{submissionId}}?include=...

      submission_api_route = server + 'app/api/v1' +
        '/submissions/' + URI.escape(@parameters['submission_id']) + '/?include=values'
      puts("Submission API Route: \n#{submission_api_route}") if @debug_logging_enabled
      # Retrieve the Submission Values
      submission_result = RestClient::Resource.new(
        submission_api_route,
        user: get_info_value(@input_document, 'api_username'),
        password: get_info_value(@input_document, 'api_password')
      ).get

      # If the submission exists
      unless submission_result.nil?

       submission = JSON.parse(submission_result)['submission']
        field_value = submission['values'][field_name]
        # If the attachment field value exists
        unless field_value.nil?
          files = []
          # At:tachment field values are stored as arrays, one map for each file attachment
          field_value.each_index do |index|
            file_info = field_value[index]
            # The attachment file name is stored in the 'name' property
            # API route to get the generated attachment download link from Kinetic Request CE.
            attachment_download_api_route = server + 'app/api/v1' +
              '/submissions/' + URI.escape(@parameters['submission_id']) +
              '/files/' + URI.escape(field_name) +
              '/' + index.to_s +
              '/' + URI.escape(file_info['name']) +
              '/url'
            puts("Attachment Download API Route: \n#{attachment_download_api_route}") if @debug_logging_enabled

            # Retrieve the URL to download the attachment from Kinetic Request CE.
            # This URL will only be valid for a short amount of time before it expires
            # (usually about 5 seconds).
            attachment_download_result = RestClient::Resource.new(
              attachment_download_api_route,
              user: get_info_value(@input_document, 'api_username'),
              password: get_info_value(@input_document, 'api_password')
            ).get

            unless attachment_download_result.nil?
              url = JSON.parse(attachment_download_result)['url']
              file_info["url"] = url
            end
            file_info.delete("link")
            files << file_info
          end
        end
      end

    # If the credentials are invalid
    rescue RestClient::Unauthorized
      raise StandardError, "(Unauthorized): You are not authorized."
    rescue RestClient::ResourceNotFound => error
      raise StandardError, error.response
    end

  if files.nil?
      puts("No File in Field: \n#{field_name}") if @debug_logging_enabled
          return nil
    else
      puts("Using File URL: \n#{files[0]["url"]}") if @debug_logging_enabled
      puts("Using File Name: \n#{files[0]["name"]}") if @debug_logging_enabled
      attachment = RestClient::Resource.new(
        files[0]["url"],
        user: get_info_value(@input_document, 'api_username'),
        password: get_info_value(@input_document, 'api_password')
      ).get

      attachment_field = ArsModels::FieldValues::AttachmentFieldValue.new()
      attachment_field.name = files[0]["name"]
      attachment_field.base64_content = Base64.encode64(attachment.body)
      attachment_field.size = attachment.body.size()

      return attachment_field
    end
  end

  # Returns a String URL for the review request page for the given submission.
  #
  # ==== Parameters
  # * submission_id (String) - The 'instanceId' of the ce request
  #   record related to this submission.
  # * server (String) - server URL
  #   the submission to create a review request for.
  #
  def review_request_string(submission_id, server)
    reviewLink = "#{server}submissions/#{submission_id}?review\n\n"
    puts("Using review link: #{reviewLink}") if @debug_logging_enabled
    return reviewLink

  end

  # Returns a String of question answer pairs.  The question answer data is retrieved
  # from KS_SRV_QuestionAnswerJoin using the customer_survey_instance_id parameter.
  #
  # ==== Parameters
  # * customer_survey_instance_id (String) - The 'instanceId' of the KS_SRV_CustomerSurvey_base
  #   record related to this submission.
  #
  def question_answers_string(submission_id, server)
     begin
      # API Route
      api_route = server +
                  'app/api/v1/submissions/' + submission_id +
                  '/?include=values'
      puts "API ROUTE: #{api_route}" if @debug_logging_enabled

      resource = RestClient::Resource.new(api_route,
                                          user: @info_values['api_username'],
                                          password: @info_values['api_password'])

      # Get to the API to retrieve the submission
      result = resource.get

      # Build values variable
      submission = JSON.parse(result)
      values = submission['submission']['values']


    # If the credentials are invalid
    rescue RestClient::Unauthorized
      raise StandardError, "(Unauthorized): You are not authorized."
    rescue RestClient::ResourceNotFound => error
      raise StandardError, error.response
    end

    # Build the results to be returned by this handler
    results = "\n\nQuestion Answer Pairs:\n"

    values.each {|question,answer|
      if answer.nil?
      results += "    " + question + ":  \n"
    elsif answer.kind_of?(Array)
      # Get name in the case of an Attachment Field
      name = JSON.parse(answer.to_json).empty? ? nil : JSON.parse(answer.to_json).first['name']
      if !name.nil? # Field contains an Attachment
        results += "    " + question + ":  " + escape(name) + "\n"
      else # Field is an Array such as a checkbox field
        results += "    " + question + ":  " + escape(answer.join(" , ")) + "\n"
      end
      else
       results += "    " + question + ":  " + escape(answer) + "\n"
      end
    }

  # Return the results String
    return results

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
    remedy_context = ArsModels::Context.new(
      :server         => get_info_value(input_document, 'ars_server'),
      :username       => get_info_value(input_document, 'ars_username'),
      :password       => get_info_value(input_document, 'ars_password'),
      :port           => get_info_value(input_document, 'ars_port'),
      :prognum        => get_info_value(input_document, 'ars_prognum'),
      :authentication => get_info_value(input_document, 'ars_authentication')
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
    # Starting with the "header" parameter string, concatenate each of the
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
