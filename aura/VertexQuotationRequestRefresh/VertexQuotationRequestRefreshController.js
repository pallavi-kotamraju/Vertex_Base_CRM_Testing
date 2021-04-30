({
    Cancel: function() {
        $A.get("e.force:closeQuickAction").fire();
    },
    
    Refresh: function(component, event, helper) {
        console.log('===Refresh===');
        
        //  Show the spinner, hide the buttons
        var refreshSpinner = component.find("refreshSpinner");
        var refreshButton = component.find("refreshButton");
        $A.util.toggleClass(refreshSpinner, "slds-hide");
        $A.util.toggleClass(refreshButton, "slds-show");
        
        //  Call controller method w/ this record's Id to queue up a refresh
        var action = component.get("c.RequestRefresh");
        action.setParams({
            parentId: component.get("v.recordId")
        });
        
        //  Upon completion of apex work, handle response; good or bad
        action.setCallback(this, function(response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                
                //  All good, hide the spinner, close the modal
                $A.util.toggleClass(refreshSpinner, "slds-hide");
                $A.get("e.force:closeQuickAction").fire()
                
            } else if (state === "INCOMPLETE") {
                // Show error?
            } else if (state === "ERROR") {
                var errors = response.getError();
                if (errors) {
                    if (errors[0] && errors[0].message) {
                        console.log("Error message: " + errors[0].message);
                    }
                } else {
                    console.log("Unknown error");
                }
            }
        });
        
        // Queue up the apex work
        $A.enqueueAction(action);
    }
})