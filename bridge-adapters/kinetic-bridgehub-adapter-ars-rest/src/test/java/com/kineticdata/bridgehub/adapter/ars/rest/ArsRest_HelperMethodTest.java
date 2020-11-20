/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package com.kineticdata.bridgehub.adapter.ars.rest;

import com.jayway.jsonpath.JsonPathException;
import com.kineticdata.bridgehub.adapter.BridgeError;
import com.kineticdata.bridgehub.adapter.Record;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.json.simple.JSONObject;
import org.json.simple.JSONValue;
import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertTrue;
import org.junit.Test;

/**
 *
 * @author chadrehm
 */
public class ArsRest_HelperMethodTest {
    @Test
    public void test_space_encode() {
        ArsRestV2QualificationParser helper = new ArsRestV2QualificationParser();
        
        String path = helper.parsePath("entry/HPD:Help Desk");
        assertEquals("entry/HPD:Help%20Desk", path);
    }
    
    @Test
    public void test_get_parameters() throws BridgeError {
        ArsRestV2Adapter helper = new ArsRestV2Adapter();
        
        AdapterMapping mapping = helper.getMapping("Entry");
        
        Map<String, String> parameters = 
            helper.getParameters("foo=bar&fizz=buzz", mapping);
        
        Map<String, String> parametersControl = new HashMap<String, String>() {{
            put("foo","bar");
            put("fizz","buzz");
        }};
        
        assertTrue(parameters.equals(parametersControl));
        
        mapping = helper.getMapping("Adhoc");
        
        parameters = helper.getParameters("_noOp_?foo=bar&fizz=buzz", mapping);
        
        parametersControl.put("adapterPath", "_noOp_");
        
        assertTrue(parameters.equals(parametersControl));
    }
    
    @Test
    public void test_get_mapping_error() throws BridgeError {
        BridgeError error = null;
        ArsRestV2Adapter helper = new ArsRestV2Adapter();
        
        try {
            helper.getMapping("Foo");
        } catch (BridgeError e) {
            error = e;
        }
                
        assertNotNull(error);
    }
    
    @Test
    public void test_build_record() {
        ArsRestV2Adapter helper = new ArsRestV2Adapter();
        
        List<String> list = new ArrayList();
        list.add("$['Hourly Rate'].currency");
        list.add("First Name");
        
        String jsonString = "{\"First Name\": \"Foo\", \"Hourly Rate\": {\"decimal\": 0.00,\"currency\":"
            + " \"USD\", \"conversionDate\": \"1970-01-01T00:00:00.000+0000\","
            + " \"functionalValues\": { \"USD\": 0.00, \"GBP\": null, \"EUR\": null,"
            + " \"JPY\": null,\"CAD\": null }}}";
        JSONObject jsonobj = (JSONObject)JSONValue.parse(jsonString);
        
        Record record = helper.buildRecord(list, jsonobj);
        
        JSONObject recordControl = new JSONObject();
        recordControl.put("$['Hourly Rate'].currency", "USD");
        recordControl.put("First Name", "Foo");
        
        assertTrue(record.getRecord().equals(recordControl));
        
        list.add("$[Hourly Rate].currenty");
        
        JsonPathException error = null;
        try {
            helper.buildRecord(list, jsonobj);
        } catch (JsonPathException e) {
            error = e;
        }
        
        assertNotNull(error);
    }
}
