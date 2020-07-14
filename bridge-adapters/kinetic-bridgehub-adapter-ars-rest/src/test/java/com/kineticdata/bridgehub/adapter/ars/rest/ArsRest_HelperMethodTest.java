/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package com.kineticdata.bridgehub.adapter.ars.rest;

import com.kineticdata.bridgehub.adapter.BridgeError;
import java.util.HashMap;
import java.util.Map;
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
        ArsRestQualificationParser helper = new ArsRestQualificationParser();
        
        String path = helper.parsePath("entry/HPD:Help Desk");
        assertEquals("entry/HPD:Help%20Desk", path);
    }
    
    @Test
    public void test_getParameters() throws BridgeError {
        ArsRestAdapter helper = new ArsRestAdapter();
        
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
    public void test_getMapping_error() throws BridgeError {
        BridgeError error = null;
        ArsRestAdapter helper = new ArsRestAdapter();
        
        try {
            helper.getMapping("Foo");
        } catch (BridgeError e) {
            error = e;
        }
                
        assertNotNull(error);
    }
}
