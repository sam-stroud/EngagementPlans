@SuppressWarnings('PMD.AvoidGlobalModifier')
/*
Action Plans v4
David Schach 2022
https://appexchange.salesforce.com/appxListingDetail?listingId=a0N4V00000Gg6NVUAZ

Action Plans v3
Force.com Labs 2011
http://appexchange.salesforce.com/listingDetail?listingId=a0N30000003HcINEA0

Copyright (c) 2022, salesforce.com, inc.
All rights reserved.
SPDX-License-Identifier: BSD-3-Clause
For full license text, see the LICENSE file in the repo root or https://opensource.org/licenses/BSD-3-Clause
*/
/**
 * Trigger Handler class to manage all triggers. Methods for managed objects are here, as well as a method that any other object can use to enable it to be linked to Action Plans.
 * @author {@link [David Schach](https://github.com/dschach)}
 * @since 2022
 * @group Trigger Handlers
 */
global without sharing class ActionPlansTriggerHandlers {
	/**
	 * Use only when we want to delete a Task while preserving the APTask (such as when making an APTask newly-dependent on another)<br>
	 * Unused currently, but may be used in future version
	 * @author David Schach
	 * @return   `Boolean` Should we bypass the trigger?
	 */
	private static Boolean bypassTaskTrigger = false;

	/**
	 * Global so that if in managed package, this method is the only one available
	 * @author {@link [David Schach](https://github.com/dschach)}
	 * @param  sObjectName the name of the sObject
	 * @see ActionPlansTriggerHandlers.actionPlansSObjectTriggerHandler[1]
	 */
	global static void actionPlansSObjectTriggerHandler(String sObjectName) {
		actionPlansSObjectTriggerHandler(Trigger.new, Trigger.old, Trigger.newMap, Trigger.oldMap, Trigger.operationType, sObjectName);
	}

	/**
	 * Handle SObjects with related Action Plans when those sObject records are deleted and undeleted
	 * @author {@link [David Schach](https://github.com/dschach)}
	 * @param  newRecords    Trigger.new
	 * @param  oldRecords    Trigger.old
	 * @param  newRecordsMap Trigger.newMap
	 * @param  oldRecordsMap Trigger.oldMap
	 * @param  triggerEvent  Trigger context
	 * @param  sObjectName   the name of the SObject
	 * @see ActionPlansTriggerHandlers.actionPlansSObjectTriggerHandler[0]
	 */
	// prettier-ignore
	public static void actionPlansSObjectTriggerHandler(List<SObject> newRecords, List<SObject> oldRecords, Map<Id, SObject> newRecordsMap, Map<Id, SObject> oldRecordsMap, System.TriggerOperation triggerEvent, String sObjectName) {
		

		String relationshipName = null;

		switch on triggerEvent {
			when BEFORE_DELETE {
				relationshipName = getRelationshipName((Id) oldRecordsMap.values()[0].get('Id'));
			}
			when AFTER_UNDELETE {
				relationshipName = getRelationshipName((Id) newRecordsMap.values()[0].get('Id'));
			}
			when else {
				return;
			}
		}
		// prettier-ignore
		if (relationshipName == null) { return; }

		//Delete related action plans
		switch on triggerEvent {
			when BEFORE_DELETE {
				Set<Id> apIds = new Set<Id>();

				// Query Action Plans to delete in recycle bin
				String deleteQueryString = 'SELECT Id, Name FROM ActionPlan__c WHERE ' + relationshipName + ' IN :oldRecords AND isDeleted = true ALL ROWS';
				List<ActionPlan__c> deletePermenantlyAps = Database.query(String.escapeSingleQuotes(deleteQueryString));

				if (!deletePermenantlyAps.isEmpty()) {
					Database.emptyRecycleBin(deletePermenantlyAps);
				}

				// Delete regular Action Plans associated with this object
				deleteQueryString = 'SELECT Id FROM ActionPlan__c WHERE ' + relationshipName + ' IN :oldRecords AND IsDeleted = false';
				List<ActionPlan__c> apList = Database.query(String.escapeSingleQuotes(deleteQueryString));
				for (ActionPlan__c ap : apList) {
					apIds.add(ap.Id);
				}

				if (!apIds.isEmpty()) {
					if(forceSynchronous()){
						deleteActionPlans(apIds);
					} else {
						futureDeleteActionPlans(apIds);
					}
				}
			}
			//Undelete related action plans
			when AFTER_UNDELETE {
				String afterUndeleteQuery = 'SELECT Id FROM ActionPlan__c WHERE ' + relationshipName + ' IN :newRecords ALL ROWS';
				List<ActionPlan__c> aPs = Database.query(String.escapeSingleQuotes(afterUndeleteQuery));

				try {
					if (ActionPlansTestUtilities.forceError) {
						insert new Contact();
					}
					Database.undelete(aPs, false);
				} catch (Dmlexception e) {
					for (SObject c : newRecords) {
						c.addError(System.Label.ap_RelObjUndeleteError);
					}
				}
			}
		}
	}
	/**
	 * Actions to take on ActionPlan DML
	 * @author {@link [David Schach](https://github.com/dschach)}
	 * @param  newRecords    Trigger.new
	 * @param  oldRecords    Trigger.old
	 * @param  newRecordsMap Trigger.newMap
	 * @param  oldRecordsMap Trigger.oldMap
	 * @param  triggerEvent  Trigger context
	 * @see ActionPlansTriggerHandlers.fillRelatedRecordFields
	 * @see ActionPlansTriggerHandlers.validateActionPlans
	 * @see ActionPlansTaskTriggerUtilities.deleteTasks
	 */
	// prettier-ignore
	public static void triggerhandlerActionPlan(List<ActionPlan__c> newRecords, List<ActionPlan__c> oldRecords, Map<Id, ActionPlan__c> newRecordsMap, Map<Id, ActionPlan__c> oldRecordsMap, System.TriggerOperation triggerEvent) {
		switch on triggerEvent {
			when BEFORE_INSERT {
				Id defaultTaskRTId = ActionPlansUtilities.getDefaultTaskRecordTypeId();

				Set<Id> aptemplates = new Set<Id>();
				for (ActionPlan__c ap : newRecords) {
					if (ap.Action_Plan_Template__c != null && ap.TaskRecordTypeID__c == null) {
						aptemplates.add(ap.Action_Plan_Template__c);
					} else if (ap.Action_Plan_Template__c == null && ap.TaskRecordTypeID__c == null) {
						ap.TaskRecordTypeID__c = defaultTaskRTId;
					}
				}
				if (!aptemplates.isEmpty()) {
					Map<Id, ActionPlanTemplate__c> templateMap = new Map<Id, ActionPlanTemplate__c>([SELECT Id, TaskRecordTypeID__c FROM ActionPlanTemplate__c WHERE Id IN :aptemplates]);

					for (ActionPlan__c ap : newRecords) {
						if (ap.TaskRecordTypeID__c == null || !(ap.TaskRecordTypeID__c instanceof Id)) {
							if (templateMap.containsKey(ap.Action_Plan_Template__c)) {
								ap.TaskRecordTypeID__c = templateMap.get(ap.Action_Plan_Template__c).TaskRecordTypeID__c;
							} else {
								ap.TaskRecordTypeID__c = defaultTaskRTId;
							}
						}
					}
				}
				fillRelatedRecordFields(newRecords);
				validateActionPlans(newRecords);
			}
			when BEFORE_UPDATE {
				fillRelatedRecordFields(newRecords);
				validateActionPlans(newRecords);
			}
			when AFTER_UPDATE {
				Set<Id> actionPlanNewNames = new Set<Id>();
				for (ActionPlan__c ap : newRecords) {
					if (ap.Name != oldRecordsMap.get(ap.Id).Name) {
						actionPlanNewNames.add(ap.Id);
					}
				}
				if (!actionPlanNewNames.isEmpty()) {
					List<APTask__c> templateTasks = [SELECT Id, Name FROM APTask__c WHERE Action_Plan__c IN :actionPlanNewNames];
					for (APTask__c a : templateTasks) {
						a.Name = null;
					}
					// no permissions check because trigger handler must run in system mode
					update templateTasks;
				}
			}
			//Execution when an Action Plan is deleted: delete all asociated Tasks
			when BEFORE_DELETE {
				
				Set<Id> apTaskIDs = new Set<Id>();
				if (!forceSynchronous()) {
					Set<Id> taskIds = new Set<Id>();
					// if action plan is deleted, delete all tasks associated with it
					// Collect all APTasks
					for (APTask__c apt : [SELECT Id FROM APTask__c WHERE Action_Plan__c IN :oldRecordsMap.keyset()]){
						apTaskIDs.add(apt.Id);
					}
					for (Task ap : [SELECT Id FROM Task WHERE IsClosed = FALSE AND TaskAPTask__c IN :apTaskIDs]) {
						taskIds.add(ap.Id);
					}
					delete [SELECT Id FROM Task WHERE IsClosed = FALSE AND Id IN :taskIds];
					// Run a future delete method
					//if (!taskIds.isEmpty()) {
					//ActionPlansTaskTriggerUtilities.futureDeleteTasks(taskIds);
					//}
					
				} else {
					for (APTask__c apt : [SELECT Id FROM APTask__c WHERE Action_Plan__c IN :oldRecordsMap.keyset()]){
						apTaskIDs.add(apt.Id);
					}
					// no permissions check because trigger handler must run in system mode
					delete [SELECT Id FROM Task WHERE IsClosed = FALSE AND TaskAPTask__c IN :apTaskIDs];
				}
			}
			when AFTER_UNDELETE {
				//get Id of all deleted Action Plan Task Templates
				Map<Id, APTask__c> mapAPTasks = new Map<Id, APTask__c>([SELECT Id, Action_Plan__c FROM APTask__c WHERE Action_Plan__c IN :newRecordsMap.keyset() ALL ROWS]);

				//get all tasks asociated to this APTasks
				List<Task> taskList = [SELECT Id, TaskAPTask__c, IsDeleted FROM Task WHERE TaskAPTask__c IN :mapAPTasks.keySet() AND IsDeleted = TRUE ALL ROWS];

				//if (!taskList.isEmpty()) {
					Database.undelete(taskList, false);
				//}
			}
		}
	}
	/**
	 * When inserting or updating Action Plan records, fill the text parent object `Related Object` and parent record  `Related Record` fields
	 * @author {@link [David Schach](https://github.com/dschach)}
	 * @param  newRecords Trigger.new
	 */
	private static void fillRelatedRecordFields(List<ActionPlan__c> newRecords) {
		Set<Id> parentIDs = new Set<Id>();
		for (ActionPlan__c actionPlan : newRecords) {
			for (String s : ActionPlansUtilities.getCustomRelationshipFields()) {
				if (actionPlan.get(s) != null) {
					parentIDs.add((Id) actionPlan.get(s));
					break;
				}
			}
		}
		Map<Id, String> relatedNamesMap = ActionPlansUtilities.queryRecordIDToRecordName(parentIDs);
		for (ActionPlan__c ap : newRecords) {
			for (String s : ActionPlansUtilities.getCustomRelationshipFields()) {
				if (ap.get(s) != null) {
					Id relatedId = (Id) ap.get(s);
					ap.Related_Record__c = relatedNamesMap.get(relatedId);
					if (String.isEmpty(ap.Related_Object__c) || ap.Id == null) {
						ap.Related_Object__c = ActionPlansUtilities.getRelatedSObjectDescribe(relatedId).getLabel();
					}
					break;
				}
			}
		}
	}

	/**
	 * Handle ActionPlan Tasks
	 * @author {@link [David Schach](https://github.com/dschach)}
	 * @param  newRecords    Trigger.new
	 * @param  oldRecords    Trigger.old
	 * @param  newRecordsMap Trigger.newMap
	 * @param  oldRecordsMap Trigger.oldMap
	 * @param  triggerEvent  Trigger context
	 */
	// prettier-ignore
	public static void triggerhandlerActionPlanTask(List<APTask__c> newRecords, List<APTask__c> oldRecords,	Map<Id, APTask__c> newRecordsMap,Map<Id, APTask__c> oldRecordsMap, System.TriggerOperation triggerEvent) {
		switch on triggerEvent {
			when BEFORE_INSERT, BEFORE_UPDATE {
				
				Set<Id> parentIDs = new Set<Id>();
				for(APTask__c apt : newRecords){
					parentIDs.add(apt.Action_Plan__c);
				}
				Map<Id, ActionPlan__c> parentMap = new Map<Id, ActionPlan__c>([SELECT Id, Name, StartDate__c FROM ActionPlan__c WHERE Id IN :parentIDs]);
				for (APTask__c a : newRecords) {
					a.IsClosed__c = ActionPlansUtilities.getClosedTaskStatuses().contains(a.Status__c);
					// TODO: Check if we need to move custom setting record owner logic here
					a.User__c = a.User__c == null ? UserInfo.getUserId() : a.User__c;
					a.DaysFromStart__c = a.DaysFromStart__c == null ? 0 : a.DaysFromStart__c;
					a.Dependent__c = (String.isBlank(a.Dependent__c)) ? 'None' : a.Dependent__c;
					// support manually creating related tasks - for future moving all logic into trigger handlers
					if(a.Id == null && a.Controller__c == null && a.DaysFromStart__c != null && a.ActivityDate__c == null){
						a.ActivityDate__c = parentMap.get(a.Action_Plan__c).StartDate__c.addDays(a.DaysFromStart__c.intValue());
					}
				}

				Set<Id> apIDs = new Set<Id>();
				String aptPrefix = Schema.APTask__c.getSObjectType().getDescribe().getKeyPrefix();

				for (APTask__c apt : newRecords) {
					if (
						oldRecords == null ||
						(apt.Name == null ||
						apt.Name.startsWithIgnoreCase(aptPrefix) ||
						(oldRecords != null &&
						apt.Subject__c != oldRecordsMap.get(apt.Id).Subject__c)) ||
						!apt.Name.endsWithIgnoreCase(apt.Subject__c)
					) {
						apIDs.add(apt.Action_Plan__c);
					}
				}
				if (!apIDs.isEmpty()) {
					Integer taskTemplateNameLength = APTask__c.Name.getDescribe().getLength();
					for (APTask__c apt : newRecords) {
						if (parentMap.containsKey(apt.Action_Plan__c)) {
							String apName = parentMap.get(apt.Action_Plan__c).Name;
							String newSubject = apName + ' - ' + apt.Subject__c;
							apt.Name = ActionPlansUtilities.actionPlanSubjectToName(newSubject, taskTemplateNameLength);
						}
					}
				}

				for (APTask__c a : newRecords) {
					if (a.Reminder__c && String.isBlank(a.Minutes_Reminder__c)) {
						a.Minutes_Reminder__c = ActionPlansUtilities.getDefaultReminderMinutes();
					} else if (!a.Reminder__c) {
						a.Minutes_Reminder__c = null;
					}
				}
			}
			
			when AFTER_UPDATE {
				Map<Id, Id> openControlledAPTasks = new Map<Id, Id>();
				Set<Id> parentControllingTaskIDs = new Set<Id>();
				for(APTask__c apt : newRecords){
					if(apt.Controller__c != null){
						openControlledAPTasks.put(apt.Id, apt.Controller__c);
						parentControllingTaskIDs.add(apt.Controller__c);
					}
				}
				Map<Id, APTask__c> parentControllingTasks = new Map<Id, APTask__c>([SELECT Id, (SELECT Id, IsClosed FROM Tasks__r) FROM APTask__c WHERE Id IN :parentControllingTaskIDs]);
				Set<Id> apTasksNeedingTaskDeletion = new Set<Id>();
				for(Id i : openControlledAPTasks.keyset()){
					APTask__c controller = parentControllingTasks.get(openControlledAPTasks.get(i));
					if(controller.Tasks__r.isEmpty() || !controller.Tasks__r[0].IsClosed){
						apTasksNeedingTaskDeletion.add(i);
					}
				}
				
				try {
					bypassTaskTrigger = true;
					Database.delete([SELECT Id FROM Task WHERE TaskAPTask__c IN :apTasksNeedingTaskDeletion]);
					bypassTaskTrigger = false;
				} catch (Exception e) {
					for (APTask__c a : newRecords) {
						a.addError('Error when deleting newly-dependent Task related to APTaskTemplate: ' + e.getMessage());
					}
				}
			}
			
			when BEFORE_DELETE {
				try {
					bypassTaskTrigger = true;
					Database.delete([SELECT Id FROM Task WHERE TaskAPTask__c IN :oldRecordsMap.keyset() AND IsClosed = FALSE AND IsDeleted = FALSE]);
					bypassTaskTrigger = false;
				} catch (Exception e) {
					for (APTask__c a : oldRecords) {
						a.addError('Error when deleting Task related to APTaskTemplate: ' + e.getMessage());
					}
				}
			}
			when AFTER_UNDELETE {
				List<Task> apTasks = [SELECT Id FROM Task WHERE TaskAPTask__c IN :newRecordsMap.keyset() AND IsDeleted = TRUE ALL ROWS];

				try {
					Database.undelete(apTasks);
				} catch (Dmlexception e) {
					for (APTask__c a : newRecords) {
						a.addError(System.Label.ap_Error + ' ' + Task.sObjectType.getDescribe().getLabel() + ' ' + triggerEvent + ': ' + e);
					}
				}
			}
		}
	}
	/**
	 * Handle ActionPlan Templates
	 * @author {@link [David Schach](https://github.com/dschach)}
	 * @param  newRecords    Trigger.new
	 * @param  oldRecords    Trigger.old
	 * @param  oldRecordsMap Trigger.oldMap
	 * @param  triggerEvent  Trigger context
	 */
	// prettier-ignore
	public static void triggerhandlerActionPlanTemplate(List<ActionPlanTemplate__c> newRecords, List<ActionPlanTemplate__c> oldRecords, Map<Id, ActionPlanTemplate__c> oldRecordsMap, System.TriggerOperation triggerEvent) {
		switch on triggerEvent {
			when BEFORE_INSERT {
				Id defaultTaskRTId = ActionPlansUtilities.getDefaultTaskRecordTypeId();

				for (ActionPlanTemplate__c apt : newRecords) {
					if (apt.TaskRecordTypeID__c == null || !(apt.TaskRecordTypeID__c instanceof Id)) {
						apt.TaskRecordTypeID__c = defaultTaskRTId;
					}
				}
			}
			when AFTER_UPDATE {
				Set<Id> changedNames = new Set<Id>();
				for (ActionPlanTemplate__c apt : newRecords) {
					if (apt.Name != oldRecordsMap.get(apt.Id).Name) {
						changedNames.add(apt.Id);
					}
				}
				if (!changedNames.isEmpty()) {
					List<APTemplateTask__c> templateTasks = [SELECT Id, Name FROM APTemplateTask__c WHERE Action_Plan_Template__c IN :changedNames];
					for (APTemplateTask__c a : templateTasks) {
						a.Name = null;
					}
					update templateTasks;
				}
			}
		}
	}
	/**
	 * Handle Action Plan Template Tasks
	 * @author {@link [David Schach](https://github.com/dschach)}
	 * @param  newRecords    Trigger.new
	 * @param  oldRecords    Trigger.old
	 * @param  oldRecordsMap Trigger.oldMap
	 * @param  triggerEvent  Trigger context
	 */
	// prettier-ignore
	public static void triggerhandlerActionPlanTemplateTask(List<APTemplateTask__c> newRecords, List<APTemplateTask__c> oldRecords, Map<Id, APTemplateTask__c> oldRecordsMap, System.TriggerOperation triggerEvent) {

		switch on triggerEvent {
			when BEFORE_INSERT, BEFORE_UPDATE {
				Set<Id> templateIDs = new Set<Id>();
				Schema.SObjectType aptttype = Schema.APTemplateTask__c.getSObjectType();
				Schema.DescribeSObjectResult apttDescribe = aptttype.getDescribe();
				String apttObjectName = apttDescribe.getName();
				String apttPrefix = ActionPlansUtilities.getObjectKeyPrefix(apttObjectName);
				for (APTemplateTask__c aptt : newRecords) {
					if (
						aptt.Name == null ||
						aptt.Name.startsWithIgnoreCase(apttPrefix) ||
						(oldRecords != null &&
						aptt.Subject__c != oldRecordsMap.get(aptt.Id).Subject__c) ||
						!aptt.Name.endsWithIgnoreCase(aptt.Subject__c)
					) {
						templateIDs.add(aptt.Action_Plan_Template__c);
					}
				}
				if (!templateIDs.isEmpty()) {
					Map<Id, ActionPlanTemplate__c> nameMap = new Map<Id, ActionPlanTemplate__c>([SELECT Id, Name FROM ActionPlanTemplate__c WHERE Id IN :templateIDs]);

					for (APTemplateTask__c aptt : newRecords) {
						if (nameMap.containsKey(aptt.Action_Plan_Template__c)) {
							String templateName = nameMap.get(aptt.Action_Plan_Template__c).Name;
							String newSubject = templateName + ' - ' + aptt.Subject__c;
							aptt.Name = ActionPlansUtilities.actionPlanSubjectToName(newSubject);
						}
					}
				}
				for (APTemplateTask__c a : newRecords) {
					if (a.Reminder__c && String.isBlank(a.Minutes_Reminder__c)) {
						a.Minutes_Reminder__c = ActionPlansUtilities.getDefaultReminderMinutes();
					} else if (!a.Reminder__c) {
						a.Minutes_Reminder__c = null;
					}
					if(a.DaysFromStart__c == null){
						a.DaysFromStart__c = 0;
					}
				}
			}
		}
	}
	/**
	 * Trigger handler for Task records when they are inserted, updated, or deleted
	 * @author {@link [David Schach](https://github.com/dschach)}
	 * @param  newRecords    Trigger.new
	 * @param  oldRecords    Trigger.old
	 * @param  triggerEvent  Trigger context
	 * @see ActionPlansTaskTriggerUtilities
	 */
	public static void triggerhandlerTask(List<Task> newRecords, List<Task> oldRecords, System.TriggerOperation triggerEvent) {
		// prettier-ignore
		if (bypassTaskTrigger) { return; }
		switch on triggerEvent {
			when BEFORE_INSERT {
				if (ActionPlansUtilities.taskUsesRecordTypes) {
					Map<Id, Id> taskTemplateToIntendedRecordTypeId = new Map<Id, Id>();
					Set<Id> taskTemplateIDs = new Set<Id>();
					for (Task t : newRecords) {
						if (t.TaskAPTask__c != null) {
							taskTemplateIDs.add(t.TaskAPTask__c);
						}
					}
					for (APTask__c aptt : [SELECT Id, Action_Plan__r.TaskRecordTypeID__c FROM APTask__c WHERE Id IN :taskTemplateIDs]) {
						taskTemplateToIntendedRecordTypeId.put(aptt.Id, aptt.Action_Plan__r.TaskRecordTypeID__c);
					}
					for (Task t : newRecords) {
						if (
							t.TaskAPTask__c != null &&
							taskTemplateToIntendedRecordTypeId.containsKey(t.TaskAPTask__c) &&
							ActionPlansUtilities.getTaskRecordTypeStatusDefaultValues().containsKey(taskTemplateToIntendedRecordTypeId.get(t.TaskAPTask__c))
						) {
							t.put('RecordTypeId', taskTemplateToIntendedRecordTypeId.get(t.TaskAPTask__c));
						}
					}
				}
			}
			when AFTER_UPDATE {
				Map<Id, String> closedTasksMap = new Map<Id, String>();
				Map<Id, String> inProgressTasksMap = new Map<Id, String>();
				Set<Id> aPTasksIds = new Set<Id>();

				Map<Id, Task> triggerTasksWithTemplateTaskStatus = new Map<Id, Task>();
				for (Task ta : [
					SELECT Id, Status, TaskAPTask__r.Status__c, TaskAPTask__r.Controller__c, TaskAPTask__r.Controller__r.Status__c
					FROM Task
					WHERE Id IN :newRecords AND TaskAPTask__c != NULL
				]) {
					triggerTasksWithTemplateTaskStatus.put(ta.Id, ta);
				}

				Set<Id> tasktemplatesToValidate = new Set<Id>();

				for (Task t : newRecords) {
					if (t.TaskAPTask__c != null) {
						tasktemplatesToValidate.add(t.TaskAPTask__c);
					}
				}

				Boolean taskHasRecordType = ActionPlansUtilities.taskUsesRecordTypes;

				Set<String> closedStatuses = ActionPlansUtilities.getClosedTaskStatuses();

				// Map of record ID to "true" if the related task template is OPEN
				Map<Id, Boolean> allowMap = allowChangeParentStatus(tasktemplatesToValidate);

				Map<Id, String> rtIdToDefaultStatus = ActionPlansUtilities.getTaskRecordTypeStatusDefaultValues();

				//Get all my Updated complete Task Id's.
				for (Task t : newRecords) {
					if (t.TaskAPTask__c != null) {
						aPTasksIds.add(t.TaskAPTask__c);

						// Find default task status
						String defaultTaskStatus;

						if (!taskHasRecordType) {
							defaultTaskStatus = rtIdToDefaultStatus.get(null);
						} else {
							defaultTaskStatus = rtIdToDefaultStatus.get((Id) t.get('recordtypeid'));
						}

						if (t.Status != defaultTaskStatus) {
							if (allowMap.containsKey(t.TaskAPTask__c) && allowMap.get(t.TaskAPTask__c)) {
								if (t.IsClosed || closedStatuses.contains(t.Status)) {
									closedTasksMap.put(t.TaskAPTask__c, t.Status);
								} else {
									inProgressTasksMap.put(t.TaskAPTask__c, t.Status);
								}
							} else {
								//throw exception
								t.Status.addError(System.Label.ap_UpdateStatusError);
							}
						}
					}
				}

				//Call to ActionPlansUtilities in order to proceed with creation of dependent Task
				if (!closedTasksMap.isEmpty()) {
					ActionPlansTaskTriggerUtilities.initDependentTaskWork(closedTasksMap);
				}
				//update status to in progress for AP Tasks
				if (!inProgressTasksMap.isEmpty()) {
					ActionPlansTaskTriggerUtilities.updateAPTasksStatus(inProgressTasksMap);
				}

				//Query APTask__c objects to update fields
				if (!aPTasksIds.isEmpty()) {
					Map<Id, APTask__c> mapAPTasks = new Map<Id, APTask__c>(
						[SELECT Status__c, Id, Controller__r.Status__c, ActivityDate__c, Minutes_Reminder__c, Action_Plan__r.Name, User__c FROM APTask__c WHERE Id IN :APTasksIds]
					);
					List<APTask__c> lUpsert = new List<APTask__c>();

					for (Task t : newRecords) {
						if (mapAPTasks.containsKey(t.TaskAPTask__c)) {
							APTask__c tmp = mapAPTasks.get(t.TaskAPTask__c);
							tmp.Subject__c = t.Subject;
							tmp.Name = tmp.Id;
							tmp.Comments__c = t.Description;
							tmp.Priority__c = t.Priority;
							// Do not change AP Task owner if Task is assigned to a queue
							if (((String) t.OwnerId).startsWith('005')) {
								tmp.User__c = t.OwnerId;
							}
							//tmp.User__c = ( ? t.OwnerId : tmp.User__c;
							tmp.ActivityDate__c = t.ActivityDate;
							tmp.Department__c = t.Department__c;
							tmp.Topic__c = t.Topic__c;
							tmp.Promote_to_Case__c = t.Promote_to_Case__c;
							lUpsert.add(tmp);
						}
					}
					if (!lUpsert.isEmpty()) {
						// no permission check because in trigger handler
						upsert lUpsert;
					}
				}
			}
			when BEFORE_DELETE {
				Set<Id> taskTempIds = new Set<Id>();
				for (Task t : oldRecords) {
					if (t.TaskAPTask__c != null) {
						taskTempIds.add(t.TaskAPTask__c);
					}
				}
				//only delete Action Plan Template Tasks that are not deleted
				//create any tasks depending on this one
				ActionPlansTaskTriggerUtilities.actionsOnTaskBeforeDelete(taskTempIds);
			}
			when AFTER_DELETE {
				Set<Id> taskTempIds = new Set<Id>();
				Set<Id> finalIds = new Set<Id>();
				for (Task t : oldRecords) {
					if (t.TaskAPTask__c != null) {
						taskTempIds.add(t.TaskAPTask__c);
					}
				}
				//only delete Action Plan Template Tasks that are not deleted
				for (APTask__c ta : [SELECT Id, Action_Plan__c FROM APTask__c WHERE Id IN :taskTempIds AND IsDeleted = FALSE ALL ROWS]) {
					finalIds.add(ta.Id);
				}

				if (!finalIds.isEmpty()) {
					if (forceSynchronous()) {
						delete [SELECT Id FROM APTask__c WHERE Id IN :finalIds];
					} else {
						ActionPlansTaskTriggerUtilities.deleteAPTasks(finalIds);
					}
				}
			}
		}
	}

	/**
	 * Handle ActionPlans related to Leads after conversion
	 * @author {@link [David Schach](https://github.com/dschach)}
	 * @param  newRecords    Trigger.new
	 * @param  oldRecords    Trigger.old
	 * @param  newRecordsMap Trigger.newMap
	 * @param  oldRecordsMap Trigger.oldMap
	 * @param  triggerEvent  Trigger context
	 */
	public static void triggerhandlerActionPlanLead(
		List<Lead> newRecords,
		List<Lead> oldRecords,
		Map<Id, Lead> newRecordsMap,
		Map<Id, Lead> oldRecordsMap,
		System.TriggerOperation triggerEvent
	) {
		switch on triggerEvent {
			when AFTER_UPDATE {
				List<ActionPlan__c> leadAPs = [SELECT Id, Lead__c, Contact__c, Account__c, Opportunity__c, Description__c FROM ActionPlan__c WHERE Lead__c IN :newRecordsMap.keySet()];

				Map<Id, ActionPlan__c> apMap = new Map<Id, ActionPlan__c>();
				List<ActionPlan__c> toUpdate = new List<ActionPlan__c>();

				for (ActionPlan__c ap : leadAPs) {
					apMap.put(ap.Lead__c, ap);
				}

				String destinationObject = ActionPlansUtilities.getCustomSetting().Default_Object_on_Lead_Conversion__c;
				if (destinationObject != null) {
					destinationObject = destinationObject.toLowerCase();
				}

				for (Lead l : newRecords) {
					if (l.IsConverted && !oldRecordsMap.get(l.Id).IsConverted && apMap.containsKey(l.Id)) {
						ActionPlan__c ap = apMap.get(l.Id);

						switch on destinationObject {
							when 'account' {
								ap.Account__c = l.ConvertedAccountId;
							}
							when 'opportunity' {
								ap.Opportunity__c = l.ConvertedOpportunityId;
							}
							when else {
								ap.Contact__c = l.ConvertedContactId;
							}
						}
						ap.Lead__c = null;
						toUpdate.add(ap);
					}
				}
				update toUpdate;
			}
		}
	}

	/**
	 * Handle Account-related Action Plans on delete and undelete (of the Account)
	 * @author {@link [David Schach](https://github.com/dschach)}
	 * @param  newRecords    Trigger.new
	 * @param  oldRecords    Trigger.old
	 * @param  newRecordsMap Trigger.newMap
	 * @param  oldRecordsMap Trigger.oldMap
	 * @param  triggerEvent  Trigger context
	 */
	// prettier-ignore
	public static void triggerhandlerActionPlanAccount(List<Account> newRecords, List<Account> oldRecords, Map<Id, Account> newRecordsMap, Map<Id, Account> oldRecordsMap, System.TriggerOperation triggerEvent) {
		//Delete related action plans
		switch on triggerEvent {
			when BEFORE_DELETE {
				Set<Id> oldRecordIDs = oldRecordsMap.keyset();

				// Get Action Plans to delete in recycle bin
				List<ActionPlan__c> deletePermenantlyAPIds = [
					SELECT Id
					FROM ActionPlan__c
					WHERE
						(Contact__r.AccountId IN :oldRecordIDs
						OR Case__r.AccountId IN :oldRecordIDs
						OR Contract__r.AccountId IN :oldRecordIDs
						OR Opportunity__r.AccountId IN :oldRecordIDs)
						AND isDeleted = TRUE
					ALL ROWS
				];

				if (!deletePermenantlyAPIds.isEmpty()) {
					Database.emptyRecycleBin(deletePermenantlyAPIds);
				}

				Set<Id> apIds = new Set<Id>();
				for (ActionPlan__c ap : [
					SELECT Id
					FROM ActionPlan__c
					WHERE Contact__r.AccountId IN :oldRecordIDs OR Case__r.AccountId IN :oldRecordIDs OR Contract__r.AccountId IN :oldRecordIDs OR Opportunity__r.AccountId IN :oldRecordIDs
				]) {
					apIds.add(ap.Id);
				}

				if (!apIds.isEmpty()) {
					if(forceSynchronous()){
						deleteActionPlans(apIds);
					} else {
						futureDeleteActionPlans(apIds);
					}
				}
			}
			//Undelete related action plans
			when AFTER_UNDELETE {
				Set<Id> relatedIDs = new Set<Id>();
				for (Contact c : [SELECT Id FROM Contact WHERE AccountId IN :newRecordsMap.keyset()]) {
					relatedIDs.add(c.Id);
				}
				for (Contract c : [SELECT Id FROM Contract WHERE AccountId IN :newRecordsMap.keySet()]) {
					relatedIDs.add(c.Id);
				}
				for (Case c : [SELECT Id FROM Case WHERE AccountId IN :newRecordsMap.keySet()]) {
					relatedIDs.add(c.Id);
				}
				for (Opportunity c : [SELECT Id FROM Opportunity WHERE AccountId IN :newRecordsMap.keySet()]) {
					relatedIDs.add(c.Id);
				}

				List<ActionPlan__c> aPs = [SELECT Id FROM ActionPlan__c WHERE Contact__c IN :relatedIDs OR Contract__c IN :relatedIDs OR Case__c IN :relatedIDs OR Opportunity__c IN :relatedIDs ALL ROWS];

				try {
					if (ActionPlansTestUtilities.forceError) {
						//throw dmlException
						insert new Contact();
					}
					//undelete aPs;
					Database.undelete(aPs, false);
				} catch (Dmlexception e) {
					for (Account c : newRecords) {
						c.addError(System.Label.ap_RelObjUndeleteError);
					}
				}
			}
		}
	}
	/**
	 * Validate that 1 and only 1 custom reference field is filled
	 * @author {@link [David Schach](https://github.com/dschach)}
	 * @param  actionPlans Trigger records to validate
	 * @see ActionPlansUtilities.getCustomRelationshipFields
	 */
	private static void validateActionPlans(List<ActionPlan__c> actionPlans) {
		List<String> actionPlanReferenceFields = ActionPlansUtilities.getCustomRelationshipFields();

		// Validate that 1 and only 1 custom reference field is filled

		for (ActionPlan__c ap : actionPlans) {
			Integer filledReferences = 0;

			for (String s : actionPlanReferenceFields) {
				if (ap.get(s) != null) {
					filledReferences++;
				}
			}
			if (filledReferences != 1) {
				ap.addError(System.Label.ap_RelatedCount);
			}
		}
	}

	/**
	 * Though the object name should match the field name, we get the name of the related object
	 * @param recordId The related record Id
	 * @return         The name of the filled Relationship field object name
	 */
	private static String getRelationshipName(Id recordId) {
		String sObjectName = recordId.getSObjectType().getDescribe().getName().toLowerCase();

		Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.ActionPlan__c.fields.getMap();

		for (String s : fieldMap.keyset()) {
			Schema.DescribeFieldResult dfr = fieldMap.get(s).getDescribe();
			Schema.DisplayType dt = dfr.getType();
			if (dt.name().equalsIgnoreCase('Reference') && s.endsWithIgnoreCase('__c')) {
				String relationshipObjectName = dfr.getReferenceTo()[0].getDescribe().getName();
				if (sObjectName.equalsIgnoreCase(relationshipObjectName)) {
					return s;
				}
			}
		}
		return null;
	}

	/**
	 * Validates if the given tasks can change status to in progress or completed.
	 * <br>If the task depends on another that is open, returns false
	 * <br>This bulkified method avoids SOQL queries in a loop
	 * @param apTaskTemplateIds bulkified set of task IDs to consider
	 * @return `Map<Id, Boolean>` Is each APTask dependent on another task and is in an open status?
	 */
	private static Map<Id, Boolean> allowChangeParentStatus(Set<Id> apTaskTemplateIds) {
		Map<Id, Boolean> allowTasksMap = new Map<Id, Boolean>();
		Set<String> openStatuses = ActionPlansUtilities.getOpenTaskStatuses();

		for (APTask__c apt : [SELECT Status__c, Controller__c, Controller__r.Status__c FROM APTask__c WHERE Id IN :apTaskTemplateIds]) {
			allowTasksMap.put(apt.Id, apt.Controller__c == null || !openStatuses.contains(apt.Controller__r.Status__c));
		}
		return allowTasksMap;
	}

	/**
	 * Given actionplanIDs, delete these Action Plans AND their open Tasks
	 * @author {@link [David Schach](https://github.com/dschach)}
	 * @param  relActionPlansIds `ActionPlan__c` IDs
	 */
	private static void deleteActionPlans(Set<Id> relActionPlansIds) {
		List<ActionPlan__c> relActionPlans = [SELECT Id FROM ActionPlan__c WHERE Id IN :relActionPlansIds];
		Map<Id, APTask__c> relTaskTemplateMap = new Map<Id, APTask__c>([SELECT Id FROM APTask__c WHERE Action_Plan__c IN :relActionPlansIds]);
		List<Task> relTaskList = [SELECT Id FROM Task WHERE IsClosed = FALSE AND TaskAPTask__c IN :relTaskTemplateMap.keySet()];

		if (!relActionPlans.isEmpty()) {
			List<Database.DeleteResult> results = Database.delete(relActionPlans, false); //NOPMD
		}

		if (!relTaskList.isEmpty()) {
			List<Database.DeleteResult> results = Database.delete(relTaskList, false); //NOPMD
		}
	}

	/**
	 * Given actionplanIDs, delete these Action Plans AND their open Tasks in future context
	 * @author {@link [David Schach](https://github.com/dschach)}
	 * @param  relActionPlansIds `ActionPlan__c` IDs
	 * @see ActionPlanTriggerHandlers.deleteActionPlans
	 */
	@testVisible
	@future
	private static void futureDeleteActionPlans(Set<Id> relActionPlansIds) {
		deleteActionPlans(relActionPlansIds);
	}

	/**
	 * Simple method to check if we are asynchronous already
	 * @author {@link [David Schach](https://github.com/dschach)}
	 * @return  `Boolean` Are we in an asynchronous state (so can't call future methods)?
	 */
	private static Boolean forceSynchronous() {
		return (System.isQueueable() || System.isFuture() || System.isBatch() || Test.isRunningTest());
	}
}