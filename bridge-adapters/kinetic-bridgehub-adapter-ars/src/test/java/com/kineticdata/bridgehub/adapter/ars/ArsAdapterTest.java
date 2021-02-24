package com.kineticdata.bridgehub.adapter.ars;

import com.kineticdata.bridgehub.adapter.BridgeAdapter;
import com.kineticdata.bridgehub.adapter.BridgeAdapterTestBase;
import com.kineticdata.bridgehub.adapter.BridgeError;
import com.kineticdata.bridgehub.adapter.BridgeRequest;
import com.kineticdata.bridgehub.adapter.Count;
import com.kineticdata.bridgehub.adapter.RecordList;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.Map;
import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertNull;
import org.junit.Test;

/**
 *
 */
public class ArsAdapterTest extends BridgeAdapterTestBase {

    @Override
    public String getConfigFilePath() {
        return "src/test/resources/bridge-config.yml";
    }
    
    @Override
    public Class getAdapterClass() {
        return ArsAdapter.class;
    }
    
    @Test
    public void test_invalidBridgeConfiguration() {
        BridgeError error = null;
        
        Map<String,String> invalidConfiguration = new LinkedHashMap<String,String>();
        invalidConfiguration.put("Username", "aUsername");
        invalidConfiguration.put("Password", "super-secret-password");
        invalidConfiguration.put("Server","emu.kineticdata.com");
        invalidConfiguration.put("Port","3000");
        invalidConfiguration.put("Progum","0");
        
        BridgeRequest request = new BridgeRequest();
        request.setStructure(getStructure());
        request.setQuery(getSingleValueQuery());
        
        BridgeAdapter adapter = new ArsAdapter();
        adapter.setProperties(invalidConfiguration);
        
        Count count = null;
        try {
            adapter.initialize();
            count = adapter.count(request);
        } catch (BridgeError e) {
            error = e;
        }
        
        assertNull(error);
        assertEquals(0,count.getValue().intValue());
    }
    
    // Override the invalidStructure test from the TestBase because it is
    // expecting a BridgeError, and the ArsAdapter throws a RuntimeException
    @Override
    @Test
    public void test_invalidStructure() {
        RuntimeException error = null;
        
        BridgeRequest request = new BridgeRequest();
        request.setStructure("Blank Test Structure");
        request.setFields(getFields());
        request.setQuery(getSingleValueQuery());
        
        try {
            getAdapter().search(request);
        } catch (RuntimeException e) {
            error = e;
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
        
        assertNotNull(error);
    }
    
//    @Test
//    public void test_invalidField() {
//        BridgeError error = null;
//        
//        List<String> invalidFields = new ArrayList<>();
//        UUID randomField = UUID.randomUUID();
//        invalidFields.add(randomField.toString());
//        
//        BridgeRequest request = new BridgeRequest();
//        request.setStructure(getStructure());
//        request.setFields(invalidFields);
//        request.setQuery(getSingleValueQuery());
//        
//        Record record = null;
//        try {
//            record = getAdapter().retrieve(request);
//        } catch (BridgeError e) { error = e; }
//        
//        assertNull(error);
//        assertNull(record.getRecord().get(randomField.toString()));
//    }
//
//    @Test
//    public void test_blankFields() {
//        BridgeError error = null;
//        
//        BridgeRequest request = new BridgeRequest();
//        request.setStructure(getStructure());
//        request.setFields(new ArrayList());
//        request.setQuery(getSingleValueQuery());
//        
//        try {
//            getAdapter().retrieve(request);
//        } catch (BridgeError e) { error = e; }
//        
//        assertNull(error);
//    }

    @Test
    public void test_search_exception() {
        RuntimeException error = null;
        
        BridgeRequest request = new BridgeRequest();
        request.setStructure("AATest");
        request.setFields(new ArrayList<String>(){{ 
            add("1000 Characters"); 
            add("10000 Characters");
            add("1001 Characters");
            add("256 Characters");
            add("Short Description");
        }});
        request.setQuery("1=1");
        
        RecordList rl = null;
        try {
            rl = getAdapter().search(request);
        } catch (RuntimeException e) {
            error = e;
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
        
        assertNull(error);
    }
}
