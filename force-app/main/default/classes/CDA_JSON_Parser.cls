public class CDA_JSON_Parser {

    public List<AssociatedEmails> associatedEmails;    
    
    public class AssociatedEmails {
        public Integer personId;
        public String firstName;
        public String lastName;
        public String email;
        public Set<String> roles;
    }
    
    public static CDA_JSON_Parser parse(String json) {
        return (CDA_JSON_Parser) System.JSON.deserialize(json, CDA_JSON_Parser.class);
    }    
}