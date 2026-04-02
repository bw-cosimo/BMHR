public class ListToMultiSelectAction {

    public class Request {
        @InvocableVariable(label='List of Strings' required=true)
        public List<String> values;
    }

    public class Response {
        @InvocableVariable(label='Multi-Select String (Semi-colon separated)')
        public String multiSelectString;
    }

    @InvocableMethod(label='List to Multi-Select Picklist' description='Converts a List of Strings into a single semi-colon separated string for Multi-Select Picklist fields.')
    public static List<Response> convert(List<Request> requests) {
        List<Response> results = new List<Response>();

        for (Request req : requests) {
            Response res = new Response();
            
            if (req.values == null || req.values.isEmpty()) {
                res.multiSelectString = null;
            } else {
                res.multiSelectString = String.join(req.values, ';');
            }
            
            results.add(res);
        }
        return results;
    }
}