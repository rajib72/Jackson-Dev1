public class MaterialMasterBatch implements Database.Batchable<MaterialMasterController.MaterialWrapper>, Database.Stateful {

    List<MaterialMasterController.MaterialWrapper> materials;
    Id runningUserId;

    Integer successCount = 0;
    Integer errorCount = 0;

    List<String> errorMessages = new List<String>();


    public MaterialMasterBatch(List<MaterialMasterController.MaterialWrapper> materials, Id userId){
        this.materials = materials;
        this.runningUserId = userId;
    }


    public Iterable<MaterialMasterController.MaterialWrapper> start(Database.BatchableContext bc){
        return materials;
    }


    public void execute(Database.BatchableContext bc, List<MaterialMasterController.MaterialWrapper> scope){

        Set<String> uniqueKeys = new Set<String>();

        for(MaterialMasterController.MaterialWrapper m : scope){

            String key = MaterialMasterController.generateUniqueKey(m);

            if(key != null){
                uniqueKeys.add(key);
            }
        }


        Map<String,Material_Master__c> existingMap = new Map<String,Material_Master__c>();

        for(Material_Master__c mm : [
            SELECT Id, Unique_Key__c
            FROM Material_Master__c
            WHERE Unique_Key__c IN :uniqueKeys
        ]){
            existingMap.put(mm.Unique_Key__c, mm);
        }


        Set<String> processedKeys = new Set<String>();

        List<Material_Master__c> recordsToInsert = new List<Material_Master__c>();


        for(MaterialMasterController.MaterialWrapper m : scope){

            String key = MaterialMasterController.generateUniqueKey(m);

            if(key == null){
                continue;
            }

            if(!existingMap.containsKey(key) && !processedKeys.contains(key)){

                processedKeys.add(key);

                Material_Master__c rec = new Material_Master__c();

                rec.Name = m.MATERIAL_CODE;
                rec.Unique_Key__c = key;

                rec.Created_By__c = m.CREATED_BY;
                rec.Created_On__c = m.CREATED_ON;
                rec.Distribution_Channel__c = m.DISTRIBUTION_CHANNEL;
                rec.Division__c = m.DIVISION;
                rec.Material_Description__c = m.MATERIAL_DESCRIPTION;
                rec.Material_Group__c = m.MATERIAL_GROUP;
                rec.Material_Group_Description__c = m.MATERIAL_GROUP_DESCRIPTION;
                rec.Material_Type__c = m.MATERIAL_TYPE;
                rec.Material_Type_Description__c = m.MATERIAL_TYPE_DESCRIPTION;
                rec.Plant__c = m.PLANT;
                rec.Plant_Description__c = m.PLANT_DESCRIPTION;
                rec.Sales_Org__c = m.SALES_ORG;
                rec.Unit_of_Measure__c = m.UNIT_OF_MEASURE;
                rec.Storage_Location__c = m.STORAGE_LOCATION;
                rec.Storage_Location_Description__c = m.STORAGE_LOCATION_DESCRIPTION;

                recordsToInsert.add(rec);
            }
        }


        if(!recordsToInsert.isEmpty()){

            Database.SaveResult[] results = Database.insert(recordsToInsert, false);

            for(Database.SaveResult sr : results){

                if(sr.isSuccess()){
                    successCount++;
                }
                else{

                    errorCount++;

                    for(Database.Error err : sr.getErrors()){
                        errorMessages.add(err.getMessage());
                    }
                }
            }
        }

    }



    public void finish(Database.BatchableContext bc){

        User u = [SELECT Email FROM User WHERE Id = :runningUserId LIMIT 1];

        String body = 'Material Master Batch Completed\n\n';

        body += 'Successful Inserts: ' + successCount + '\n';
        body += 'Failed Inserts: ' + errorCount + '\n\n';

        if(!errorMessages.isEmpty()){

            body += 'Errors:\n';

            for(String err : errorMessages){
                body += err + '\n';
            }
        }


        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();

        mail.setToAddresses(new List<String>{u.Email});
        mail.setSubject('Material Master Batch Processing Result');
        mail.setPlainTextBody(body);

        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });

    }

}