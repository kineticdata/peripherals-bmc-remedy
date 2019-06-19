require 'rexml/document'
require 'ars_models'

class BmcItsm7TaskTemplatedCreateV2
  # Prepare for execution by pre-loading ARS form definitions, building Hash
  # objects for necessary values, and validating the present state.  This method
  # sets the following instance variables:
  # * @input_document - A REXML::Document object that represents the input XML.
  # * @debug_logging_enabled - A Boolean value indicating whether logging should
  #   be enabled or disabled.
  # * @task_field_values - A Hash of TMS:Task database field names to their
  #   respective values.
  # * @flow_builder_field_values - A Hash of TMS:FlowBuilder database field names
  #   to their respective values.
  #
  # This is a required method that is automatically called by the Kinetic Task
  # Engine.
  #
  # ==== Parameters
  # * +input+ - The String of XML that was built by evaluating the node.xml
  #   handler template.
  def initialize(input)
    # Set the input document attribute
    @input_document = REXML::Document.new(input)

    # Initialize the handler and pre-load form definitions using the credentials
    # supplied by the task info items.
    preinitialize_on_first_load(
      @input_document,
      ['TMS:Task', 'TMS:TaskTemplate', 'TMS:Association', 'TMS:FlowBuilder']
    )

    # Determine and store whether or not debug logging is enabled.  The variable
    # @debug_logging_enabled will be a boolean that tells the log() function whether
    # or not to print messages.
    @debug_logging_enabled = get_info_value(@input_document, 'enable_debug_logging') == 'Yes'
    log("Logging enabled.")

    # Store parameters in the node.xml in a hash attribute named @parameters.
    @parameters = {}
    REXML::XPath.match(@input_document, '/handler/parameters/parameter').each do |node|
      @parameters[node.attribute('name').value] = node.text
    end
    log(format_hash("Handler Parameters:", @parameters))

    # Build a hash called @task_field_values from the task_fields part of the node.xml.
    # These field values will be used when creating the TMS:Task record.
    @task_field_values = {}
    REXML::XPath.match(@input_document, '/handler/task_fields/field').each do |node|
      @task_field_values[node.attribute('name').value] = node.text
    end

    # Build a hash called @flow_builder_field_values from the flow_builder_fields
    # part of the node.xml.  These field values will be used when creating the
    # TMS:FlowBuilder record.
    @flow_builder_field_values = {}
    REXML::XPath.match(@input_document, '/handler/flow_builder_fields/field').each do |node|
      @flow_builder_field_values[node.attribute('name').value] = node.text
    end
  end

  # This method creates a TMS:Task and a TMS:FlowBuilder entry.  It also does a
  # lookup on TMS:Association to find some data necessary for creating the entry
  # on TMS:FlowBuilder.
  #
  # This is a required method that is automatically called by the Kinetic Task
  # Engine.
  #
  # ==== Returns
  # An XML String representing the return variable results.
  def execute
    @task_field_values['TemplateID'] = get_template_id(@parameters['task_name'],
      @parameters['location_company'])
    log(format_hash("Handler Task Field Values:", @task_field_values))

    # Create the TMS:Task entry using the @task_field_values hash that was built.
    # Pass 'InstanceId' to the fields argument because the 'InstanceId' of the
    # created record will be used to create the TMS:FlowBuilder entry.
    task_entry = @@remedy_forms['TMS:Task'].create_entry!(
      :field_values => @task_field_values,
      :fields => ['InstanceId']
    )

    # Retrieve the associated TMS:Association record that was created by work flow
    # when the TMS:Task record was created.  We need the 'InstanceId' of this record
    # when we push to TMS:FlowBuilder.
    association_entry = @@remedy_forms['TMS:Association'].find_entries(
      :single,
      :conditions => [%|'Child ID'="#{task_entry['InstanceId']}"|],
      :fields => ['InstanceId']
    )
    if association_entry.nil?
      raise(%|Could not find TMS:Association record with 'Child ID'="#{task_entry['InstanceId']}"|)
    end

    # Add some data to @flow_builder_field_values hash from the TMS:Task and the
    # TMS:Association entries.
    @flow_builder_field_values['Child ID'] = task_entry['InstanceId']
    @flow_builder_field_values['zTmpSuccessorLink'] = association_entry['InstanceId']
    log(format_hash("TMS:FlowBuilder Field Values:", @flow_builder_field_values))

    # Push to the display only TMS:FlowBuilder form to trigger work flow that builds
    # the flow for our new task.  Pass an empty array to the fields argument because
    # no fields are needed from the created entry.
    @@remedy_forms['TMS:FlowBuilder'].create_entry!(
      :field_values => @flow_builder_field_values,
      :fields => []
    )

    # Build the results XML that will be returned by this handler.
    results = <<-RESULTS
    <results>
      <result name="Task Id">#{escape(task_entry.id)}</result>
    </results>
    RESULTS
    log("Results: \n#{results}")

    # Return the results String
    return results
  end

  # Calls puts on the argument message if the @debug_logging_enable attribute is
  # true.  This function is meant to clean up code by replacing statements like:
  #   puts("Log message") if @debug_logging_enabled
  # with statements like:
  #   log("Log message")
  def log(message)
    puts(message) if @debug_logging_enabled
  end

  ##############################################################################
  # BMC_ITSM7_Task_TemplatedCreate handler utility functions
  ##############################################################################

  # Retrieves the String 'InstanceId' of the TMS:TaskTemplate record that is
  # associated to the specified task name.
  #
  # Raises an exception if there was no TMS:TaskTemplate record that had
  # 'TaskName' equal to the specified task_name parameter.
  #
  # ==== Parameters
  # * task_name (String) - The name of the task to use.
  #
  def get_template_id(task_name, location_company)
    # Retrieve the TMS:TaskTemplate entry using the task_name parameter in the
    # qualification.
    qual = %|'TaskName' = "#{task_name}" AND 'Location Company' = "#{location_company}"|
    entry = @@remedy_forms['TMS:TaskTemplate'].find_entries(
      :first,
      :conditions => [qual],
      :fields     => ['InstanceId']
    )
    # Raise an exception if no TMS:TaskTemplate entry was found with the given name.
    if entry.nil?
      raise(%|Could not find TMS:TaskTemplate entry matching qualification: #{qual}|)
    end
    # Return the 'InstanceId' of the TMS:TaskTemplate entry.
    entry['InstanceId']
  end
  
  ##############################################################################
  # General handler utility functions
  ##############################################################################

  # Preinitialize expensive operations that are not task node dependent (IE
  # don't differ based on the input parameters passed via xml to the #initialize
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
    # Retrieve the XML node representing the desired info value
    info_element = REXML::XPath.first(document, "/handler/infos/info[@name='#{name}']")
    # If the desired element is nil, return nil; otherwise return the text value of the element
    info_element.nil? ? nil : info_element.text
  end
end