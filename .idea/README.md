# NotificationsService - dreamolé '19
<p>A few versions of an emailing engine and a LWC email tracker specially cooked to be showcasted in the dreamolé '19.</p>
<p>NotificationsService cares about:</p>

- Composing Salesforce email objects aiming clarity and flexibility.
- Sending such emails avoiding boilerplate code in the clients of the service.
- Tracking emails even when Salesforce doesn't do it for us.

Lightning Web Components included:

- EmailMessages: a table listing the EmailMessage records. When one message gets selected, an event is fired containing the Id of the record.
- emailmessagedetails: listens to the events fired by the emailMessages component. When received it shows the content of the selected message.
- pubsub: a copy of the [publish/subscribe library](https://github.com/trailheadapps/lwc-recipes/tree/master/force-app/main/default/lwc/pubsub) from the Salesforce's [lwc-receipes](https://github.com/trailheadapps/lwc-recipes) repository. Provides a mechanism for sibling component communication (components in a Lightning App Builder page). 

## NotificationsServiceV1
The simplest version of the engine where you'll find how we have approached the goal of building and sending emails by paying special attention to the  clarity of the code.

## NotificationsServiceV1_1
Adds the tracking feature for single emails. This has been specially made to show how the Clarity Driven Development approach would naturally drive us to the full send/track solution. Note that it is **not bulkified**. If you're planning to import the NotificationsService on any project, consider using the V2 instead.

## NotificationsServiceV2
Includes bulkification to send multiple emails at once without additional DMLs or SOQL queries cost. We encourage you to have a look to the previous versions to get the Clarity Driven Development spirit.