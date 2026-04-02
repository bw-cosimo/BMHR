public class MultiSelectToListAction {

    public class Request {
        @InvocableVariable(required=true)
        public String multiSelectValues;
    }

    public class Response {
        @InvocableVariable
        public List<String> values;
    }

    @InvocableMethod(label='Multi-Select Picklist to List' description='Converts a multi-select picklist value string into a List<String>')
    public static List<Response> convert(List<Request> requests) {
        List<Response> results = new List<Response>();

        for (Request req : requests) {
            Response res = new Response();
            if (String.isBlank(req.multiSelectValues)) {
                res.values = new List<String>();
            } else {
                res.values = req.multiSelectValues.split(';');
            }
            results.add(res);
        }
        return results;
    }
}