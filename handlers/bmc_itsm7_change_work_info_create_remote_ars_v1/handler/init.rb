require 'rexml/document'
require 'ars_models'

class BmcItsm7ChangeWorkInfoCreateRemoteArsV1
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
    
    # Initialize the handler and pre-load form definitions using the credentials
    # supplied by the task info items.
    preinitialize_on_first_load(
      @input_document,
      ['KS_SRV_SurveyQuestion', 'KS_SRV_QuestionAnswerJoin', 'KS_ACC_Attachment']
    )
	
	preinitialize_on_first_load_remote(
      @input_document,
      ['CHG:WorkLog', 'CHG:Infrastructure Change']
    )
    
    # Determine if debug logging is enabled.
    @debug_logging_enabled = get_info_value(@input_document, 'enable_debug_logging') == 'Yes'
    puts("Logging enabled.") if @debug_logging_enabled

    # Store parameters in the node.xml in a hash attribute named @parameters.
    @parameters = {}
    REXML::XPath.match(@input_document, '/handler/parameters/parameter').each do |node|
      @parameters[node.attribute('name').value] = node.text
    end
    puts(format_hash("Handler Parameters:", @parameters)) if @debug_logging_enabled

    # Retrieve the list of field values
    @field_values = {}
    REXML::XPath.match(@input_document, '/handler/fields/field').each do |node|
      @field_values[node.attribute('name').value] = node.text
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
    # If parameter include_review_request is set to "Yes", prepend the review request
    # URL string to the 'Detailed Description' field, using the review_request_string()
    # method to build the URL.
    if @parameters['include_review_request'] == "Yes"
      @field_values['Detailed Description'].insert(0, review_request_string(
          @parameters['customer_survey_instance_id'], @parameters['default_web_server']))
    end

    # If parameter include_question_answers is set to "Yes", prepend the question
    # answers formatted string to the 'Detailed Description' field, using the
    # question_answers_string() method to build the question answer pairs string.
    if @parameters['include_question_answers'] == "Yes"
      @field_values['Detailed Description'] << question_answers_string(
        @parameters['customer_survey_instance_id'])
    end
    
    # For attachment_question_menu_label 1, 2, and 3: if there is a value, retrieve
    # the attachment with the get_attachment() method and store the attachment in
    # @field_values.
    @field_values['z2AF Work Log01'] = get_attachment(@parameters['customer_survey_instance_id'],
      @parameters['attachment_question_menu_label_1'], @parameters['survey_template_instance_id']
    ) if @parameters['attachment_question_menu_label_1']
    @field_values['z2AF Work Log02'] = get_attachment(@parameters['customer_survey_instance_id'],
      @parameters['attachment_question_menu_label_2'], @parameters['survey_template_instance_id']
    ) if @parameters['attachment_question_menu_label_2']
    @field_values['z2AF Work Log03'] = get_attachment(@parameters['customer_survey_instance_id'],
      @parameters['attachment_question_menu_label_3'], @parameters['survey_template_instance_id']
    ) if @parameters['attachment_question_menu_label_3']

    # Retrieve the CHG:Infrastructure Change entry that will be associated with
    # the CHG:WorkLog entry.  This entry is retrieved using the change_number
    # parameter and the request id of the entry is used.
    change_entry = @@remedy_forms_remote['CHG:Infrastructure Change'].find_entries(
      :single,
      :conditions => [%|'Infrastructure Change ID' = "#{@parameters['change_number']}"|],
      :fields => []
    )
    if change_entry.nil?
      raise(%|Could not find entry on CHG:Infrastructure Change with 'Infrastructure Change ID'="#{@parameters['change_number']}"|)
    end
    @field_values['Infra. Change Entry ID'] = change_entry.id

    # Log the final values that will be used to create the CHG:WorkLog record.
    puts(format_hash("Field Values:", @field_values)) if @debug_logging_enabled

    # Create the CHG:WorkLog record using the @field_values hash that was built
    # up.  Pass empty array to the fields argument because no fields are necessary
    # to build the results XML.
    entry = @@remedy_forms_remote['CHG:WorkLog'].create_entry!(
      :field_values => @field_values,
      :fields       => []
    )
    
    # Build the results xml that will be returned by this handler.
    results = <<-RESULTS
    <results>
      <result name="Entry Id">#{escape(entry.id)}</result>
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

  # Returns the 'At_AttachmentOne' field from a KS_ACC_Attachment record.  The record
  # is retrieved using the given customer_survey_instance_id, attachment_question_menu_label,
  # and survey_template_instance_id.  It first queries KS_SRV_SurveyQuestion with
  # the attachment_question_menu_label and survey_template_instance_id to retrieve
  # the instance id of the question.  It then queries the KS_SRV_QuestionAnswerJoin
  # form with the question instance id and the custom survey instance id to retrieve
  # the answer instance id.  It finally queries the KS_ACC_Attachment form with
  # the answer instance id to retrieve the attachment record.
  #
  # Raises an exception if a KS_SRV_SurveyQuestion record could not be found with
  # the attachment_question_menu_label and survey_template_instance_id parameters.
  #
  # ==== Parameters
  # * customer_survey_instance_id (String) - The 'instanceId' of the KS_SRV_CustomerSurvey_base
  #   record related to this submission.
  # * attachment_question_menu_label (String) - The menu label of the attachment
  #   question whose attachment we want to retrieve.
  # * survey_template_instance_id (String) - The 'SurveyInstanceID' of the KS_SRV_CustomerSurvey_base
  #   record related to this submission.  This parameter is used to retrieve question
  #   information about this service item.
  #
  def get_attachment(customer_survey_instance_id, attachment_question_menu_label, survey_template_instance_id)
    survey_question_entry = @@remedy_forms['KS_SRV_SurveyQuestion'].find_entries(
      :single,
      :conditions => [%|'Editor Label' = "#{attachment_question_menu_label}" AND 'SurveyInstanceID' = "#{survey_template_instance_id}"|],
      :fields     => ['instanceId']
    )
    # A question record on KS_SRV_SurveyQuestion could not be found with the given
    # attachment_question_menu_label and survey_template_instance_id parameters.
    if survey_question_entry.nil?
      raise("No question was found with given label #{attachment_question_menu_label}")
    end
    
    question_answer_entry = @@remedy_forms['KS_SRV_QuestionAnswerJoin'].find_entries(
      :single,
      :conditions => [%|'QuestioninstanceId' = "#{survey_question_entry['instanceId']}" AND 'CustomerSurveyInstanceID' = "#{customer_survey_instance_id}"|],
      :fields     => ['answerinstanceId']
    )
    # The question does not have a related KS_SRV_QuestionAnswerJoin record for
    # the current submission.
    return nil if question_answer_entry.nil?

    attachment_entry = @@remedy_forms['KS_ACC_Attachment'].find_entries(
      :single,
      :conditions => [%|'FormID' = "#{question_answer_entry['answerinstanceId']}"|],
      :fields     => ['At_AttachmentOne']
    )
    # The answer does not have a related KS_ACC_Attachment record.
    return nil if attachment_entry.nil?

    # Return the 'At_AttachmentOne' field from the KS_ACC_Attachment record.
    attachment_entry['At_AttachmentOne']
  end

  # Returns a String URL for the review request page for the given submission.
  #
  # ==== Parameters
  # * customer_survey_instance_id (String) - The 'instanceId' of the KS_SRV_CustomerSurvey_base
  #   record related to this submission.
  # * default_web_server (String) - The value of the application configuration item
  #   named Default Web Server.  This is used when building the review request URL.
  #
  def review_request_string(customer_survey_instance_id, default_web_server)
    "#{default_web_server}ReviewRequest?csrv=#{customer_survey_instance_id}\n\n"
  end
  
  # Returns a String of question answer pairs.  The question answer data is retrieved
  # from KS_SRV_QuestionAnswerJoin using the customer_survey_instance_id parameter.
  #
  # ==== Parameters
  # * customer_survey_instance_id (String) - The 'instanceId' of the KS_SRV_CustomerSurvey_base
  #   record related to this submission.
  #
  def question_answers_string(customer_survey_instance_id)
    entries = @@remedy_forms['KS_SRV_QuestionAnswerJoin'].find_entries(
      :all,
      :order      => ['Question_Order'],
      :conditions => [%|'CustomerSurveyInstanceID' = "#{customer_survey_instance_id}"|],
      :fields     => ['Question', 'FullAnswer']
    )
    entries.inject("\n\nQuestion Answer Pairs:\n") do |result, entry|
      result << "    #{entry['Question']}: #{entry['FullAnswer']}\n"
    end
  end

  ##############################################################################
  # General handler utility functions
  ##############################################################################

  # Preinitialize expensive operations that are not task node dependent (IE
  # don't change based on the input parameters passed via xml to the #initialize
  # method).  This will very frequently utilize task info items to do things
  # such as pre-load a Remedy form or generate a Remedy proxy user.
  def preinitialize_on_first_load(input_document, form_names)
    # Unless this method has already been called...
    unless self.class.class_variable_defined?('@@preinitialized')
      # Initialize a remedy context (login) account to execute the Remedy queries.
      @@remedy_context = ArsModels::Context.new(
        :server         => get_info_value(input_document, 'server'),
        :username       => get_info_value(input_document, 'username'),
        :password       => get_info_value(input_document, 'password'),
        :port           => get_info_value(input_document, 'port'),
        :prognum        => get_info_value(input_document, 'prognum'),
        :authentication => get_info_value(input_document, 'authentication')
      )
      # Initialize the remedy forms that will be used by this handler.
      @@remedy_forms = form_names.inject({}) do |hash, form_name|
        hash.merge!(form_name => ArsModels::Form.find(form_name, :context => @@remedy_context))
      end
      # Store that we are preinitialized so that this method is not called twice.
      @@preinitialized = true
    end
  end

  def preinitialize_on_first_load_remote(input_document, form_names)
    # Unless this method has already been called...
    unless self.class.class_variable_defined?('@@preinitialized_remote')
      # Initialize a remedy context (login) account to execute the Remedy queries.
      @@remedy_context_remote = ArsModels::Context.new(
        :server         => get_info_value(input_document, 'ars_server'),
        :username       => get_info_value(input_document, 'ars_username'),
        :password       => get_info_value(input_document, 'ars_password'),
        :port           => get_info_value(input_document, 'ars_port'),
        :prognum        => get_info_value(input_document, 'ars_prognum'),
        :authentication => get_info_value(input_document, 'ars_authentication')
      )
      # Initialize the remedy forms that will be used by this handler.
      @@remedy_forms_remote = form_names.inject({}) do |hash, form_name|
        hash.merge!(form_name => ArsModels::Form.find(form_name, :context => @@remedy_context_remote))
      end
      # Store that we are preinitialized so that this method is not called twice.
      @@preinitialized_remote = true
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