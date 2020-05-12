/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package com.kineticdata.bridgehub.adapter.ars.rest;

import com.kineticdata.bridgehub.adapter.BridgeError;
import static com.kineticdata.bridgehub.adapter.ars.rest.ArsRestAdapter.logger;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import org.apache.http.Consts;
import org.apache.http.HttpEntity;
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

public class ArsRestApiHelper {
    private static final Logger LOGGER = 
        LoggerFactory.getLogger(ArsRestApiHelper.class);
    
    private final String origin;
    private final String username;
    private final String password;
    private String token;
    
    public ArsRestApiHelper(String origin, String username, String password) {
        
        this.origin = origin;
        this.username = username;
        this.password = password;
    } 
    
    public JSONObject executeRequest (String url) throws BridgeError{
        return executeRequest (url, 0);
    }
    
    public JSONObject executeRequest (String url, int count) 
        throws BridgeError{
        
        JSONObject output;      
        // System time used to measure the request/response time
        long start = System.currentTimeMillis();
        
        try (
            CloseableHttpClient client = HttpClients.createDefault()
        ) {
            HttpResponse response;
            HttpGet get = new HttpGet(url);

            get.setHeader("Authorization", "AR-JWT " + token);
            get.setHeader("Content-Type", "application/json");
            get.setHeader("Accept", "application/json");
            
            response = client.execute(get);
            LOGGER.debug("Recieved response from \"{}\" in {}ms.",
                url,
                System.currentTimeMillis()-start);

            int responseCode = response.getStatusLine().getStatusCode();
            LOGGER.trace("Request response code: " + responseCode);
            
            HttpEntity entity = response.getEntity();
            
            // Confirm that response is a JSON object
            output = parseResponse(EntityUtils.toString(entity));
            
            if(responseCode == 401){
                LOGGER.debug("401 recieved attempting to get new token.");
                // If token has expired get fresh token
                getToken();
                // If count is greater than 2 stop token retry attempts.
                if (count < 2) {
                    output = executeRequest(url, count + 1);
                } else {
                    throw new BridgeError(count + " attempts were made to get a"
                        + "new token without success.");
                }
            }
            // Handle all other faild repsonses
            if (responseCode >= 400 && responseCode != 401) {
                handleFailedReqeust(responseCode);
            } 
        }
        catch (IOException e) {
            throw new BridgeError("Unable to make a connection to the REST"
                + " Service", e);
        }
        
        return output;
    }
    
    // Get a JWT to be used with subsequent requests.
    public void getToken () throws BridgeError {
        String url = origin + "/api/jwt/login";
        
        try (
            CloseableHttpClient client = HttpClients.createDefault()
        ) {
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
            response = client.execute(httpPost);
            HttpEntity entity = response.getEntity();
            
            int responseCode = response.getStatusLine().getStatusCode();
            if (responseCode >= 400) {
                handleFailedReqeust(responseCode);
            }

            token = EntityUtils.toString(entity);
            
        } catch (IOException e) {
            throw new BridgeError("Unable to make a connection to the REST"
                + " Service", e);
        }
    }
    
    private void handleFailedReqeust (int responseCode) throws BridgeError {
        switch (responseCode) {
            case 400:
                throw new BridgeError("400: Bad Reqeust");
            case 401:
                throw new BridgeError("401: Unauthorized");
            case 404:
                throw new BridgeError("404: Page not found");
            case 405:
                throw new BridgeError("405: Method Not Allowed");
            case 500:
                throw new BridgeError("500 Internal Server Error");
            default:
                throw new BridgeError("Unexpected response from server");
        }
    }
        
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
}
