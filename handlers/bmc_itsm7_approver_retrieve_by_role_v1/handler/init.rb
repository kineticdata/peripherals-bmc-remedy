# Require the REXML ruby library.
require 'rexml/document'
# Require the ArsModels ruby gem.  This is a Ruby helper library that wraps many
# of the common Remedy operations.
require 'ars_models'

# Define the handler class which should:
#  * Be named in the format <GROUP><ITEM><ACTION>HandlerV<VERSION>
#  * Include an initialize method that takes a single String of XML.
#  * Include an execute method that returns XML in the expected format
class BmcItsm7ApproverRetrieveByRoleV1
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
    preinitialize_on_first_load(
      @input_document,
      ['AP:Role']
    )
    
    # Store parameters in the node.xml in a hash attribute named @parameters.
    @parameters = {}
    REXML::XPath.match(@input_document, '/handler/parameters/parameter').each do |node|
      @parameters[node.attribute('name').value] = node.text
    end

  end

  # The execute method takes no parameters and should leverage the instance
  # variables setup and validated by the initialize method to generate a result
  # xml string.
  def execute()
    # Retrieve the entry using the ArsModels form setup the first time this
    # handler is executed.  Use the :single option because there should only be
    # one entry returned, if more than one is found this function call will raise
    # an exception.  Use :fields => :all to retrieve all of the fields.
	

    entry = @@remedy_forms['AP:Role'].find_entries(
      :single, 
      :conditions => [%`'Role Name' = "#{@parameters['role_name']}" AND 'Status' = "Active"`],
      :fields => ['If Multiple Approvers','Member List']
    )
    
    # Raise an exception if no record was found.
    if entry.nil?
      raise("There was no active role record with the name: #{@parameters['role_name']}")
    end

	if entry['If Multiple Approvers'].nil?
		ifmult = "None"
	else
		ifmult = entry['If Multiple Approvers'].value
	end
	
	xml = '<userIds>'

	apprs = entry['Member List'].split(";")
	apprs.each do |appr|
		if (appr != "")
			xml << '<userId>'+ appr +'</userId>'
		end
	end
		

    
	xml << '</userIds>'
	
    # Return the results
    <<-RESULTS
    <results>
      <result name="userIdList">#{escape(xml)}</result>
	  <result name="ifMultiple">#{escape(ifmult)}</result>
    </results>
    RESULTS
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
end