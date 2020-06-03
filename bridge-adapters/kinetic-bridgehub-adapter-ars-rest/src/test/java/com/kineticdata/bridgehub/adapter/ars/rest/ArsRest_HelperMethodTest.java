/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package com.kineticdata.bridgehub.adapter.ars.rest;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;
import org.junit.Test;

/**
 *
 * @author chadrehm
 */
public class ArsRest_HelperMethodTest {
    @Test
    public void test_get_url() {
        ArsRestQualificationParser helper = new ArsRestQualificationParser();
        
        String path = helper.parsePath("entry/HPD:Help Desk");
        assertEquals("entry/HPD:Help%20Desk", path);
    }
}
