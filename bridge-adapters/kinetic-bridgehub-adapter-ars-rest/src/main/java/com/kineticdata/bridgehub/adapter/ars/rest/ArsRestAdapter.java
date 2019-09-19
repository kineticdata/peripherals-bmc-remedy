package com.kineticdata.bridgehub.adapter.ars.rest;

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
import org.apache.http.HttpEntity;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;
import org.apache.http.Consts;
import org.apache.http.HttpResponse;
import org.apache.http.NameValuePair;
import org.apache.http.client.HttpClient;
import org.apache.http.client.entity.UrlEncodedFormEntity;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.client.methods.HttpPost;
import org.apache.http.impl.client.CloseableHttpClient;
import org.apache.http.impl.client.HttpClients;
import org.apache.http.message.BasicNameValuePair;
import org.apache.http.util.EntityUtils;
import org.json.simple.JSONArray;
import org.json.simple.JSONObject;
import org.json.simple.JSONValue;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class ArsRestAdapter implements BridgeAdapter {
    /*----------------------------------------------------------------------------------------------
     * PROPERTIES
     *--------------------------------------------------------------------------------------------*/

    /** Defines the adapter display name */
    public static final String NAME = "Ars Rest Bridge";

    /** Defines the logger */
    protected static final Logger logger = LoggerFactory.getLogger(ArsRestAdapter.class);
    
    /** Adapter version constant. */
    public static String VERSION = "";
    /** Load the properties version from the version.properties file. */
    static {
        try {
            java.util.Properties properties = new java.util.Properties();
            properties.load(ArsRestAdapter.class.getResourceAsStream("/"+ArsRestAdapter.class.getName()+".version"));
            VERSION = properties.getProperty("version");
        } catch (IOException e) {
            logger.warn("Unable to load "+ArsRestAdapter.class.getName()+" version properties.", e);
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
        new ConfigurableProperty(Properties.PROPERTY_PASSWORD).setIsRequired(true).setIsSensitive(true),
        new ConfigurableProperty(Properties.PROPERTY_ORIGIN).setIsRequired(true)
            .setDescription("The scheme://hostname:port of the Ars Server")
    );

    // Local variables to store the property values in
    private String username;
    private String password;
    private String origin;
    private ArsRestQualificationParser parser;
    private String token;

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
        
        parser = new ArsRestQualificationParser();
        
        token = getToken();
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

    // Structures that are valid to use in the bridge. Used to check against
    // when a method is called to make sure that the Structure the user is
    // attempting to call is valid.
    public static final List<String> VALID_STRUCTURES = Arrays.asList(new String[] {
        "Entry"
    });

    /*---------------------------------------------------------------------------------------------
     * IMPLEMENTATION METHODS
     *-------------------------------------------------------------------------------------------*/

    @Override
    public Count count(BridgeRequest request) throws BridgeError {
        request.setQuery(substituteQueryParameters(request));
        
        // Log the access
        logger.trace("Counting records");
        logger.trace("  Structure: " + request.getStructure());
        logger.trace("  Query: " + request.getQuery());

        // Check if the inputted structure is valid
        if (!VALID_STRUCTURES.contains(request.getStructure())) {
            throw new BridgeError("Invalid Structure: '" + 
                request.getStructure() + "' is not a valid structure");
        }

        Map<String, String> parameters = parser.getParameters(request.getQuery());
        
        // Retrieve the objects based on the structure from the source
        String output = getResource(getUrl(request, parameters));
        logger.trace("Count Output: "+output);
        JSONObject object = parseResponse(output);
        
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
        request.setQuery(substituteQueryParameters(request));
        
        // Log the access
        logger.trace("Retrieving Kinetic Request CE Record");
        logger.trace("  Structure: " + request.getStructure());
        logger.trace("  Query: " + request.getQuery());
        logger.trace("  Fields: " + request.getFieldString());

        // Check if the inputted structure is valid
        if (!VALID_STRUCTURES.contains(request.getStructure())) {
            throw new BridgeError("Invalid Structure: '" + request.getStructure() + "' is not a valid structure");
        }

        Map<String, String> parameters = parser.getParameters(request.getQuery());
        
        // Retrieve the objects based on the structure from the source
        String output = getResource(getUrl(request, parameters));
        logger.trace("Retrieve Output: "+output);
        JSONObject object = parseResponse(output);
        
        List<String> fields = request.getFields();
        if (fields == null) {
            fields = new ArrayList();
        }
        
        // Get domain specific data.
        JSONObject obj = (JSONObject)(object).get("values");
        JSONArray entries = (JSONArray)object.get("entries");
        
        Record record = new Record();
        if (obj != null) {
            // Set object to user defined fields
            Set<Object> removeKeySet = buildKeySet(fields, obj);
            obj.keySet().removeAll(removeKeySet);

            // Create a Record object from the responce JSONObject
            record = new Record(obj);
        } else if (entries != null) {
            // Throw error is multiple results found.
            // TODO: consider using mapper for single/multiple similar to kinetic
            // core
            if (entries.size() > 1) {
                throw new BridgeError ("Retrieve must return a single result."
                    + " Multiple results found.");
            } else if (entries.size() == 1){
                obj = (JSONObject)entries.get(0);
                
                Set<Object> removeKeySet = buildKeySet(fields, obj);
                obj.keySet().removeAll(removeKeySet);

                record = new Record(obj);
            }
        } else {
            throw new BridgeError ("An unexpected error has occured.");
        }

        // Return the created Record object
        return record;
    }

    @Override
    public RecordList search(BridgeRequest request) throws BridgeError {
        request.setQuery(substituteQueryParameters(request));
        
        // Log the access
        logger.trace("Searching Records");
        logger.trace("  Structure: " + request.getStructure());
        logger.trace("  Query: " + request.getQuery());
        logger.trace("  Fields: " + request.getFieldString());

        // Check if the inputted structure is valid
        if (!VALID_STRUCTURES.contains(request.getStructure())) {
            throw new BridgeError("Invalid Structure: '" + request.getStructure() + "' is not a valid structure");
        }

        Map<String, String> parameters = parser.getParameters(request.getQuery());
        Map<String, String> metadata = request.getMetadata() != null ?
                request.getMetadata() : new HashMap<>();
     
        addLimit(parameters);
        // Add a sorting order to be used with the request if order was defined,
        // but sort was not included in the qualification mapping.        
        if (metadata.get("order") != null && !parameters.containsKey("sort")) {
            addSort(metadata.get("order"), parameters);
        }
        // If offest exists in metadata add it to the parameters for use with 
        // reqeust.  
        if (metadata.get("offset") != null) {
            // Offset in parameters takes precedence.
            parameters.putIfAbsent("offset", metadata.get("offset"));
        }
        // clear metadata object to be repopulated for response.
        metadata.clear();
        
        // Retrieve the objects based on the structure from the source
        String output = getResource(getUrl(request, parameters));
        logger.trace("Search Output: " + output);
        JSONObject object = parseResponse(output);

        // Get domain specific data.
        JSONArray entries = (JSONArray)object.get("entries");

        // Create a List of records that will be used to make a RecordList object
        List<Record> recordList = new ArrayList<Record>();

        // If the user doesn't enter any values for fields we return all of the fields
        List<String> fields = request.getFields();
        if (fields == null) {
            fields = new ArrayList();
        }
        
        if(entries.isEmpty() != true){
            JSONObject firstObj = (JSONObject)entries.get(0);

            // Get domain specific data.
            JSONObject entry = (JSONObject)(firstObj).get("values");
            // Set object to user defined fields
            Set<Object> removeKeySet = buildKeySet(fields, entry);

            // Iterate through the responce objects and make a new Record for each.
            for (Object o : entries) {
                entry = (JSONObject)((JSONObject)o).get("values");

                entry.keySet().removeAll(removeKeySet);
        
                Record record;
                if (object != null) {
                    record = new Record(entry);
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
    private JSONObject parseResponse(String output) throws BridgeError{
                
        JSONObject object = new JSONObject();
        try {
            // Parse the response string into a JSONObject
            object = (JSONObject)JSONValue.parse(output);
        } catch (ClassCastException e){
            JSONArray error = (JSONArray)JSONValue.parse(output);
            throw new BridgeError("Error caught in retrieve: "
                + ((JSONObject)error.get(0)).get("messageText"));
        } catch (Exception e) {
            throw new BridgeError("An unexpected error has occured " + e);
        }
        
        return object;
    }
    
    // Set the offset that will be used in subsequent requests for pagination
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
            logger.error("Error parsing int: " + e);
        }
    }
    
    // Set limit if none exists or ensure that limit is in acceptable range.
    // TODO: consider if limit is on metadata.
    protected void addLimit(Map<String, String> parameters) {
        int limit = 1000;
        try {
            if (parameters.containsKey("limit")) {
                limit = Integer.parseInt(parameters.get("limit").trim());
                if (limit < 0 || limit > 1000) {
                    limit = 1000;
                    logger.debug("limit was outside standard values. Limit set "
                        + "to 1000 default.");
                }
                parameters.replace("limit", Integer.toString(limit));
            } else {
                parameters.put("limit", "1000");
            }
        } catch (NumberFormatException e) {
            logger.error("limit parmaeter must be a number.  limit set to 1000 "
                + "default. " + e);
        }
    }
    
    // Take the sort order from metadata and add it to parameters for use with
    // request.  Encoding field names and joining fields with comma is required
    // due to ARS 9 api behavior.  Encoded commas between field namesbreaks api 
    // requests. 
    protected void addSort(String order, 
        Map<String, String> parameters) throws BridgeError {
        
        LinkedHashMap<String,String> sortOrderItems = getSortOrderItems(
                BridgeUtils.parseOrder(order));
            String str = sortOrderItems.entrySet().stream().map(entry -> {
                String key = "";
                try {
                    key = URLEncoder.encode(entry.getKey().trim(), "UTF-8");
                }   catch (UnsupportedEncodingException e) {
                    logger.error("Error encoding sort order for field: " 
                        + entry.getKey() + " " + e);
                    return "";
                }
                return key + "." + entry.getValue().toLowerCase();


            }).collect(Collectors.joining(","));
            parameters.put("sort", str);
    }
    
    // Create a set of keys to remove from object prior to creating Record.
    // TODO: consider using fields(foo,bar) to only request required feilds from
    // api.  This would eliminate the need to manipulate return objects
    protected Set<Object> buildKeySet(List<String> fields, JSONObject obj) {
        if(fields.isEmpty()){
            fields.addAll(obj.keySet());
        }
            
        // If specific fields were specified then we remove all of the 
        // nonspecified properties from the object.
        Set<Object> removeKeySet = new HashSet<Object>();
        for(Object key: obj.keySet()){
            if(fields.contains(key)){
                continue;
            }else{
                logger.trace("Remove Key: "+key);
                removeKeySet.add(key);
            }
        }
        return removeKeySet;
    }
    
    // Build url for request.  Encode all parameters except the sort parameter.
    // The encoding for sort is done in the addSort method.  Read comment for 
    // explanation.
    protected String getUrl (BridgeRequest request, Map<String, String> parameters) {
                
        String str = parameters.entrySet().stream().map(entry -> {
            if (!entry.getKey().equals("sort")) {
                try {
                    return entry.getKey() + "=" 
                        + URLEncoder.encode(entry.getValue(), "UTF-8");
                } catch (UnsupportedEncodingException e) {
                    logger.error("Error encoding query parameter: " + e);
                }
                return entry.getKey() + "=" + entry.getValue();
            }
            return entry.getKey() + "=" + entry.getValue();
        }).collect(Collectors.joining("&"));
        
        return String.format("%s/api/arsys/v1/%s?%s", origin, 
            parser.parsePath(request.getQuery()), str);
    }
    
    private String getResource(String url) throws BridgeError {
        return getResource(url, 0);
    }
    
    // Count Search and Retrieve get the resoucre the same and use the same output object.
    private String getResource(String url, int count) throws BridgeError {
        String output = "";
        
        try (
            CloseableHttpClient client = HttpClients.createDefault()
        ) {
            HttpResponse response;
            HttpGet get = new HttpGet(url);  
            
            get.setHeader("Authorization", "AR-JWT " + token);
            get.setHeader("Content-Type", "application/json");
            get.setHeader("Accept", "application/json");
            
            // Make the call to the source to retrieve data and convert the response
            // from a HttpEntity object into a Java String
            response = client.execute(get);
            HttpEntity entity = response.getEntity();
            output = EntityUtils.toString(entity);
            int responseCode = response.getStatusLine().getStatusCode();
            logger.trace("Request response code: " + responseCode);
            if(responseCode == 404){
                throw new BridgeError("404 Page not found at "+url+".");
            }else if(responseCode == 401){
                // If token has expired get fresh token
                // TODO: Find way to test this code.
                getToken();
                // If count is greater than 2 assume that bad credentials were
                // provided.
                if (count < 2) {
                    getResource(url, count + 1);
                } else {
                    throw new BridgeError("401 unauthorized access");
                }
            }
            
        } catch (IOException e) {
            logger.error("An unexpected IO exception was encountered calling the"
                + " core API.", e);
            throw new BridgeError(
                "Unable to make a connection to the ARS server.");
        }

        return output;
    }
    
    // Get a JWT to be used with subsequent requests.
    private String getToken () throws BridgeError {
         String url = origin + "/api/jwt/login";
        
        // Initialize the HTTP Client, Response, and Get objects.
        HttpClient client = HttpClients.createDefault();
        HttpResponse response;
        HttpPost httpPost = new HttpPost(url);

        // Create entity with username and pass for use in the Post.
        List<NameValuePair> form = new ArrayList<>();
        form.add(new BasicNameValuePair("username", username));
        form.add(new BasicNameValuePair("password", password));
        UrlEncodedFormEntity requestEntity = new UrlEncodedFormEntity(form, Consts.UTF_8);
        
        httpPost.setEntity(requestEntity);
        httpPost.setHeader("Content-Type", "application/x-www-form-urlencoded");
            
        // Make the call to the REST source to retrieve data and convert the 
        // response from an HttpEntity object into a Java string so more response
        // parsing can be done.
        String token = "";
        try {
            response = client.execute(httpPost);
            HttpEntity entity = response.getEntity();
            token = EntityUtils.toString(entity);
        } catch (IOException e) {
            logger.error(e.getMessage());
            throw new BridgeError("Unable to make a connection to the REST"
                + " Service");
        }
        
        return token;
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
    
    private String substituteQueryParameters(BridgeRequest request) throws BridgeError {
        // Parse the query and exchange out any parameters with their parameter 
        // values. ie. change the query username=<%=parameter["Username"]%> to
        // username=test.user where parameter["Username"]=test.user
        ArsRestQualificationParser parser = new ArsRestQualificationParser();
        return parser.parse(request.getQuery(),request.getParameters());
    }
}
