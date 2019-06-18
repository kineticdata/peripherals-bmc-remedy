package testing.kineticdata.filehub.adapters.ars;

import com.bmc.arsys.api.ARServerUser;
import com.bmc.arsys.api.Constants;
import com.kineticdata.filehub.adapters.ars.ArsFilestoreAdapter;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Properties;
import org.junit.BeforeClass;

public class ArsTestBase {
    
    private static Boolean setupComplete = false;
    private static Exception setupException;

    protected static Properties properties;
    protected static ARServerUser user;

    /*----------------------------------------------------------------------------------------------
     * BEFORE/AFTER METHODS
     *--------------------------------------------------------------------------------------------*/
    
    /**
     * Once per JVM execution, validate that the test-config file is present and import the
     * KTEST_FilehubArsAdapter_AttachmentForm.def file to ensure the form is available for testing.
     * 
     * @throws Exception 
     */
    @BeforeClass
    public static void beforeAll_Base() throws Exception {
        // If this is the first time executing setup
        if (!setupComplete) {
            // Attempt to perform setup
            try {
                // Check that the configuration file exists
                Path path = Paths.get(
                    System.getProperty("user.home"), 
                    ".test-config", 
                    "kinetic-filehub-adapter-ars.properties");
                if (!Files.exists(path)) {
                    throw new FileNotFoundException("Expected configuration file at "+path.toString()+
                        " with the following contents: \nserver: SERVER\nport: PORT\n"+
                        "username: USERNAME\npassword: PASSWORD");
                }
                // Attempt to read the properties file
                properties = new Properties();
                properties.load(new FileInputStream(path.toFile()));
                // Initialize the user
                user = new ARServerUser();
                user.setServer(properties.getProperty(ArsFilestoreAdapter.Properties.SERVER));
                user.setPort(Integer.valueOf(properties.getProperty(ArsFilestoreAdapter.Properties.PORT)));
                user.setUser(properties.getProperty(ArsFilestoreAdapter.Properties.USERNAME));
                user.setPassword(properties.getProperty(ArsFilestoreAdapter.Properties.PASSWORD));
                // Install/Overwrite the test form
                String file = Paths.get("src/test/resources/KTEST_FilehubArsAdapter_AttachmentForm.def")
                    .normalize().toAbsolutePath().toString();
                user.importDefFromFile(file, Constants.AR_IMPORT_OPT_OVERWRITE);
                
            }
            // If there was a problem performing the setup
            catch (Exception e) {
                // Store the exception
                setupException = e;
            }
            // Ensure we only execute setup one time, regardless of whether it was successful
            finally {
                // Mark the setup as complete
                setupComplete = true;
            }
        }
        
        // If there was a setup exeption
        if (setupException != null) {
            // Re-raise the exception
            throw setupException;
        }
    }
    
}
