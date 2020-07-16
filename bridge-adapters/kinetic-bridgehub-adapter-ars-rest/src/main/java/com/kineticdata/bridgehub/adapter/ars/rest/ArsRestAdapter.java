package com.kineticdata.bridgehub.adapter.ars.rest;

import com.jayway.jsonpath.DocumentContext;
import com.jayway.jsonpath.JsonPath;
import com.jayway.jsonpath.JsonPathException;
import com.kineticdata.bridgehub.adapter.BridgeAdapter;
import com.kineticdata.bridgehub.adapter.BridgeError;
import com.kineticdata.bridgehub.adapter.BridgeRequest;
import com.kineticdata.bridgehub.adapter.BridgeUtils;
import com.kineticdata.bridgehub.adapter.Count;
import com.kineticdata.bridgehub.adapter.Record;
import com.kineticdata.bridgehub.adapter.RecordList;
import com.kineticdata.commons.v1.config.ConfigurableProperty;
import com.kineticdata.commons.v1.config.ConfigurablePropertyMap;
import java.io.IOException;
import java.io.UnsupportedEncodingException;
import java.net.URLEncoder;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import org.json.simple.JSONArray;
import org.json.simple.JSONObject;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class ArsRestAdapter implements BridgeAdapter {
    /*----------------------------------------------------------------------------------------------
     * CONSTRUCTOR
     *--------------------------------------------------------------------------------------------*/
    public ArsRestAdapter () {
        // Parse the query and exchange out any parameters with their parameter 
        // values. ie. change the query username=<%=parameter["Username"]%> to
        // username=test.user where parameter["Username"]=test.user
        this.parser = new ArsRestQualificationParser();
    }
    
    /*----------------------------------------------------------------------------------------------
     * STRUCTURES
     *      AdapterMapping( Structure Name, Path Function)
     *--------------------------------------------------------------------------------------------*/
    public static Map<String,AdapterMapping> MAPPINGS 
        = new HashMap<String,AdapterMapping>() {{
        put("Entry", new AdapterMapping("Entry",
            ArsRestAdapter::pathEntry));
        put("Adhoc", new AdapterMapping("Adhoc",
            ArsRestAdapter::pathAdhoc));
    }};
    
    /*----------------------------------------------------------------------------------------------
     * PROPERTIES
     *--------------------------------------------------------------------------------------------*/

    /** Defines the adapter display name */
    public static final String NAME = "Ars Rest Bridge";

    /** Defines the logger */
    protected static final Logger LOGGER = LoggerFactory.getLogger(ArsRestAdapter.class);
    
    /** Adapter version constant. */
    public static String VERSION = "";
    /** Load the properties version from the version.properties file. */
    static {
        try {
            java.util.Properties properties = new java.util.Properties();
            properties.load(ArsRestAdapter.class.getResourceAsStream("/"+ArsRestAdapter.class.getName()+".version"));
            VERSION = properties.getProperty("version");
        } catch (IOException e) {
            LOGGER.warn("Unable to load "+ArsRestAdapter.class.getName()+" version properties.", e);
            VERSION = "Unknown";
        }
    }

    /** Defines the collection of property names for the adapter */
    public static class Properties {
        public static final String PROPERTY_USERNAME = "Username";
        public static final String PROPERTY_PASSWORD = "Password";
        public static final String PROPERTY_ORIGIN = "URL Origin";

    }

    private final ConfigurablePropertyMap properties = new ConfigurablePropertyMap(
        new ConfigurableProperty(Properties.PROPERTY_USERNAME).setIsRequired(true),
        new ConfigurableProperty(Properties.PROPERTY_PASSWORD).setIsSensitive(true),
        new ConfigurableProperty(Properties.PROPERTY_ORIGIN).setIsRequired(true)
            .setDescription("The scheme://hostname:port of the Ars Server")
    );

    // Local variables to store the property values in
    private String username;
    private String password;
    private String origin;
    private ArsRestQualificationParser parser;
    private ArsRestApiHelper apiHelper;
    
    // constant variables
    private final String API_PATH = "/api/arsys/v1";
    
    /*---------------------------------------------------------------------------------------------
     * SETUP METHODS
     *-------------------------------------------------------------------------------------------*/

    @Override
    public void initialize() throws BridgeError {
        // Initializing the variables with the property values that were passed
        // when creating the bridge so that they are easier to use
        username = properties.getValue(Properties.PROPERTY_USERNAME);
        password = properties.getValue(Properties.PROPERTY_PASSWORD);
        origin = properties.getValue(Properties.PROPERTY_ORIGIN);
        
        apiHelper = new ArsRestApiHelper(origin, username, password);
        
        apiHelper.getToken();
    }

    @Override
    public String getName() {
        return NAME;
    }

    @Override
    public String getVersion() {
       return VERSION;
    }

    @Override
    public void setProperties(Map<String,String> parameters) {
        // This should always be the same unless there are special circumstances
        // for changing it
        properties.setValues(parameters);
    }

    @Override
    public ConfigurablePropertyMap getProperties() {
        // This should always be the same unless there are special circumstances
        // for changing it
        return properties;
    }

    /*---------------------------------------------------------------------------------------------
     * IMPLEMENTATION METHODS
     *-------------------------------------------------------------------------------------------*/

    @Override
    public Count count(BridgeRequest request) throws BridgeError {
        // Log the access
        LOGGER.trace("Counting records");
        LOGGER.trace("  Structure: " + request.getStructure());
        LOGGER.trace("  Query: " + request.getQuery());

        // parse Structure
        List<String> structureList = Arrays.asList(request.getStructure().trim()
            .split("\\s*>\\s*"));
        // get Structure model
        AdapterMapping mapping = getMapping(structureList.get(0));
        
        Map<String, String> parameters = getParameters(
            parser.parse(request.getQuery(),request.getParameters()), mapping);
        
        // Path builder functions may mutate the parameters Map;
        String path = mapping.getPathbuilder().apply(structureList, parameters);
        
        // Retrieve the objects based on the structure from the source
        JSONObject object = apiHelper.executeRequest(getUrl(path, 
            parameters));
        
        // Get domain specific data.
        JSONArray entries = (JSONArray)object.get("entries");
        
        Integer count;
        // If entries null check for single value.
        // TODO: consider using mapper for single/multiple similar to kinetic core
        if (entries == null &&  object.get("values") != null) {
           count = 1;
        } else {
            // Get the number of elements in the returned array
            count = entries.size();
        }
        
        // Create and return a count object that contains the count
        return new Count(count);
    }

    @Override
    public Record retrieve(BridgeRequest request) throws BridgeError {
        // Log the access
        LOGGER.trace("Retrieving Kinetic Request CE Record");
        LOGGER.trace("  Structure: " + request.getStructure());
        LOGGER.trace("  Query: " + request.getQuery());
        LOGGER.trace("  Fields: " + request.getFieldString());

        // parse Structure
        List<String> structureList = Arrays.asList(request.getStructure().trim()
            .split("\\s*>\\s*"));
        // get Structure model
        AdapterMapping mapping = getMapping(structureList.get(0));
        
        Map<String, String> parameters = getParameters(
            parser.parse(request.getQuery(),request.getParameters()), mapping);
        
        // Path builder functions may mutate the parameters Map;
        String path = mapping.getPathbuilder().apply(structureList, parameters);
        
        // Retrieve the objects based on the structure from the source
        JSONObject object = apiHelper.executeRequest(getUrl(path, parameters));

        // Get domain specific data.
        // TODO: consider using mapper for single/multiple similar to kinetic
        // core
        JSONObject obj = (JSONObject)(object).get("values");
        JSONArray entries = (JSONArray)object.get("entries");
        
        // If "multiple" were requested than obj will be null and entries will 
        // get populated.
        Record record = new Record();
        if (entries != null) {
            // Throw error if multiple results found.
            if (entries.size() > 1) {
                throw new BridgeError ("Retrieve must return a single result."
                    + " Multiple results found.");
            } else if (entries.size() == 0) {
                // empty retrieve condition
                return new Record();
            } else if (entries.size() == 1){
                obj = (JSONObject)((JSONObject)entries.get(0)).get("values");
            }
        }
        if (obj != null) {
            List<String> fields = getFields(request.getFields() == null ? 
                new ArrayList() : request.getFields(), obj);
            record = buildRecord(fields, obj);
        } else {
            throw new BridgeError ("An unexpected error has occured.");
        }

        // Return the created Record object
        return record;
    }

    @Override
    public RecordList search(BridgeRequest request) throws BridgeError {
        // Log the access
        LOGGER.trace("Searching Records");
        LOGGER.trace("  Structure: " + request.getStructure());
        LOGGER.trace("  Query: " + request.getQuery());
        LOGGER.trace("  Fields: " + request.getFieldString());
        
        // parse Structure
        List<String> structureList = Arrays.asList(request.getStructure().trim()
            .split("\\s*>\\s*"));
        // get Structure model
        AdapterMapping mapping = getMapping(structureList.get(0));

        Map<String, String> parameters = getParameters(
            parser.parse(request.getQuery(),request.getParameters()), mapping);
        addLimit(parameters);
        
        Map<String, String> metadata = request.getMetadata() != null ?
                request.getMetadata() : new HashMap<>();

        // If offest exists in metadata add it to the parameters for use with 
        // reqeust.  
        if (metadata.get("offset") != null) {
            // Offset in parameters takes precedence.
            parameters.putIfAbsent("offset", metadata.get("offset"));
        }
        // clear metadata object to be repopulated for response.
        metadata.clear();

        // Add a sorting order to be used with the request if order was defined,
        // but sort was not included in the qualification mapping.        
        if (metadata.get("order") != null && !parameters.containsKey("sort")) {
            addSort(metadata.get("order"), parameters);
        }

        // Path builder functions may mutate the parameters Map;
        String path = mapping.getPathbuilder().apply(structureList, parameters);
        
        // Retrieve the objects based on the structure from the source
        JSONObject object = apiHelper.executeRequest(getUrl(path, parameters));

        // Get domain specific data.
        JSONArray entries = (JSONArray)object.get("entries");

        // Create a List of records that will be used to make a RecordList object
        List<Record> recordList = new ArrayList<Record>();
        List<String> fields = request.getFields() == null ? new ArrayList() : 
            request.getFields();
        if(entries.isEmpty() != true){
            fields = getFields(fields, 
                (JSONObject)((JSONObject)entries.get(0)).get("values"));
            // Iterate through the response objects and make a new Record for each.
            for (Object o : entries) {
                JSONObject obj = (JSONObject)((JSONObject)o).get("values");
                
                Record record;
                if (obj != null) {
                    record = buildRecord(fields, obj);;
                } else {
                    record = new Record();
                }
                // Add the created record to the list of records
                recordList.add(record);
            }
            
            setOffset(metadata, parameters);
        }
        
        // Return the RecordList object
        return new RecordList(fields, recordList, metadata);
    }

    /*----------------------------------------------------------------------------------------------
     * HELPER METHODS
     *--------------------------------------------------------------------------------------------*/
    protected List<String> getFields(List<String> fields, JSONObject jsonobj) {
        // if no fields were provided then all fields will be returned. 
        if(fields.isEmpty()){
            fields.addAll(jsonobj.keySet());
        }
        
        return fields;
    }
    
    /**
     * Build a Record.  If no fields are provided all fields will be returned.
     * 
     * @param fields
     * @param jsonobj
     * @return Record
     */
    protected Record buildRecord (List<String> fields, JSONObject jsonobj) {
        JSONObject obj = new JSONObject();
        DocumentContext jsonContext = JsonPath.parse(jsonobj); 
        
        fields.stream().forEach(field -> {
            // either use JsonPath or just add the field value.  We're assuming
            // all JsonPath usages will begin with $[ or $.. 
            if (field.startsWith("$.") || field.startsWith("$[")) {
                try {
                    obj.put(field, jsonContext.read(field));
                } catch (JsonPathException e) {
                    throw new JsonPathException(String.format("There was an issue"
                        + " reading %s", field), e);
                }
            } else {
                obj.put(field, jsonobj.get(field));
            }
        });
        
        Record record = new Record(obj, fields);
        return record;
    }

    /**
     * Set the offset that will be used in subsequent requests for pagination.
     * This method mutates the parameters Map.
     * 
     * @param metadata
     * @param parameters
     */
    protected void setOffset(Map<String, String> metadata, 
        Map<String, String> parameters) {
     
        try {
            int offset = 0;
            int limit = Integer.parseInt(parameters.get("limit"));
            
            if (parameters.containsKey("offset")) {
                offset = Integer.parseInt(parameters.get("offset").trim());
            } else if (metadata.containsKey("offset")) {
                offset = Integer.parseInt(metadata.get("offset").trim());
            }   
            metadata.put("offset", Integer.toString((limit + 1) + offset));
        
        } catch (NumberFormatException e) {
            LOGGER.error("Error parsing int: ", e);
        }
    }

    /**
     * Set limit if none exists or ensure that limit is in acceptable range.
     * This method mutates the parameters Map.
     * 
     * @param parameters
     */
    // TODO: consider if limit is on metadata.
    protected void addLimit(Map<String, String> parameters) {
        int limit = 1000;
        try {
            if (parameters.containsKey("limit")) {
                limit = Integer.parseInt(parameters.get("limit").trim());
                if (limit < 0 || limit > 1000) {
                    limit = 1000;
                    LOGGER.debug("limit was outside standard values. Limit set "
                        + "to 1000 default.");
                }
                parameters.replace("limit", Integer.toString(limit));
            } else {
                parameters.put("limit", "1000");
            }
        } catch (NumberFormatException e) {
            LOGGER.error("limit parmaeter must be a number.  limit set to 1000 "
                + "default. ", e);
        }
    }
    
    private LinkedHashMap<String, String> 
        getSortOrderItems (Map<String, String> uncastSortOrderItems)
        throws IllegalArgumentException{
        
        /* results of parseOrder does not allow for a structure that 
         * guarantees order.  Casting is required to preserver order.
         */
        if (!(uncastSortOrderItems instanceof LinkedHashMap)) {
            throw new IllegalArgumentException("MESSAGE");
        }
        
        return (LinkedHashMap)uncastSortOrderItems;
    }
        
    /**
     *
     * @param responseData
     * @return
     */
    protected JSONArray getResponseData(Object responseData) {
        JSONArray responseArray = new JSONArray();
        
        if (responseData instanceof JSONArray) {
            responseArray = (JSONArray)responseData;
        }
        else if (responseData instanceof JSONObject) {
            // It's an object
            responseArray.add((JSONObject)responseData);
        }
        
        return responseArray;
    }
    
    /**
     * This helper is intended to abstract the parser get parameters from the core
     * methods.
     * 
     * @param request
     * @param mapping
     * @return
     * @throws BridgeError 
     */
    protected Map<String, String> getParameters(String query,  
        AdapterMapping mapping) throws BridgeError {
        
        Map<String, String> parameters = new HashMap<>();
        if (mapping.getStructure() == "Adhoc") {
            // Adhoc qualifications are two segments. ie path?queryParameters
            String [] segments = query.split("[?]",2);

            // getParameters only needs the queryParameters segment
            if (segments.length > 1) {
                parameters = parser.getParameters(segments[1]);
            }
            // Pass the path along to the functional operator
            parameters.put("adapterPath", segments[0]);
        } else {
            parameters = parser.getParameters(query);
        }
        
        return parameters;
    }
        
    /**
     * This method checks that the structure on the request matches on in the 
     * Mapping internal class.  Mappings map directly to the adapters supported 
     * Structures.  
     * 
     * @param structure
     * @return Mapping
     * @throws BridgeError 
     */
    protected AdapterMapping getMapping (String structure) throws BridgeError{
        AdapterMapping mapping = MAPPINGS.get(structure);
        if (mapping == null) {
            throw new BridgeError("Invalid Structure: '" 
                + structure + "' is not a valid structure.");
        }
        return mapping;
    }
    
    /**
     * Build url for request.  Encode all parameters except the sort parameter.
     * The encoding for sort is done in the addSort method.  Read comment for 
     * explanation.
     * 
     * @param path
     * @param parameters
     * @return String
     */
    protected String getUrl (String path, Map<String, String> parameters) {
                
        String str = parameters.entrySet().stream().map(entry -> {
            if (!entry.getKey().equals("sort")) {
                try {
                    return entry.getKey() + "=" 
                        + URLEncoder.encode(entry.getValue(), "UTF-8");
                } catch (UnsupportedEncodingException e) {
                    LOGGER.error("Error encoding query parameter: " + e);
                }
                return entry.getKey() + "=" + entry.getValue();
            }
            return entry.getKey() + "=" + entry.getValue();
        }).collect(Collectors.joining("&"));
        
        return String.format("%s%s?%s", API_PATH, path, str);
    }
 
    /**
     * Take the sort order from metadata and add it to parameters for use with
     * request.  Encoding field names and joining fields with comma is required
     * due to ARS 9 api behavior.  Encoded commas between field names breaks api 
     * requests. 
     * 
     * @param order
     * @param parameters
     * @return
     * @throws BridgeError 
     */
    protected void addSort(String order, 
        Map<String, String> parameters) throws BridgeError {
        
        LinkedHashMap<String,String> sortOrderItems = getSortOrderItems(
            BridgeUtils.parseOrder(order));
        String str = sortOrderItems.entrySet().stream().map(entry -> {
            String key = "";
            try {
                key = URLEncoder.encode(entry.getKey().trim(), "UTF-8");
            }   catch (UnsupportedEncodingException e) {
                LOGGER.error("Error encoding sort order for field: " 
                    + entry.getKey() + " ", e);
                return "";
            }
            return key + "." + entry.getValue().toLowerCase();

        }).collect(Collectors.joining(","));
        
        parameters.put("sort", str);
    }
    
    /**************************** Path Definitions ****************************/
    /**
     * Build the path for the Deals structure.
     * 
     * @param structureList
     * @param parameters
     * @return 
     * @throws com.kineticdata.bridgehub.adapter.BridgeError 
     */
    protected static String pathEntry(List<String> structureList,
        Map<String, String> parameters) throws BridgeError {

        if (!(structureList.size() > 1)) {
            throw new BridgeError("The Entry structure requires a Form Name.");
        }
        
        String path = String.format("%s/%s","/entry", structureList.get(1));
        if (parameters.containsKey("entry_id")) {
            path = String.format("%s/%s", path, parameters.get("entry_id"));
            parameters.remove("entry_id");
        }

        return path;
    }
    
    /**
     * Build path for Adhoc structure.
     * 
     * @param structureList
     * @param parameters
     * @return
     * @throws BridgeError 
     */
    protected static String pathAdhoc(List<String> structureList, 
        Map<String, String> parameters) throws BridgeError {
        
        return parameters.get("adapterPath");
    }

    /**
     * Checks if a parameter exists in the parameters Map.
     * 
     * @param param
     * @param parameters
     * @param structureList
     * @throws BridgeError 
     */
    protected static void checkRequiredParamForStruct(String param,
        Map<String, String> parameters, List<String> structureList)
        throws BridgeError{
        
        if (!parameters.containsKey(param)) {
            String structure = String.join(" > ", structureList);
            throw new BridgeError(String.format("The %s structure requires %s"
                + "parameter.", structure, param));
        }
    }
}
