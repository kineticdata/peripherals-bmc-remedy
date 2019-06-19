require 'rexml/document'
require 'ars_models'

class BmcExecuteProcessV2
  # Prepare for execution building hash objects for necessary values and 
  # validating the present state. This handler touches no forms.
  #
  # This method sets the following instance variables:
  # * @input_document - A REXML::Document object that represents the input Xml.
  # * @debug_logging_enabled - A Boolean value indicating whether logging should
  #   be enabled or disabled.
  # * @parameters - A Hash of parameter names to parameter values.
  # * @field_values - A field name/value pairs defined in the node.xml.
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
    preinitialize_on_first_load( @input_document)

    # Determine if debug logging is enabled.
    @debug_logging_enabled = get_info_value(@input_document, 'enable_debug_logging') == 'Yes'
    log "Logging enabled."

    # Store parameters in the node.xml in a hash attribute named @parameters.
    @parameters = {}
    REXML::XPath.match(@input_document, '/handler/parameters/parameter').each do |node|
      @parameters[node.attribute('name').value] = node.text
      log node.text
    end
    log (format_hash("Handler Parameters:", @parameters))

    # Retrieve the list of field values
    @field_values = {}
    REXML::XPath.match(@input_document, '/handler/fields/field').each do |node|
      @field_values[node.attribute('name').value] = node.text
    end
  end

  # Submit an Execute Process to the system and either waits for a response
  # or moves on without waiting for a response.
  # 
  # This is a required method that is automatically called by the Kinetic Task
  # Engine.
  #
  # ==== Returns
  # If the option to wait for a respoinse is used, an Xml formatted String 
  # representing the return variable results.
  def execute()
    # Attempt to include the get a valid ARServerUser object
    # and include some AR classes 
    begin
      # If this succeeds we're in the older API (com.remedy.arsys.api)
      server_user = @@remedy_context.ars_context.get_context 
      include_class 'com.remedy.arsys.api.Util'
      is_old_api = true
      log('This the older AR API version.')
    rescue Exception
      begin
        # If this succeeds we're in the newer API (com.bmc.arsys.api)
        server_user = @@remedy_context.ars_context
        is_old_api = false
        log('This the newer AR API version.')
      rescue Exception
        log "Warning: Unable to get a Remedy ARServerUser context object."
      end
    end

    # Define the command to execute; must be a valid command on the server
    # example:  command = "Application-Generate-GUID"
    command = @field_values['Command']

    # Determine if we should wait for the results (synchronous) or not
    @field_values['Wait for server result'] == "No" ? wait = false : wait = true

    # proc_result = @@remedy_context.ars_context.executeProcess(command, wait)
    if is_old_api
      proc_result = Util.ARExecuteProcess(server_user, command, wait)
    else
      proc_result = server_user.executeProcess(command, wait)
    end

    # Build the results xml that will be returned by this handler.
    results = <<-RESULTS
    <results>
      <result name="Return Value">#{escape(proc_result.getOutput())}</result>
      <result name="Return Status">#{escape(proc_result.getStatus())}</result>
    </results>
    RESULTS
    log "Results: \n#{results}"

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
  def preinitialize_on_first_load(input_document)
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
      # Store the preinitialized state so that this method is not called twice.
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
    # Retrieve the XML node representing the desird info value
    info_element = REXML::XPath.first(document, "/handler/infos/info[@name='#{name}']")
    # If the desired element is nil, return nil; otherwise return the text 
    # value of the element
    info_element.nil? ? nil : info_element.text
  end

  # Calls puts on the argument message if the @debug_logging_enable attribute is
  # true.  This function is meant to clean up code by replacing statements like:
  #   puts("Log message") if @debug_logging_enabled
  # with statements like:
  #   log("Log message")
  def log(message)
    if @debug_logging_enabled
      # Show the line number to help with debugging.
      puts "[#{caller.first.split(":")[-2]}] #{message}"
    end
  end

end
