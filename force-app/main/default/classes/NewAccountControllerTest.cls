/**
* Test class for NewAccountController
* @author 	Ramiro Alvarez
* @date 	  11/11/2021
* @module   BR-4466
*/

@isTest
public class NewAccountControllerTest {

    @IsTest
    static void checkProfile() {
        Boolean checkProfile = NewAccountController.checkUserProfile();
        System.assertEquals(true, checkProfile);

    }
    
}