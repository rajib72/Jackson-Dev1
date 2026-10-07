public with sharing class Ctrl_FetchTagMaterialToQuoteLineItem {

    public class SapMaterialDTO {
        @AuraEnabled public String MATERIAL_CODE;
        @AuraEnabled public String MATERIAL_DESCRIPTION;
        @AuraEnabled public String CREATED_ON;
        @AuraEnabled public String CREATED_BY;
        @AuraEnabled public String MATERIAL_GROUP;
        @AuraEnabled public String MATERIAL_GROUP_DESCRIPTION;
        @AuraEnabled public String UNIT_OF_MEASURE;
        @AuraEnabled public String MATERIAL_TYPE;
        @AuraEnabled public String MATERIAL_TYPE_DESCRIPTION;
        @AuraEnabled public String PLANT;
        @AuraEnabled public String PLANT_DESCRIPTION;
        @AuraEnabled public String STORAGE_LOCATION;
        @AuraEnabled public String STORAGE_LOCATION_DESCRIPTION;
        @AuraEnabled public String SALES_ORG;
        @AuraEnabled public String DISTRIBUTION_CHANNEL;
        @AuraEnabled public String DISTTRIBUTION_CHANNEL_DESC;
        @AuraEnabled public String DIVISION;
        @AuraEnabled public String DIVISION_DESCRIPTION;
    }

    @AuraEnabled
    public static List<SapMaterialDTO> getMaterialsFromSAP(String materialCode) {
        if (String.isBlank(materialCode)) {
            throw new AuraHandledException('Material Code is required.');
        }

        try {
            return callMaterialCodeApi(materialCode);
        } catch (Exception ex) {
            throw new AuraHandledException('Integration Error: ' + ex.getMessage());
        }
    }

    @AuraEnabled
    public static List<SapMaterialDTO> getMaterialsByDescriptionFromSAP(String materialDescription) {
        if (String.isBlank(materialDescription)) {
            throw new AuraHandledException('Material Description is required.');
        }

        try {
            return callMaterialDescriptionApi(materialDescription);
        } catch (Exception ex) {
            throw new AuraHandledException('Description Integration Error: ' + ex.getMessage());
        }
    }

    @AuraEnabled
    public static void saveAndLinkMaterial(
        String selectedMaterialJson,
        Id quoteLineItemId,
        String searchMode
    ) {
        try {
            if (String.isBlank(selectedMaterialJson)) {
                throw new AuraHandledException('Selected material details are missing.');
            }

            if (quoteLineItemId == null) {
                throw new AuraHandledException('Quote Line Item Id is missing.');
            }

            SapMaterialDTO dto = (SapMaterialDTO) JSON.deserialize(
                selectedMaterialJson,
                SapMaterialDTO.class
            );

            if (String.isBlank(searchMode)) {
                searchMode = 'CODE';
            }

            if (searchMode == 'DESCRIPTION') {
                saveAndLinkMaterialByDescription(dto, quoteLineItemId);
            } else {
                saveAndLinkMaterialByCode(dto, quoteLineItemId);
            }

        } catch (AuraHandledException ex) {
            throw ex;
        } catch (Exception ex) {
            throw new AuraHandledException('Error saving and linking material: ' + ex.getMessage());
        }
    }

    private static void saveAndLinkMaterialByCode(
        SapMaterialDTO dto,
        Id quoteLineItemId
    ) {
        if (dto == null || String.isBlank(dto.MATERIAL_CODE)) {
            throw new AuraHandledException('Selected material code is missing.');
        }

        Material_Master__c materialRec = upsertSingleMaterial(dto);

        linkMaterialToQuoteLineItem(materialRec.Id, quoteLineItemId);
    }

    private static void saveAndLinkMaterialByDescription(
        SapMaterialDTO selectedDto,
        Id quoteLineItemId
    ) {
        if (selectedDto == null) {
            throw new AuraHandledException('Selected material details are missing.');
        }

        String selectedDescription = safeValue(selectedDto.MATERIAL_DESCRIPTION);
        String selectedMaterialCode = safeValue(selectedDto.MATERIAL_CODE);

        if (String.isBlank(selectedDescription)) {
            throw new AuraHandledException('Selected material description is missing.');
        }

        Material_Master__c existingByDescription = findMaterialByDescription(selectedDescription);

        if (existingByDescription != null) {
            linkMaterialToQuoteLineItem(existingByDescription.Id, quoteLineItemId);
            return;
        }

        if (String.isBlank(selectedMaterialCode)) {
            throw new AuraHandledException(
                'Material is not available in Salesforce and selected SAP material code is missing.'
            );
        }

        List<SapMaterialDTO> fullMaterialDetails = callMaterialCodeApi(selectedMaterialCode);

        if (fullMaterialDetails == null || fullMaterialDetails.isEmpty()) {
            throw new AuraHandledException(
                'Material not found in Salesforce and full material details were not returned by SAP.'
            );
        }

        List<Material_Master__c> materialRecordsToUpsert = new List<Material_Master__c>();

        for (SapMaterialDTO fullDto : fullMaterialDetails) {
            if (fullDto == null) {
                continue;
            }

            if (String.isBlank(fullDto.MATERIAL_DESCRIPTION)) {
                fullDto.MATERIAL_DESCRIPTION = selectedDescription;
            }

            materialRecordsToUpsert.add(buildMaterialMasterRecord(fullDto));
        }

        if (!materialRecordsToUpsert.isEmpty()) {
            upsert materialRecordsToUpsert Unique_Key__c;
        }

        Material_Master__c insertedByDescription = findMaterialByDescription(selectedDescription);

        if (insertedByDescription != null) {
            linkMaterialToQuoteLineItem(insertedByDescription.Id, quoteLineItemId);
            return;
        }

        Material_Master__c fallbackMaterial = findMaterialByCode(selectedMaterialCode);

        if (fallbackMaterial != null) {
            linkMaterialToQuoteLineItem(fallbackMaterial.Id, quoteLineItemId);
            return;
        }

        throw new AuraHandledException(
            'Material was fetched from SAP but could not be matched in Salesforce by description.'
        );
    }

    private static List<SapMaterialDTO> callMaterialCodeApi(String materialCode) {
        String endpointName = 'callout:NC_SAP_API/http/rfcMatMast';

        Map<String, Object> requestBody = new Map<String, Object>();
        requestBody.put('MATERIAL_CODE', materialCode.trim());

        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpointName);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(120000);
        req.setBody(JSON.serialize(requestBody));

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() != 200 || String.isBlank(res.getBody())) {
            throw new AuraHandledException(
                'Failed to retrieve material data from SAP. Status Code: ' + res.getStatusCode()
            );
        }

        return (List<SapMaterialDTO>) JSON.deserialize(
            res.getBody(),
            List<SapMaterialDTO>.class
        );
    }

    private static List<SapMaterialDTO> callMaterialDescriptionApi(String materialDescription) {
        String endpointName = 'callout:NC_SAP_API/http/descMat';

        Map<String, Object> requestBody = new Map<String, Object>();
        requestBody.put('MATERIAL_DESCRIPTION', materialDescription.trim().toUpperCase());

        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpointName);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(120000);
        req.setBody(JSON.serialize(requestBody));

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() != 200 || String.isBlank(res.getBody())) {
            throw new AuraHandledException(
                'Failed to retrieve material description data from SAP. Status Code: ' +
                res.getStatusCode()
            );
        }

        return parseDescriptionXmlResponse(res.getBody());
    }

    private static List<SapMaterialDTO> parseDescriptionXmlResponse(String xmlBody) {
        List<SapMaterialDTO> materials = new List<SapMaterialDTO>();

        if (String.isBlank(xmlBody)) {
            return materials;
        }

        Dom.Document doc = new Dom.Document();
        doc.load(xmlBody);

        Dom.XmlNode root = doc.getRootElement();

        collectDescriptionItems(root, materials);

        return materials;
    }

    private static void collectDescriptionItems(
        Dom.XmlNode currentNode,
        List<SapMaterialDTO> materials
    ) {
        if (currentNode == null) {
            return;
        }

        if (currentNode.getName() != null && currentNode.getName().equalsIgnoreCase('item')) {
            SapMaterialDTO dto = new SapMaterialDTO();

            for (Dom.XmlNode child : currentNode.getChildElements()) {
                String childName = child.getName();

                if (String.isBlank(childName)) {
                    continue;
                }

                if (childName.equalsIgnoreCase('MATERIAL')) {
                    dto.MATERIAL_CODE = child.getText();
                } else if (childName.equalsIgnoreCase('DESCRIPTION')) {
                    dto.MATERIAL_DESCRIPTION = child.getText();
                }
            }

            if (!String.isBlank(dto.MATERIAL_CODE) || !String.isBlank(dto.MATERIAL_DESCRIPTION)) {
                materials.add(dto);
            }

            return;
        }

        for (Dom.XmlNode childNode : currentNode.getChildElements()) {
            collectDescriptionItems(childNode, materials);
        }
    }

    private static Material_Master__c upsertSingleMaterial(SapMaterialDTO dto) {
        String uniqueKey = generateUniqueKey(dto);

        List<Material_Master__c> existingList = [
            SELECT Id, Unique_Key__c
            FROM Material_Master__c
            WHERE Unique_Key__c = :uniqueKey
            LIMIT 1
        ];

        Material_Master__c materialRec;

        if (existingList.isEmpty()) {
            materialRec = buildMaterialMasterRecord(dto);
        } else {
            materialRec = existingList[0];
            mapDtoToMaterialMaster(dto, materialRec);
        }

        upsert materialRec;

        return materialRec;
    }

    private static Material_Master__c buildMaterialMasterRecord(SapMaterialDTO dto) {
        Material_Master__c materialRec = new Material_Master__c();
        mapDtoToMaterialMaster(dto, materialRec);
        return materialRec;
    }

    private static void mapDtoToMaterialMaster(
        SapMaterialDTO dto,
        Material_Master__c materialRec
    ) {
        materialRec.Name = safeValue(dto.MATERIAL_CODE);
        materialRec.Unique_Key__c = generateUniqueKey(dto);
        materialRec.Created_By__c = safeValue(dto.CREATED_BY);
        materialRec.Created_On__c = dto.CREATED_ON;
        materialRec.Distribution_Channel__c = safeValue(dto.DISTRIBUTION_CHANNEL);
        materialRec.Division__c = safeValue(dto.DIVISION);
        materialRec.Material_Description__c = safeValue(dto.MATERIAL_DESCRIPTION);
        materialRec.Material_Group__c = safeValue(dto.MATERIAL_GROUP);
        materialRec.Material_Group_Description__c = safeValue(dto.MATERIAL_GROUP_DESCRIPTION);
        materialRec.Material_Type__c = safeValue(dto.MATERIAL_TYPE);
        materialRec.Material_Type_Description__c = safeValue(dto.MATERIAL_TYPE_DESCRIPTION);
        materialRec.Plant__c = safeValue(dto.PLANT);
        materialRec.Plant_Description__c = safeValue(dto.PLANT_DESCRIPTION);
        materialRec.Sales_Org__c = safeValue(dto.SALES_ORG);
        materialRec.Storage_Location__c = safeValue(dto.STORAGE_LOCATION);
        materialRec.Storage_Location_Description__c = safeValue(dto.STORAGE_LOCATION_DESCRIPTION);
        materialRec.Unit_of_Measure__c = safeValue(dto.UNIT_OF_MEASURE);
    }

    private static Material_Master__c findMaterialByDescription(String materialDescription) {
        if (String.isBlank(materialDescription)) {
            return null;
        }

        List<Material_Master__c> materialList = [
            SELECT Id, Name, Material_Description__c
            FROM Material_Master__c
            WHERE Material_Description__c = :materialDescription
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];

        return materialList.isEmpty() ? null : materialList[0];
    }

    private static Material_Master__c findMaterialByCode(String materialCode) {
        if (String.isBlank(materialCode)) {
            return null;
        }

        List<Material_Master__c> materialList = [
            SELECT Id, Name, Material_Description__c
            FROM Material_Master__c
            WHERE Name = :materialCode
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];

        return materialList.isEmpty() ? null : materialList[0];
    }

    private static void linkMaterialToQuoteLineItem(
        Id materialMasterId,
        Id quoteLineItemId
    ) {
        if (materialMasterId == null || quoteLineItemId == null) {
            throw new AuraHandledException('Material or Quote Line Item Id is missing.');
        }

        QuoteLineItem qli = new QuoteLineItem(Id = quoteLineItemId);
        qli.Material_Master__c = materialMasterId;
        update qli;
    }

    private static String generateUniqueKey(SapMaterialDTO dto) {
        if (dto == null) {
            return '';
        }

        return safeValue(dto.MATERIAL_CODE) + '|' +
            safeValue(dto.PLANT) + '|' +
            safeValue(dto.STORAGE_LOCATION) + '|' +
            safeValue(dto.SALES_ORG) + '|' +
            safeValue(dto.DISTRIBUTION_CHANNEL) + '|' +
            safeValue(dto.DIVISION);
    }

    private static String safeValue(String input) {
        return input == null ? '' : input.trim();
    }
}