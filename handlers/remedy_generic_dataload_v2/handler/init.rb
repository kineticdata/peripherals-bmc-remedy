require 'rexml/document'
require 'ars_models'
require 'csv'
require 'base64'

class RemedyGenericDataloadV2
  # Prepare for execution by pre-loading Ars form definitions, building Hash
  # objects for necessary values, and validating the present state.  This method
  # sets the following instance variables:
  # * @input_document - A REXML::Document object that represents the input Xml.
  # * @debug_logging_enabled - A Boolean value indicating whether logging should
  #   be enabled or disabled.
  # * @parameters - A Hash of parameter names to parameter values.
  # * @field_values - A Hash of KS_SRV_CustomerSurvey_base database field names
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

    # Initialize the handler and pre-load form definitions using the credentials
    # supplied by the task info items.
    preinitialize_on_first_load(
      @input_document,
      ['KS_SRV_SurveyQuestion','KS_SRV_QuestionAnswerJoin','KS_ACC_Attachment','KS_SRV_CustomerSurvey_base']
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

    # Retrieve the list of field values that will be written to the approval record
    @field_values = {}
    REXML::XPath.match(@input_document, '/handler/fields/field').each do |node|
      @field_values[node.attribute('name').value] = node.text
    end
    puts(format_hash("Field Values:", @field_values)) if @debug_logging_enabled
  end
  # Creates a record in the KS_SRV_Helper form
  #
  # This is a required method that is automatically called by the Kinetic Task
  # Engine.
  #
  # ==== Returns
  # An Xml formatted String representing the return variable results.
  def execute()
    # Initialize Results variables
	status=""
	error_code=""
	results_message=""
	
	#get service item template ID
	templateId = get_template_id(@parameters['customer_survey_instance_id'])
	
	# Retrieve the CSV file
    csvfile = get_attachment(@parameters['customer_survey_instance_id'],@parameters['csv_file'], templateId)
	
	
		
		if status!="Error"
			# csvfile is an ARSmodels attachment type.  The base64_content contains the actual file content.
			file = Base64.decode64(csvfile.base64_content)
			records = CSV.parse(file)
			
			
			#puts "Field Names Provided: #{@field_names.inspect}" if @debug_logging_enabled
			puts "CSV: #{records.inspect}" if @debug_logging_enabled
			
			count = 0
			@field_names = []
			column_count = 0
			
			records.each do |record|

				column_num = 0
				@field_values = {}
				
				if count == 0 
					column_count = record.length
					@field_names = record
				else
					if record.length < column_count
					   raise("Too few data columns for record #{rowcount}.\nData: #{record.inspect}")
					end
					
					while column_num < column_count
						# Add field_values
						@field_values[@field_names[column_num]]=record[column_num]

						# Increment column number
						column_num += 1
					end
					
					puts("Working on row: #{@field_values.inspect}") if @debug_logging_enabled
					
					entry = get_remedy_form(@parameters['form']).create_entry!(
					:field_values => @field_values,
					:fields       => []
					)
				end
				
				count = count + 1
			end
			
			count = count -1
			status="Success"
			results_message += "#{count} records created."
		end




    # Build the results xml that will be returned by this handler.
    results = <<-RESULTS
    <results>
      <result name="Status">#{status}</result>
	  <result name="Error Code">#{error_code}</result>
	  <result name="Result Message">#{results_message}</result>
    </results>
    RESULTS
    puts("Results: \n#{results}") if @debug_logging_enabled

    # Return the results String
    return results
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
  
  def get_template_id(customer_survey_instance_id)
	base_entry = @@remedy_forms['KS_SRV_CustomerSurvey_base'].find_entries(
      :single,
      :conditions => [%|'instanceId' = "#{customer_survey_instance_id}"|],
      :fields     => ['SurveyInstanceID']
    )
	if base_entry.nil?
      raise("No submission was found with given id #{customer_survey_instance_id}")
    end
	
	base_entry['SurveyInstanceID']
  end
  
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
  
    # This method is an accessor for the @@remedy_forms variable that caches form
  # definitions.  It checks to see if the specified form has been loaded if so
  # it returns it otherwise it needs to load the form and add it to the cache.
  def get_remedy_form(form_name)
  	if @@remedy_forms[form_name].nil?
  		@@remedy_forms[form_name] = ArsModels::Form.find(form_name, :context => @@remedy_context)
  	end
  	if @@remedy_forms[form_name].nil?
  		raise "Could not find form " + form_name
  	end
  	@@remedy_forms[form_name]
  end
  
end
