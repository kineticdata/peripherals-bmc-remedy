/*
 * This class is intened to become generic so that many agent adapters can leverage
 * the same functionality.  
 */
package com.kineticdata.bridgehub.adapter.ars.rest;

import com.kineticdata.bridgehub.adapter.BridgeError;
import java.util.List;
import java.util.Map;

/**
 * This class defines valid Structures.
 * Properties:
 *  String structure - Name of the data model.
 *  PathBuilder pathBuilder - URL path to asset.  Defined in child class.
 */
public class AdapterMapping {
    private final String structure;
    private final PathBuilder pathbuilder;
    
    public AdapterMapping(String structure, PathBuilder pathbuilder){
        
        this.structure = structure;
        this.pathbuilder = pathbuilder;
    }
    
    /**
     * Interfaces for mappings.
     */
    @FunctionalInterface
    public static interface PathBuilder {
        String apply(List<String> structureList, Map<String, String> parameters) 
           throws BridgeError;
    }

    /**
     * @return the structure
     */
    public String getStructure() {
        return structure;
    }

    /**
     * @return the pathbuilder
     */
    public PathBuilder getPathbuilder() {
        return pathbuilder;
    }
}
