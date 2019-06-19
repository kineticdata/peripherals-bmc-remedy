# Require the dependencies file to load the vendor libraries
require File.expand_path(File.join(File.dirname(__FILE__), 'dependencies'))


# Define the handler class which should:
#  * Be named in the format <GROUP><ITEM><ACTION>HandlerV<VERSION>
#  * Include an initialize method that takes a single String of XML.
#  * Include an execute method that returns XML in the expected format
class RemedyGenericCreateV2
  # The initialize method takes a String of XML.  This XML is defined in the
  # process/node.xml file as the taskDefinition/handler element.  This method
  # should setup (usually retrieve from the input xml) any instance variables
  # that will be used by the handler, validate that the variables are valid, and
  # optionally call a preinitialize_on_first_load method (if there are expensive
  # operations that don't need to be executed with each task node instance).
  def initialize(input)
    # Set the input document attribute
    @input_document = REXML::Document.new(input)

    # Initialize the handler and pre-load form definitions using the credentials
    # supplied by the task info items.
    preinitialize_on_first_load(@input_document, [])
	
	 # Determine if debug logging is enabled.
    @debug_logging_enabled = get_info_value(@input_document, 'enable_debug_logging') == 'Yes'
    puts("Logging enabled.") if @debug_logging_enabled

    # Initialize the parameters hash.
    @parameters = {}
    # For each of the parameters in the node.xml file, add them to the hash
    REXML::XPath.match(@input_document, '/handler/parameters/parameter').each do |node|
      @parameters[node.attribute('name').value] = node.text
    end
	puts(format_hash("Parameters:", @parameters)) if @debug_logging_enabled
	
		@field_values  = {}
  end

  # The execute method takes no parameters and should leverage the instance
  # variables setup and validated by the initialize method to generate a result
  # xml string.
  def execute()
    # Create the entry using the ArsModels form setup the first time this
    # handler is executed.  The :field_values parameter takes a Hash of field
    # names to value mappings (which was built in the #initialize method).  The
    # :fields parameter is an optional Array of field values to return with the
    # entry.  By default (when the :fields parameter is omitted), all field
    # values are returned.  For large forms, the performance gained by
    # specifying a smaller subset of fields can be significant.
	@field_values = JSON.parse(@parameters['field_values'])
	puts(format_hash("Field Values:", @field_values)) if @debug_logging_enabled
	
    entry = get_remedy_form(@parameters['form']).create_entry!(
      :field_values => @field_values,
      :fields => []
    )

    # Return the results
    <<-RESULTS
    <results>
      <result name="Entry Id">#{escape(entry.id)}</result>
    </results>
    RESULTS
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

  # Preinitialize expensive operations that are not task node dependent (IE
  # don't change based on the input parameters passed via xml to the #initialize
  # method).  This will very frequently utilize task info items to do things
  # such as pre-load a Remedy form or generate a Remedy proxy user.
  def preinitialize_on_first_load(input_document, form_names)
    # Unless this method has already been called
    unless self.class.class_variable_defined?('@@preinitialized')
      # Initialize a remedy context (login) account to execute the Remedy queries
      @@remedy_context = ArsModels::Context.new(
        :server => get_info_value(input_document, 'server'),
        :username => get_info_value(input_document, 'username'),
        :password => get_info_value(input_document, 'password'),
        :port => get_info_value(input_document, 'port'),
        :prognum => get_info_value(input_document, 'prognum'),
        :authentication => get_info_value(input_document, 'authentication')
      )

      # Initialize the remedy forms that will be used by this handler.
      @@remedy_forms = form_names.inject({}) do |hash, form_name|
        hash.merge!(form_name => ArsModels::Form.find(form_name, :context => @@remedy_context))
      end

      # Store that we are preinitialized so that this method is not called a second time
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
    string.to_s.gsub(/[&"><]/) { |special| ESCAPE_CHARACTERS[special] }
  end
  # This is a ruby constant that is used by the escape method
  ESCAPE_CHARACTERS = {'&'=>'&amp;', '>'=>'&gt;', '<'=>'&lt;', '"' => '&quot;'}

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
  
    def format_hash(header, hash)
    # Staring with the "header" parameter string, concatenate each of the
    # parameter name/value pairs with a prefix intended to better display the
    # results within the Kinetic Task log.
    hash.inject(header) do |result, (key, value)|
      result << "\n    #{key}: #{value}"
    end
  end
end
