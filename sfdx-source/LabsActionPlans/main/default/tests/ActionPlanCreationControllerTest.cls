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
 * Tests for `ActionPlan__c` Create/Edit Visualforce Extension
 * @author {@link [David Schach](https://github.com/dschach)}
 * @see ActionPlanCreationController
 * @group Tests
 */
@IsTest
private class ActionPlanCreationControllerTest {
	@TestSetup
	private static void makeData() {
		Action_Plans_Settings__c aps = ActionPlansUtilities.getCustomSetting();
		aps.Chatter_Object_Brag__c = true;
		aps.Unassigned_Task_Assigned_to_Owner__c = true;
		try {
			upsert aps;
		} catch (Exception e) {
			update aps;
		}
	}

	@IsTest
	private static void singleRecordConstructor() {
		Test.startTest();
		Test.setCurrentPage(Page.ActionPlanCreation);

		ActionPlansTestUtilities testUtil = new ActionPlansTestUtilities();
		ActionPlan__c actionPlan = testUtil.createNewActionPlan('contact', 2);

		ActionPlanCreationController apCreateController = new ActionPlanCreationController(new Apexpages.StandardController(actionPlan));
		apCreateController.onLoad();
		System.assertEquals(0, ActionPlansTestUtilities.getCompleted(actionPlan.Id), 'New AP should have no completed tasks');
		System.assertNotEquals(null, apCreateController.relatedFieldName, 'should have lazy loaded relatedFieldName');
		apCreateController.getAllRelationshipFields();
		System.assertEquals('', apCreateController.getTemplateName());

		//apCreateController = new ActionPlanCreationController(new Apexpages.StandardController(actionPlan));
		apCreateController.relatedObjectId();
		apCreateController.save();
		Test.stopTest();
	}

	@IsTest
	private static void saveAndView() {
		Test.startTest();
		Test.setCurrentPage(Page.ActionPlanCreation);

		ActionPlansTestUtilities testUtil = new ActionPlansTestUtilities();
		ActionPlan__c actionPlan = testUtil.createNewActionPlan('contact', 2);

		ActionPlanCreationController apCreateController = new ActionPlanCreationController(new Apexpages.StandardController(actionPlan));
		apCreateController.onLoad();
		System.assertEquals(0, ActionPlansTestUtilities.getCompleted(actionPlan.Id), 'New AP should have no completed tasks');
		System.assertNotEquals(null, apCreateController.relatedFieldName, 'should have lazy loaded relatedFieldName');
		apCreateController.getAllRelationshipFields();
		System.assertEquals('', apCreateController.getTemplateName());

		//apCreateController = new ActionPlanCreationController(new Apexpages.StandardController(actionPlan));
		apCreateController.relatedObjectId();
		PageReference viewPage = apCreateController.save();
		Test.stopTest();

		Test.setCurrentPage(viewPage);
		ActionPlanDetailController apdc = new ActionPlanDetailController(new Apexpages.StandardController(actionPlan));
		System.assertNotEquals(0, apdc.getActionPlanTasks().size());
	}

	@IsTest
	private static void saveAndDelete() {
		Test.startTest();
		Test.setCurrentPage(Page.ActionPlanCreation);

		ActionPlansTestUtilities testUtil = new ActionPlansTestUtilities();
		ActionPlan__c actionPlan = testUtil.createNewActionPlan('contact', 2);

		ActionPlanCreationController apCreateController = new ActionPlanCreationController(new Apexpages.StandardController(actionPlan));
		apCreateController.onLoad();
		apCreateController.save();

		System.assertNotEquals(0, [SELECT COUNT() FROM Task]);

		delete actionPlan;
		Test.stopTest();
		System.assertEquals(0, [SELECT COUNT() FROM Task]);
	}

	@IsTest
	private static void newAPWithoutTasks() {
		ActionPlansTestUtilities testUtil = new ActionPlansTestUtilities();
		ActionPlan__c actionPlan = testUtil.createNewActionPlan('contact', 0);

		Test.startTest();
		Test.setCurrentPage(Page.ActionPlanCreation);
		ActionPlanCreationController apCreateController = new ActionPlanCreationController(new Apexpages.StandardController(actionPlan));
		apCreateController.onLoad();
		Test.stopTest();
		System.assert(apCreateController.getTasks().isEmpty());
	}

	@IsTest
	private static void constructorTests() {
		Test.startTest();
		Test.setCurrentPage(Page.ActionPlanCreation);

		ApexPages.currentPage().getParameters().put('id', null);
		ActionPlanCreationController apCreateController = new ActionPlanCreationController(new Apexpages.StandardController(new ActionPlan__c()));
		apCreateController.onLoad();
		System.assertEquals(0, ActionPlansTestUtilities.getCompleted(apCreateController.actionPlan.Id), 'New AP should have no completed tasks');
		System.assertNotEquals(null, apCreateController.relatedFieldName, 'should have lazy loaded relatedFieldName');

		ActionPlansTestUtilities testUtil = new ActionPlansTestUtilities();
		ActionPlan__c actionPlan = testUtil.createNewActionPlan('contact', 2);

		apCreateController = new ActionPlanCreationController(new Apexpages.StandardController(actionPlan));

		ApexPages.currentPage().getParameters().put('id', null);
		ApexPages.currentPage().getParameters().put('clone', '1');
		apCreateController = new ActionPlanCreationController(new Apexpages.StandardController(new ActionPlan__c()));

		ActionPlanTemplate__c apTemplate = testUtil.createNewActionPlanTemplate(3);

		ApexPages.currentPage().getParameters().put('id', null);
		ApexPages.currentPage().getParameters().put('clone', null);
		ApexPages.currentPage().getParameters().put('templateId', apTemplate.Id);
		apCreateController = new ActionPlanCreationController(new Apexpages.StandardController(new ActionPlan__c()));

		Contact contact = testUtil.createNewContact();

		ApexPages.currentPage().getParameters().put('id', null);
		ApexPages.currentPage().getParameters().put('refId', contact.Id);
		apCreateController = new ActionPlanCreationController(new Apexpages.StandardController(new ActionPlan__c()));
		String refId = apCreateController.refId;
		System.debug(refId);
		String reftype = apCreateController.refType;
		System.debug(reftype);

		apCreateController.refreshRelatedObjectsLookUp();
		apCreateController.getTaskRTPicklistValues();
		apCreateController.getTaskTypes();
		apCreateController.getTaskPriorities();
		apCreateController.getHoursOption();
		apCreateController.getDisplayTemplateLookup();
		apCreateController.getRecordTypeName();

		apCreateController.relatedFieldName = ActionPlansUtilities.namespacePrefix + 'Contract__c';
		apCreateController.relatedFieldName = ActionPlansUtilities.namespacePrefix + 'Case__c';
		apCreateController.relatedFieldName = ActionPlansUtilities.namespacePrefix + 'Contact__c';

		apCreateController.save();

		Test.stopTest();
	}

	@IsTest
	private static void actionPlanSave() {
		ActionPlan__c ap = new ActionPlansTestUtilities().createNewActionPlan('contact', 3);

		Contact contact = [SELECT Id FROM Contact LIMIT 1];

		Test.startTest();

		Test.setCurrentPage(Page.ActionPlanCreation);
		ApexPages.currentPage().getParameters().put('id', ap.Id);
		ApexPages.currentPage().getParameters().put('refId', contact.Id);
		ApexPages.currentPage().getParameters().put('refType', 'Contact');

		ActionPlanCreationController apCreateController = new ActionPlanCreationController(new Apexpages.StandardController(ap));

		apCreateController.actionPlan.name = 'updated name';

		apCreateController.save();

		System.assertEquals(3, [SELECT COUNT() FROM Task]);

		APTask__c aptEmail = [SELECT Id, SendEmail__c FROM APTask__c LIMIT 1];
		aptEmail.SendEmail__c = true;
		update aptEmail;

		Test.setCurrentPage(Page.ActionPlanCreation);
		apCreateController = new ActionPlanCreationController(new Apexpages.StandardController(ap));
		apCreateController.getTasks();
		apCreateController.actionPlan.SkipWeekends__c = true;
		apCreateController.actionPlan.SkipDay__c = 'End of previous week';

		apCreateController.save();

		Test.stopTest();

		List<ActionPlan__c> results = [SELECT Id, name, Contact__c FROM ActionPlan__c LIMIT 10000];

		System.assert(!results.isEmpty(), 'Action Plan not created');
		System.assert(results.size() == 1, 'Too many Action Plans created');

		apCreateController.cancel();
	}

	@IsTest
	private static void actionPlanSaveAndNew() {
		Test.setCurrentPage(Page.ActionPlanCreation);

		ActionPlansTestUtilities testUtil = new ActionPlansTestUtilities();
		ActionPlan__c actionPlan = new ActionPlan__c();

		Contact contact = testUtil.createNewContact();

		actionPlan.Name = testUtil.createRandomWord('Name');
		actionPlan.Contact__c = contact.Id;
		actionPlan.StartDate__c = Date.today();

		APTask__c apTask = testUtil.createNewActionPlanTask(actionPlan, null, UserInfo.getUserId(), 'Email', 'Normal');

		ApexPages.currentPage().getParameters().put('id', null);
		ApexPages.currentPage().getParameters().put('refId', contact.Id);
		ApexPages.currentPage().getParameters().put('refType', 'Contact');

		Test.startTest();

		ActionPlanCreationController apCreateController = new ActionPlanCreationController(new Apexpages.StandardController(actionPlan));

		apCreateController.apTasks = new List<APTask__c>();
		apCreateController.apTasks.add(apTask);
		apCreateController.saveAndNew();
		Test.stopTest();
		List<ActionPlan__c> results = [SELECT Id FROM ActionPlan__c LIMIT 10000];

		System.assert(!results.isEmpty(), 'Action Plan not created');
		System.assert(results.size() == 1, 'ONE Action Plan not created');
		System.debug(results.size() + ' action plans created');
	}

	@IsTest
	private static void actionPlanSaveAndMakeDependent() {
		Test.setCurrentPage(Page.ActionPlanCreation);

		ActionPlansTestUtilities testUtil = new ActionPlansTestUtilities();

		ActionPlan__c actionPlan = testUtil.createNewActionPlan('contact', 2);

		ApexPages.currentPage().getParameters().put('id', actionPlan.Id);

		ActionPlanCreationController apCreateController = new ActionPlanCreationController(new Apexpages.StandardController(actionPlan));
		apCreateController.save();
		Test.startTest();

		List<APTask__c> apTasks = [SELECT Id, Controller__c FROM APTask__c];
		apTasks[1].Controller__c = apTasks[0].Id;
		update apTasks[1];

		apCreateController = new ActionPlanCreationController(new Apexpages.StandardController(actionPlan));
		Test.stopTest();

		List<Task> results = [SELECT Id FROM Task];
		System.assertEquals(1, results.size(), 'ONE Task left - the other was deleted');
	}

	@IsTest
	private static void relateToMultipleContacts() {
		final Integer conCOUNT = 40;
		final Integer apTASKCOUNT = 2;

		List<Contact> contactsList = new List<Contact>();
		for (Integer i = 0; i < conCOUNT; i++) {
			Contact newContact = new Contact(LastName = 'con' + math.rint(math.random() * 100000));
			contactsList.add(newContact);
		}

		Database.DMLOptions dml = new Database.DMLOptions();
		dml.DuplicateRuleHeader.allowSave = true;
		dml.DuplicateRuleHeader.runAsCurrentUser = true;
		Database.insert(contactsList, dml);

		List<Id> conIDs = new List<Id>();
		for (Contact c : contactsList) {
			conIDs.add(c.Id);
		}
		String conIdsList = String.join(conIDs, ',');

		ActionPlansTestUtilities testUtil = new ActionPlansTestUtilities();
		ActionPlanTemplate__c apTemplate = testUtil.createNewActionPlanTemplate(apTASKCOUNT);

		Test.startTest();

		Test.setCurrentPage(Page.ActionPlanCreation);

		ApexPages.currentPage().getParameters().put('id', null);
		ApexPages.currentPage().getParameters().put('templateId', apTemplate.Id);
		ApexPages.currentPage().getParameters().put('refId', conIDsList);
		ApexPages.currentPage().getParameters().put('refType', 'Contact');
		ActionPlanCreationController apCreateController = new ActionPlanCreationController(new Apexpages.StandardController(new ActionPlan__c()));
		System.assert(apCreateController.inVisualforceContext, 'Test should have VF context as true');
		apCreateController.getTasks();
		System.assertEquals(apTASKCOUNT, apCreateController.getTasks().size());
		System.assertEquals(conCOUNT, apCreateController.getNameListSize());

		apCreateController.getTemplateName();
		apCreateController.save();

		Test.stopTest();
		System.assertEquals(apTASKCOUNT, [SELECT COUNT() FROM APTemplateTask__c]);

		System.assertEquals(conCOUNT, [SELECT COUNT() FROM ActionPlan__c], 'Failed to make one AP per contact');
		System.debug('successfully related to ' + conCOUNT + ' Contacts');

		System.assertNotEquals(0, [SELECT COUNT() FROM ActionPlan__c WHERE Contact__c != NULL], 'Should have linked Action Plan to contact');

		System.assertEquals(conCOUNT * apTASKCOUNT, [SELECT COUNT() FROM APTask__c], 'Not enough Action Plan Tasks created');
		System.assertEquals(conCOUNT * apTASKCOUNT, [SELECT COUNT() FROM Task], 'Wrong number of Tasks created');
	}

	@IsTest
	private static void checkCompletedTasks() {
		Test.setCurrentPage(Page.ActionPlanCreation);

		ActionPlansTestUtilities testUtil = new ActionPlansTestUtilities();
		ActionPlan__c actionPlan = testUtil.createNewActionPlan('account', 2);

		Test.startTest();

		ActionPlanCreationController apCreateController = new ActionPlanCreationController(new Apexpages.StandardController(actionPlan));
		apCreateController.save();
		apCreateController = new ActionPlanCreationController(new Apexpages.StandardController(actionPlan));

		System.assertEquals(0, ActionPlansTestUtilities.getCompleted(actionPlan.Id), 'New AP should have no completed tasks');
		Task openTask = [SELECT Id, IsClosed, Status FROM Task LIMIT 1];
		for (String s : ActionPlansUtilities.getClosedTaskStatuses()) {
			try {
				openTask.Status = s;
				update openTask; //NOPMD
				break;
			} catch (Exception e) {
				continue;
			}
		}
		update openTask;
		Test.stopTest();
		apCreateController = new ActionPlanCreationController(new Apexpages.StandardController(actionPlan));
		System.assertEquals(1, ActionPlansTestUtilities.getCompleted(actionPlan.Id), 'The completed Task should have been reflected in the Action Plan');
	}

	@IsTest
	private static void longNameTasks() {
		Test.startTest();

		Test.setCurrentPage(Page.ActionPlanCreation);

		ActionPlansTestUtilities testUtil = new ActionPlansTestUtilities();
		ActionPlan__c actionPlan = testUtil.createNewActionPlan('account', 2);

		// add code for shortening long record names
		actionPlan.Name = '1234567890123456789012345678901234567890'; // 40 characters
		update actionPlan;
		List<APTask__c> apts = [SELECT Id, Subject__c FROM APTask__c];
		for (APTask__c a : apts) {
			a.Subject__c = 'abcdefghijabcdefghijabcdefghijabcdefghij'; // 40 characters
		}
		update apts;

		//ActionPlanCreationController apCreateController = new ActionPlanCreationController(new Apexpages.StandardController(actionPlan));
		Test.stopTest();

		for (APTask__c a : [SELECT Id, Name FROM APTask__c]) {
			System.assertEquals(80, a.Name.length(), 'APTask Template name was not updated');
		}
	}

	@IsTest
	private static void addNewTask() {
		ActionPlansTestUtilities testUtil = new ActionPlansTestUtilities();

		Test.setCurrentPage(Page.ActionPlanCreation);

		ActionPlan__c actionPlan = testUtil.createNewActionPlan('account', 0);

		User ownerUser = testUtil.createTestUser();

		APTask__c apTask = testUtil.createNewActionPlanTask(actionPlan, 0, ownerUser.Id, null, null);
		insert apTask;

		Id defaultTaskRTId = ActionPlansUtilities.getDefaultTaskRecordTypeId();

		Test.startTest();

		ActionPlanCreationController apCreateController = new ActionPlanCreationController(new Apexpages.StandardController(actionPlan));
		//apCreateController.apTasks = new List<APTask__c>();
		//apCreateController.getTasks();
		System.assertEquals(1, apCreateController.getTasks().size());
		apCreateController.addTask();
		List<ActionPlanCreationController.ApTaskWrapper> taskWrapList = apCreateController.getTasks();
		System.assertEquals(2, taskWrapList.size());

		ActionPlanCreationController.ApTaskWrapper taskWrap = taskWrapList[1];

		taskWrap.apt.Subject__c = testUtil.createRandomWord('subject');
		taskWrap.apt.DaysFromStart__c = 3;
		taskWrap.apt.User__c = null;
		taskWrap.apt.Type__c = ActionPlansUtilities.getTaskRecordTypeTypeDefaultValues().get(defaultTaskRTId);
		taskWrap.apt.Priority__c = ActionPlansUtilities.getTaskRecordTypePriorityDefaultValues().get(defaultTaskRTId);
		apCreateController.save();

		Test.stopTest();

		System.assertEquals(2, [SELECT COUNT() FROM APTask__c]);
	}

	@IsTest
	private static void changeAPTaskOwner() {
		ActionPlansTestUtilities testUtil = new ActionPlansTestUtilities();

		Test.setCurrentPage(Page.ActionPlanCreation);

		ActionPlan__c actionPlan = testUtil.createNewActionPlan('account', 0);

		User ownerUser = testUtil.createTestUser();

		APTask__c apTask = testUtil.createNewActionPlanTask(actionPlan, 0, ownerUser.Id, null, null);
		insert apTask;

		Id defaultTaskRTId = ActionPlansUtilities.getDefaultTaskRecordTypeId();
		if (ActionPlansUtilities.taskUsesRecordTypes) {
			System.assertNotEquals(null, defaultTaskRTId);
		}

		Test.startTest();

		ActionPlanCreationController apCreateController = new ActionPlanCreationController(new Apexpages.StandardController(actionPlan));
		List<ActionPlanCreationController.ApTaskWrapper> taskWrapList = apCreateController.getTasks();
		ActionPlanCreationController.ApTaskWrapper taskWrap = taskWrapList[0];

		taskWrap.apt.User__c = System.UserInfo.getUserId();
		apCreateController.save();

		Test.stopTest();

		System.assertEquals(System.UserInfo.getUserId(), [SELECT Id, OwnerId FROM Task LIMIT 1].OwnerId);
	}

	@IsTest
	private static void removeActionPlanTask() {
		Test.setCurrentPage(Page.ActionPlanCreation);

		ActionPlansTestUtilities testUtil = new ActionPlansTestUtilities();
		ActionPlan__c actionPlan = testUtil.createNewActionPlan('account', 3);

		Test.startTest();

		ApexPages.currentPage().getParameters().put('id', actionPlan.Id);
		ApexPages.currentPage().getParameters().put('remove', '1');
		ActionPlanCreationController apCreateController = new ActionPlanCreationController(new Apexpages.StandardController(actionPlan));

		apCreateController.getTasks();
		apCreateController.getTasks()[0].apt.SendEmail__c = true;
		apCreateController.removeTask();
		apCreateController.save();

		Test.stopTest();

		System.assertEquals(2, [SELECT COUNT() FROM APTask__c]);
	}

	@IsTest
	private static void checkActionPlanTaskList() {
		Test.startTest();

		Test.setCurrentPage(Page.ActionPlanCreation);

		ActionPlansTestUtilities testUtil = new ActionPlansTestUtilities();
		ActionPlan__c actionPlan = testUtil.createNewActionPlan('account', 2);

		ApexPages.currentPage().getParameters().put('id', actionPlan.Id);
		ActionPlanCreationController apCreateController = new ActionPlanCreationController(new Apexpages.StandardController(actionPlan));

		List<ActionPlanCreationController.ApTaskWrapper> apTaskList = apCreateController.getTasks();

		Test.stopTest();
		System.assert(!apTaskList.isEmpty(), 'Action plan task list is empty');
	}

	@IsTest
	private static void checkSubjectItems() {
		Integer taskCOUNT = 2;
		Test.startTest();

		Test.setCurrentPage(Page.ActionPlanCreation);

		ActionPlansTestUtilities testUtil = new ActionPlansTestUtilities();
		ActionPlan__c actionPlan = testUtil.createNewActionPlan('account', taskCOUNT);

		ApexPages.currentPage().getParameters().put('id', actionPlan.Id);
		ActionPlanCreationController apCreateController = new ActionPlanCreationController(new Apexpages.StandardController(actionPlan));
		apCreateController.apTasks = [
			SELECT
				Type__c,
				Subject__c,
				ActivityDate__c,
				Priority__c,
				Status__c,
				Dependent__c,
				Name,
				User__c,
				User__r.Name,
				Id,
				DaysFromStart__c,
				CreatedById,
				Controller__r.Name,
				Controller__r.Subject__c,
				Controller__c,
				Action_Plan__c,
				Reminder__c,
				SendEmail__c,
				Comments__c
			FROM APTask__c
			WHERE Action_Plan__c = :actionPlan.Id
			ORDER BY createdDate ASC
		];

		List<Selectoption> options = apCreateController.getSubjectItems();

		Test.stopTest();

		System.assert(!options.isEmpty(), 'SELECT options is empty');
		System.assertEquals(taskCOUNT + 1, options.size(), 'incorrect number of select options');
	}

	@IsTest
	private static void cyclicDependencyTaskSuccess() {
		Test.startTest();

		Test.setCurrentPage(Page.ActionPlanCreation);

		ActionPlansTestUtilities testUtil = new ActionPlansTestUtilities();

		ActionPlan__c actionPlan = testUtil.createNewActionPlan('account', 0);

		APTask__c newAPTask2 = testUtil.createNewActionPlanTask(actionPlan, 2, actionPlan.OwnerId, 'Email', null);
		newAPTask2.TaskIndex__c = 1;
		newAPTask2.Dependent__c = 'None';
		upsert newAPTask2;

		APTask__c newAPTask3 = testUtil.createNewActionPlanTask(actionPlan, 2, actionPlan.OwnerId, 'Email', null);
		newAPTask3.TaskIndex__c = 2;
		newAPTask3.Dependent__c = '1';
		newAPTask3.Controller__c = newAPTask2.Id;
		upsert newAPTask3;

		APTask__c newAPTask1 = testUtil.createNewActionPlanTask(actionPlan, 2, actionPlan.OwnerId, 'Email', null);
		newAPTask1.TaskIndex__c = 0;
		newAPTask1.Dependent__c = '2';
		newAPTask1.Controller__c = newAPTask3.Id;
		upsert newAPTask1;

		ActionPlanCreationController apCreateController = new ActionPlanCreationController(new Apexpages.StandardController(actionPlan));

		apCreateController.apTasks = new List<APTask__c>();
		apCreateController.apTasks.add(newAPTask1);
		apCreateController.apTasks.add(newAPTask2);
		apCreateController.apTasks.add(newAPTask3);

		apCreateController.save();

		System.assert(apCreateController.getErrorMsg() == '' || String.isBlank(apCreateController.getErrorMsg()));

		Test.stopTest();
	}

	@IsTest
	private static void cyclicDependencyTasksFail() {
		Test.startTest();

		Test.setCurrentPage(Page.ActionPlanCreation);

		ActionPlansTestUtilities testUtil = new ActionPlansTestUtilities();

		ActionPlan__c actionPlan = testUtil.createNewActionPlan('account', 0);

		APTask__c newAPTask1 = new APTask__c();
		APTask__c newAPTask2 = new APTask__c();
		APTask__c newAPTask3 = new APTask__c();

		newAPTask1.Subject__c = testUtil.createRandomWord('subject');
		newAPTask1.DaysFromStart__c = 2;
		newAPTask1.Dependent__c = '2';
		newAPTask1.Type__c = 'Email';
		newAPTask1.Priority__c = 'High';

		newAPTask2.Subject__c = testUtil.createRandomWord('subject');
		newAPTask2.DaysFromStart__c = 2;
		newAPTask2.Dependent__c = '0';
		newAPTask2.Type__c = 'Email';
		newAPTask2.Priority__c = 'High';

		newAPTask3.Subject__c = testUtil.createRandomWord('subject');
		newAPTask3.DaysFromStart__c = 2;
		newAPTask3.Dependent__c = '1';
		newAPTask3.Type__c = 'Email';
		newAPTask3.Priority__c = 'High';

		ApexPages.currentPage().getParameters().put('id', actionPlan.Id);
		ActionPlanCreationController apCreateController = new ActionPlanCreationController(new Apexpages.StandardController(actionPlan));

		apCreateController.apTasks = new List<APTask__c>();
		apCreateController.apTasks.add(newAPTask1);
		apCreateController.apTasks.add(newAPTask2);
		apCreateController.apTasks.add(newAPTask3);

		apCreateController.save();

		System.assertNotEquals(null, apCreateController.getErrorMsg());

		Test.stopTest();
	}

	@IsTest
	private static void checkReferredObject() {
		Test.startTest();

		Test.setCurrentPage(Page.ActionPlanCreation);

		ActionPlansTestUtilities testUtil = new ActionPlansTestUtilities();

		Contact contact = testUtil.createNewContact();
		Account account = testUtil.createNewAccount();
		Account account2 = testUtil.createNewAccount();
		Lead lead = testUtil.createNewLead();
		Opportunity opportunity = testUtil.createNewOpportunity();
		Case testCase = testUtil.createNewCase();
		Contract contract = testUtil.createNewContract();

		ApexPages.currentPage().getParameters().put('id', null);
		ApexPages.currentPage().getParameters().put('refId', contact.id);
		ApexPages.currentPage().getParameters().put('refType', 'Contact');

		ActionPlanCreationController apCreateController = new ActionPlanCreationController(new Apexpages.StandardController(new ActionPlan__c()));
		apCreateController.referedObjectInit();
		System.assertEquals('Contact', apCreateController.refType);
		String contactName = [SELECT Name FROM Contact LIMIT 1].Name;

		System.assert(apCreateController.relatedObjNameList.size() == 1);
		System.assert(apCreateController.relatedObjNameList[0].containsIgnoreCase(contactName));

		ApexPages.currentPage().getParameters().put('id', null);
		ApexPages.currentPage().getParameters().put('refId', account.Id + ',' + account2.Id);
		ApexPages.currentPage().getParameters().put('refType', null);

		apCreateController = new ActionPlanCreationController(new Apexpages.StandardController(new ActionPlan__c()));
		apCreateController.referedObjectInit();
		System.assertEquals('Account', apCreateController.refType);

		System.assert(apCreateController.relatedObjNameList.size() == 2);

		ApexPages.currentPage().getParameters().put('id', null);
		ApexPages.currentPage().getParameters().put('refId', lead.Id);
		ApexPages.currentPage().getParameters().put('refType', 'Lead');

		apCreateController = new ActionPlanCreationController(new Apexpages.StandardController(new ActionPlan__c()));
		apCreateController.referedObjectInit();

		System.assert(apCreateController.relatedObjNameList.size() == 1);

		ApexPages.currentPage().getParameters().put('id', null);
		ApexPages.currentPage().getParameters().put('refId', opportunity.Id);
		ApexPages.currentPage().getParameters().put('refType', 'Opportunity');

		apCreateController = new ActionPlanCreationController(new Apexpages.StandardController(new ActionPlan__c()));
		apCreateController.referedObjectInit();

		ApexPages.currentPage().getParameters().put('id', null);
		ApexPages.currentPage().getParameters().put('refId', testCase.Id);
		ApexPages.currentPage().getParameters().put('refType', 'Case');

		apCreateController = new ActionPlanCreationController(new Apexpages.StandardController(new ActionPlan__c()));
		apCreateController.referedObjectInit();

		System.assertEquals(1, apCreateController.relatedObjNameList.size());

		ApexPages.currentPage().getParameters().put('id', null);
		ApexPages.currentPage().getParameters().put('refId', contract.Id);
		ApexPages.currentPage().getParameters().put('refType', 'Contract');

		apCreateController = new ActionPlanCreationController(new Apexpages.StandardController(new ActionPlan__c()));
		apCreateController.referedObjectInit();

		Test.stopTest();

		System.assertEquals(1, apCreateController.relatedObjNameList.size());
	}

	@IsTest
	private static void setTaskRecordType() {
		ActionPlansTestUtilities.forceHasRecordType = true;

		ActionPlansTestUtilities testutil = new ActionPlansTestUtilities();
		ActionPlan__c ap = testutil.createNewActionPlan('contact', 5);

		Test.startTest();
		Test.setCurrentPage(Page.ActionPlanCreation);
		ApexPages.currentPage().getParameters().put('id', ap.Id);
		ActionPlanCreationController apCreateController = new ActionPlanCreationController(new Apexpages.StandardController(new ActionPlan__c()));

		apCreateController.actionPlan.Name = testutil.createRandomWord('APName');
		apCreateController.actionPlan.StartDate__c = Date.today();
		apCreateController.actionPlan.OwnerId = Userinfo.getUserId();
		apCreateController.refreshRelatedObjectsLookUp();
		apCreateController.actionPlan.TaskRecordTypeID__c = apCreateController.getDefaultTaskRecordTypeId();
		apCreateController.actionPlan.SkipWeekends__c = true;
		apCreateController.actionPlan.SkipDay__c = 'Start of next week';

		apCreateController.addTask();
		APTask__c newAPTask = apCreateController.addedTask;
		newAPTask.Subject__c = testutil.createRandomWord('subject');
		newAPTask.DaysFromStart__c = 1;
		newAPTask.User__c = UserInfo.getUserId();
		newAPTask.Type__c = 'Meeting';
		newAPTask.Priority__c = 'Normal';
		newAPTask.Minutes_Reminder__c = '510';
		apCreateController.apTasks.add(newAPTask);
		apCreateController.save();
		Test.stopTest();
		APTask__c testAPTask = [SELECT Id, Task_RecordTypeId__c, Action_Plan__c FROM APTask__c LIMIT 1];
		System.assertNotEquals(null, testAPTask.Task_RecordTypeId__c, 'Even a master record type should have been set');
		System.assertNotEquals(null, testAPTask.Action_Plan__c, 'The APTask requires an Action Plan');
	}

	@IsTest
	private static void forceRecordTypes() {
		ActionPlansTestUtilities.forceHasRecordType = true;

		ActionPlansTestUtilities testutil = new ActionPlansTestUtilities();
		ActionPlan__c actionPlan = testutil.createNewActionPlan('contact', 2);

		Test.startTest();
		Test.setCurrentPage(Page.ActionPlanCreation);
		ApexPages.currentPage().getParameters().put('id', actionPlan.Id);
		ActionPlanCreationController apCreateController = new ActionPlanCreationController(new Apexpages.StandardController(actionPlan));

		Test.stopTest();
		//System.assertEquals(null, apCreateController.getDefaultTaskRecordTypeId());
		System.assert(apCreateController.taskHasRecordType);
	}

	@IsTest
	private static void forceNoRecordTypes() {
		ActionPlansTestUtilities.forceHasRecordType = false;

		ActionPlansUtilities.getTaskRecordTypeStatusDefaultValues();
		ActionPlansUtilities.getTaskRecordTypePriorityDefaultValues();

		Test.startTest();

		ActionPlansTestUtilities testutil = new ActionPlansTestUtilities();

		Test.setCurrentPage(Page.ActionPlanCreation);

		ActionPlan__c actionPlan = testutil.createNewActionPlan('contact', 2);

		ApexPages.currentPage().getParameters().put('id', actionPlan.Id);
		ActionPlanCreationController apCreateController = new ActionPlanCreationController(new Apexpages.StandardController(actionPlan));

		Test.stopTest();
		System.assertEquals(null, apCreateController.getDefaultTaskRecordTypeId());

		System.assert(!ActionPlansUtilities.taskUsesRecordTypes);
	}

	@IsTest
	private static void checkMaxTasks() {
		Test.startTest();
		Test.setCurrentPage(Page.ActionPlanCreation);

		ActionPlansTestUtilities testUtil = new ActionPlansTestUtilities();
		ActionPlan__c actionPlan = testUtil.createNewActionPlan('account', ActionPlansUtilities.MAX_APTASKS);

		ActionPlanCreationController apCreateController = new ActionPlanCreationController(new Apexpages.StandardController(actionPlan));
		System.assertNotEquals(null, apCreateController.relatedFieldName, 'should have lazy loaded relatedFieldName');
		System.assert(apCreateController.relatedFieldName.endsWithIgnoreCase('Account__c'), 'Should relate Account to Action Plan');

		apCreateController = new ActionPlanCreationController(new Apexpages.StandardController(actionPlan));
		apCreateController.save();
		Test.stopTest();
	}

	@IsTest
	private static void checkMaxTasksError() {
		Test.startTest();
		Test.setCurrentPage(Page.ActionPlanCreation);

		ActionPlansTestUtilities testUtil = new ActionPlansTestUtilities();
		ActionPlan__c actionPlan = testUtil.createNewActionPlan('account', ActionPlansUtilities.MAX_APTASKS + 1);

		ActionPlanCreationController apCreateController = new ActionPlanCreationController(new Apexpages.StandardController(actionPlan));
		System.assertNotEquals(null, apCreateController.relatedFieldName, 'should have lazy loaded relatedFieldName');
		System.assert(apCreateController.relatedFieldName.endsWithIgnoreCase('Account__c'), 'Should relate Account to Action Plan');

		apCreateController = new ActionPlanCreationController(new Apexpages.StandardController(actionPlan));
		apCreateController.getTasks();
		apCreateController.addTask();
		Test.stopTest();
		String errorMsg = apCreateController.getErrorMsg();
		//System.debug(errorMsg);
		//System.debug(String.valueof(ActionPlansUtilities.MAX_APTASKS));
		System.assert(errorMsg.containsIgnoreCase(String.valueOf(ActionPlansUtilities.MAX_APTASKS)));
	}
}