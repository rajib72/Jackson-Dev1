public with sharing class HOTOChecklistController {

    public class InitWrapper {
        @AuraEnabled public Map<String, String> projectInfo { get; set; }
        @AuraEnabled public List<ChecklistRowDTO> rows { get; set; }
        @AuraEnabled public Boolean hasMoreRows { get; set; } 
    }

    public class ChecklistRowDTO {
        @AuraEnabled public String section { get; set; }
        @AuraEnabled public Integer rowNumber { get; set; }
        @AuraEnabled public Integer globalIndex { get; set; }
        @AuraEnabled public String recordId { get; set; }
        @AuraEnabled public String fieldApi { get; set; }
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String remarkField { get; set; }
        @AuraEnabled public String statusField { get; set; }
        @AuraEnabled public Boolean checked { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public String remark { get; set; }
        @AuraEnabled public List<String> fileNames { get; set; }
        @AuraEnabled public String fileNamesText { get; set; }
        @AuraEnabled public Boolean hasFiles { get; set; }
        @AuraEnabled public List<String> documentIds { get; set; }
    }

    private class ChecklistDef {
        String section;
        Integer index;
        String fieldApi;
        String label;

        ChecklistDef(String sec, Integer idx, String fApi, String lbl) {
            section = sec;
            index = idx;
            fieldApi = fApi;
            label = lbl;
        }
    }

    private static final List<ChecklistDef> CHECKLIST_DEFS = new List<ChecklistDef>{
        // CIVIL Work
        new ChecklistDef('CIVIL Work', 1, 'Approved_Civil_Drawings_GA_Foundation__c', 'Approved Civil Drawings (GA, Foundation, RCC, Trenches)'),
        new ChecklistDef('CIVIL Work', 2, 'As_per_Drawing_L_x_B_x_H__c', 'As per Drawing ((L x B x H)'),
        new ChecklistDef('CIVIL Work', 3, 'Foundation_Layout_Approved__c', 'Foundation Layout Approved'),
        new ChecklistDef('CIVIL Work', 4, 'Size_of_Civil_foundation__c', 'Size of Civil foundation'),
        new ChecklistDef('CIVIL Work', 5, 'Cube_Test_Reports__c', 'Cube Test Reports'),
        new ChecklistDef('CIVIL Work', 6, 'MaterialTestCert_Cement_Steel_Aggregate__c', 'Material Test Certificates (Cement, Steel, Aggregates)'),
        new ChecklistDef('CIVIL Work', 7, 'Backfilling_Compaction__c', 'Backfilling & Compaction'),
        new ChecklistDef('CIVIL Work', 8, 'Site_Compacted_Level_Verified__c', 'Site Compacted & Level Verified'),
        new ChecklistDef('CIVIL Work', 9, 'No_Water_Logging_Observed__c', 'No Water Logging Observed'),
        new ChecklistDef('CIVIL Work', 10, 'Foundation_Location_as_per_Layout__c', 'Foundation Location as per Layout'),
        new ChecklistDef('CIVIL Work', 11, 'Alignment_Row_Spacing_Verified__c', 'Alignment & Row Spacing Verified'),
        new ChecklistDef('CIVIL Work', 12, 'Foundation_Top_Level_Checked__c', 'Foundation Top Level Checked'),
        new ChecklistDef('CIVIL Work', 13, 'AnchorBoltsPosition_AlignmentVerified__c', 'Anchor Bolts Position & Alignment Verified'),
        new ChecklistDef('CIVIL Work', 14, 'Bolt_Tightening_Done__c', 'Bolt Tightening Done'),
        new ChecklistDef('CIVIL Work', 15, 'Curing_Records_Available__c', 'Curing Records Available'),
        new ChecklistDef('CIVIL Work', 16, 'No_Cracks_Honeycombing__c', 'No Cracks / Honeycombing'),
        new ChecklistDef('CIVIL Work', 17, 'Inverter_Foundation_Dimensions_Verified__c', 'Inverter Foundation Dimensions Verified'),
        new ChecklistDef('CIVIL Work', 18, 'Number_of_foundations__c', 'Number of foundations'),
        new ChecklistDef('CIVIL Work', 19, 'White_washing_of_the_pedestal_done__c', 'White washing of the pedestal done'),
        new ChecklistDef('CIVIL Work', 20, 'No_gap_between_pedestal_and_floor__c', 'No gap between pedestal and floor'),
        new ChecklistDef('CIVIL Work', 21, 'Ladder_as_per_requirement__c', 'Ladder as per requirement'),
        new ChecklistDef('CIVIL Work', 22, 'Nitobond_Application_as_per_requirement__c', 'Nitobond Application as per requirement.'),
        
        // MMS Structure
        new ChecklistDef('MMS Structure', 23, 'MMS_installed_as_per_design__c', 'MMS installed as per design'),
        new ChecklistDef('MMS Structure', 24, 'MMS_Aligment__c', 'MMS Aligment'),
        new ChecklistDef('MMS Structure', 25, 'ProperTighteningTheNutBoltsInFoundation__c', 'Proper tightening of the Nut Bolts in foundation and structure'),
        new ChecklistDef('MMS Structure', 26, 'FinalTorquingMarkWithPermanentMarkerNuts__c', 'Final torquing mark with permanent marker on all structure nuts & bolts'),
        new ChecklistDef('MMS Structure', 27, 'Tilt_Angle_of_the_panels__c', 'Tilt Angle of the panels'),
        new ChecklistDef('MMS Structure', 28, 'Structure_Horizontal_alignment__c', 'Structure Horizontal alignment'),
        new ChecklistDef('MMS Structure', 29, 'Tieting_of_proper_module__c', 'Tieting of proper module'),
        new ChecklistDef('MMS Structure', 30, 'Gaps_between_panels_as_per_drawing__c', 'Gaps between panels as per drawing'),
        new ChecklistDef('MMS Structure', 31, 'Module_status_if_any_damages_etc__c', 'Module status (if any damages etc.)'),
        new ChecklistDef('MMS Structure', 32, 'CanopySuitableToProtectSunlightAndRain__c', 'Canopy suitable to protect direct sunlight and rain showers from top as well as from sides.'),
        
        // Water Cleaning System
        new ChecklistDef('Water Cleaning System', 33, 'Water_Pump_installed__c', 'Water Pump installed'),
        new ChecklistDef('Water Cleaning System', 34, 'PumpCableLayingDoneInconduitAndOnStub__c', 'Pump cable laying done inconduit and on stub'),
        new ChecklistDef('Water Cleaning System', 35, 'Whether_installed_separate_water_tank__c', 'Whether installed separate water tank'),
        new ChecklistDef('Water Cleaning System', 36, 'Capacity_of_tank__c', 'Capacity of tank'),
        new ChecklistDef('Water Cleaning System', 37, 'Proper_Canopy_for_Pump_installed__c', 'Proper Canopy for Pump installed'),
        new ChecklistDef('Water Cleaning System', 38, 'Plumbing_Network_as_per_drawing__c', 'Plumbing Network as per drawing'),
        new ChecklistDef('Water Cleaning System', 39, 'AvailabiltyNozzleWithValveCoveringPlant__c', 'Availabilty of nozzlewith valve covering whole plant'),
        new ChecklistDef('Water Cleaning System', 40, 'SufficientWaterPressureAtTheEndOfWTRPipe__c', 'Sufficient water pressure at the end of water pipe network as well as last panel'),
        
        // DC Electricals
        new ChecklistDef('DC Electricals', 41, 'CableLayingThrough_HDPE_Conduit_GI_Cable__c', 'Cable laying through HDPE conduit / GI cable tray with proper clamping & cover routing and dressing'),
        new ChecklistDef('DC Electricals', 42, 'Cable_used_is_multistrand_copper_FRLS__c', 'Cable used is multistrand copper FRLS'),
        new ChecklistDef('DC Electricals', 43, 'Ferrule_marking_on_both_cable_ends__c', 'Ferrule marking on both cable ends'),
        new ChecklistDef('DC Electricals', 44, 'Connector_tightness_and_damage__c', 'Connector tightness and damage'),
        new ChecklistDef('DC Electricals', 45, 'Both_ends_of_pipe_sealed_with_foam__c', 'Both ends of pipe sealed with foam'),
        new ChecklistDef('DC Electricals', 46, 'CableJointsMadeThroughHeatShrinkSleeves__c', 'Cable joints made through heat shrink sleeves and hygroscopically sealed with proper marking'),
        new ChecklistDef('DC Electricals', 47, 'MP4ConnectorsTightnessAndCheckContinuity__c', 'MP4 connectors tightness and check of continuity'),
        
        // AC Electricals
        new ChecklistDef('AC Electricals', 48, 'SurfaceCableLayingThroughCableTrayCover__c', 'Surface Cable laying through cable tray with cover and proper clamping on stub for ground support'),
        new ChecklistDef('AC Electricals', 49, 'InCaseOfUnderGround_ConfirmLayingHumePip__c', 'in case of under ground, confirm laying in Hume pipes with both ends sealed'),
        new ChecklistDef('AC Electricals', 50, 'Road_crossing_for_buried_cables__c', 'Road crossing for buried cables'),
        new ChecklistDef('AC Electricals', 51, 'Cable_crossing__c', 'Cable crossing'),
        new ChecklistDef('AC Electricals', 52, 'CableRouteMarkerProvidedForAllBuriedCbl__c', 'Cable route marker provided for all buried cables at specified distance'),
        new ChecklistDef('AC Electricals', 53, 'U_G_cablesLayingWithProperBrick_SND_STN__c', 'U/G cables laying with proper brick, sand and stone pad cover as per standards'),
        new ChecklistDef('AC Electricals', 54, 'Cable_tagging_ferrules_at_both_ends__c', 'Cable tagging & ferrules at both ends'),
        new ChecklistDef('AC Electricals', 55, 'CableClamping_ThermoplasticClampDis_50__c', 'Cable Clamping (Thermoplastic clamp at Distance < 50cm)'),
        new ChecklistDef('AC Electricals', 56, 'CableTerminationOnClientBus_barsWithLugs__c', 'Cable termination on client Bus-bars with proper lugs, colour code sleeve and tightening'),
        new ChecklistDef('AC Electricals', 57, 'SufficientLoopingOfExtraCablesAtBothEnds__c', 'Sufficient looping of extra cables at both ends'),
        new ChecklistDef('AC Electricals', 58, 'NoMultiCablesTerminatedAtSinglePointOnCl__c', 'No multiple cables terminated at single point on client ACDB'),
        new ChecklistDef('AC Electricals', 59, 'No_overlapping_of_AC_and_DC_cables__c', 'No overlapping of AC and DC cables'),
        new ChecklistDef('AC Electricals', 60, 'Separate_layin_of_AC_and_DC_cable__c', 'Separate layin of AC and DC cable'),
        
        // Inverter
        new ChecklistDef('Inverter', 61, 'Inverter_Rating_with_serial_number__c', 'Inverter Rating with serial number'),
        new ChecklistDef('Inverter', 62, 'Number_of_Inverters__c', 'Number of Inverters'),
        new ChecklistDef('Inverter', 63, 'Dongle_is_sync_with_data_loger__c', 'Dongle is sync with data loger'),
        new ChecklistDef('Inverter', 64, 'AllCBlConnectorsAreTightened_RoutedGland__c', 'All cables connectors are properly tightened & routed through glands'),
        new ChecklistDef('Inverter', 65, 'Proper_cross_tagging_of_the_cables__c', 'Proper cross tagging of the cables'),
        new ChecklistDef('Inverter', 66, 'CableEntryInsideInverterInBotton_U_Shape__c', 'Cable entry inside Inverter in proper bottom forming U shape'),
        new ChecklistDef('Inverter', 67, 'InverterDoorOpeningShouldBeAssessible__c', 'Inverter door opening should be properly assessible'),
        new ChecklistDef('Inverter', 68, 'CanopyProvidedForInvrtrWithSufficientOve__c', 'Canopy provided for Inverter with sufficient overhung to protect from top as well as from sides'),
        
        // ACDB
        new ChecklistDef('ACDB', 69, 'Panel_mounting_Indoor_Outdoor__c', 'Panel mounting Indoor/ Outdoor'),
        new ChecklistDef('ACDB', 70, 'Structure_mounted_wall_mounted_ACDB__c', 'Structure mounted / wall mounted ACDB have sufficient space and suitable mounting for heat dissipation arrangement and ease of maintenance'),
        new ChecklistDef('ACDB', 71, 'Secure_fixing_of_ACDB_on_wall_Plinth__c', 'Secure fixing of ACDB on wall/Plinth'),
        new ChecklistDef('ACDB', 72, 'ProtectiveCageProvidedFor_ACDB_If_Req__c', 'Protective Cage provided for ACDB( If required)'),
        new ChecklistDef('ACDB', 73, 'Cable_Amour_to_be_grounded_at_both_end__c', 'Cable Amour to be grounded at both end'),
        new ChecklistDef('ACDB', 74, 'Earthing_connected_at_two_points__c', 'Earthing connected at two points'),
        new ChecklistDef('ACDB', 75, 'All_display_working_at_panel__c', 'All display working at panel'),
        new ChecklistDef('ACDB', 76, 'MultiCblConnectedToBusbarWithGapsInCBLs__c', 'Multiple cables connected to busbar with specified gap in between cables (no overlapping of cables)'),
        
        // Instrumentation & metering
        new ChecklistDef('Instrumentation & metering', 77, 'CIEG_is_done__c', 'CIEG is done'),
        new ChecklistDef('Instrumentation & metering', 78, 'Net_metering_done__c', 'Net metering done.'),
        new ChecklistDef('Instrumentation & metering', 79, 'IfNetMetringNotApplicableZeroExportInst__c', 'If net metring not applicable Zero export installed .'),
        
        // Earthing
        new ChecklistDef('Earthing', 80, 'Number_of_Earthing_as_per_Drawing__c', 'Number of Earthing as per Drawing'),
        new ChecklistDef('Earthing', 81, 'AlternateEarthPathProvidedForEachStruct__c', 'Alternate earth path provided for each structure and equipment'),
        new ChecklistDef('Earthing', 82, 'GIEarthStripOnInsulator_T_JointWithSuppo__c', 'GI Earth strip on insulator & T joint with cross support'),
        new ChecklistDef('Earthing', 83, 'GIEarthStripJointsAreWeldedWithOverOf150__c', 'GI Earth strip joints are welded with overlap of min 150 mm'),
        new ChecklistDef('Earthing', 84, 'Earthing_conductor_buried_and_embedded__c', 'Earthing conductor buried and embedded'),
        new ChecklistDef('Earthing', 85, 'Earthing_pit_marked_with_resistanceValue__c', 'Earthing pit marked with resistance value'),
        new ChecklistDef('Earthing', 86, 'ProvidedWithSufficientClamping_support__c', 'Provided with sufficient Clamping/support in case of routing through wall, column etc.'),
        new ChecklistDef('Earthing', 87, 'Earth_chamber_size_as_per_specification__c', 'Earth chamber size as per specification'),
        new ChecklistDef('Earthing', 88, 'NoOverlappingOfEarthStripWith_DC_AC_Cbl__c', 'No overlapping of Earth strip with DC/ AC cable'),
        new ChecklistDef('Earthing', 89, 'NoClientEarthStrip_PitHasBeenUsed_If_Rq__c', 'No client earth strip/ pit has been used( If Required)'),
        new ChecklistDef('Earthing', 90, 'OvelappingWithOtherEartStripSeperatedBy__c', 'Ovelapping with other eart strip seperated by insulators'),
        
        // Lightening Arrestor
        new ChecklistDef('Lightening Arrestor', 91, 'Type_of_LA_and_Make_MOV_Franklin_RodType__c', 'Type of LA and Make, MOV/Franklin Rod type'),
        new ChecklistDef('Lightening Arrestor', 92, 'LAShould_placedAtTheHighestPointCoverage__c', 'LA should placed at the highest point of coverage area( As per drawing)'),
        new ChecklistDef('Lightening Arrestor', 93, 'Proper_earthing_done_fior_LA__c', 'Proper earthing done fior LA'),
        
        // Safety
        new ChecklistDef('Safety', 94, 'InstallationOfFireExtinguishersAsPerSafe__c', 'Installation of Fire Extinguishers as per safety norms (separate incase of ACDB and inverter placed at distance)'),
        new ChecklistDef('Safety', 95, 'DangerBoardInstalledAtHighVol_AC__c', 'Danger Board installed at proper places for high voltage AC (Inverter, ACDB)'),
        new ChecklistDef('Safety', 96, 'DangerBoardInstalledAtPlacesHighVol_DC__c', 'Danger Board installed at proper places for high voltage DC (AJB/DCDB, Inverter etc.)'),
        new ChecklistDef('Safety', 97, 'RadiumStickersProvidedOnStructureInFront__c', 'Radium stickers provided on structure in front of entrance'),
        new ChecklistDef('Safety', 98, 'Are_emergency_contact_numbers_displayed__c', 'Are emergency contact numbers displayed?'),
        new ChecklistDef('Safety', 99, 'First_Module_Cleaning__c', 'First Module Cleaning'),
        new ChecklistDef('Safety', 100, 'House_Keeping_Cleaning_of_site__c', 'House Keeping & Cleaning of site'),
        new ChecklistDef('Safety', 101, 'Cage_work_for_meters_if_required__c', 'Cage work for meters, if required'),
        new ChecklistDef('Safety', 102, 'LifeLineAvailbleToAnchorSafteyHarness__c', 'Life line availble to anchor saftey harness during panel cleaning for panel height > 1.8 Meter'),
        new ChecklistDef('Safety', 103, 'All_damage_material_removed_in_site__c', 'All damage material removed in site.'),
        
        // SCADA & Monitoring
        new ChecklistDef('SCADA & Monitoring', 104, 'Data_Logger_Installed__c', 'Data Logger Installed'),
        new ChecklistDef('SCADA & Monitoring', 105, 'Communication_Cable_Tested__c', 'Communication Cable Tested'),
        new ChecklistDef('SCADA & Monitoring', 106, 'Inverter_Data_Visible__c', 'Inverter Data Visible'),
        new ChecklistDef('SCADA & Monitoring', 107, 'Weather_Station_Installed__c', 'Weather Station Installed'),
        new ChecklistDef('SCADA & Monitoring', 108, 'Pyranometer_Calibrated__c', 'Pyranometer Calibrated'),
        new ChecklistDef('SCADA & Monitoring', 109, 'Remote_Monitoring_Working__c', 'Remote Monitoring Working'),
        
        // Testing & Commissioning Records With File
        new ChecklistDef('Testing & Commissioning Records With File', 110, 'Earthing_Checklist__c', 'Earthing Checklist'),
        new ChecklistDef('Testing & Commissioning Records With File', 111, 'Ac_cable_megger__c', 'Ac cable megger'),
        new ChecklistDef('Testing & Commissioning Records With File', 112, 'String_VOC_Checklist__c', 'String VOC Checklist'),
        new ChecklistDef('Testing & Commissioning Records With File', 113, 'Cube_Test_Reports_T_C__c', 'Cube Test Reports'),
        new ChecklistDef('Testing & Commissioning Records With File', 114, 'Module_Checklist__c', 'Module Checklist'),
        new ChecklistDef('Testing & Commissioning Records With File', 115, 'Inverters_Checklist__c', 'Inverters Checklist'),
        new ChecklistDef('Testing & Commissioning Records With File', 116, 'ACDB_Checklist__c', 'ACDB Checklist'),
        new ChecklistDef('Testing & Commissioning Records With File', 117, 'Cable_AC_DC__c', 'Cable AC DC'),
        new ChecklistDef('Testing & Commissioning Records With File', 118, 'Sensors_Communication_Checklist__c', 'Sensors & Communication Checklist'),
        new ChecklistDef('Testing & Commissioning Records With File', 119, 'Module_cleaning_system__c', 'Module cleaning system'),
        new ChecklistDef('Testing & Commissioning Records With File', 120, 'Walkway_Installation__c', 'Walkway Installation'),
        new ChecklistDef('Testing & Commissioning Records With File', 121, 'Isolator_Panel_Checklist__c', 'Isolator Panel Checklist')
    };

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getStatusPicklistValues() {
        List<Map<String, String>> options = new List<Map<String, String>>();
        Schema.DescribeFieldResult fieldResult = Project_HOTO_Checklist__c.Status1__c.getDescribe();
        for(Schema.PicklistEntry f : fieldResult.getPicklistValues()) {
            options.add(new Map<String, String>{ 'label' => f.getLabel(), 'value' => f.getValue() });
        }
        return options;
    }

    @AuraEnabled
    public static InitWrapper getChecklistFields(Id projectId, String cacheBust) {
        InitWrapper wrapper = new InitWrapper();
        wrapper.projectInfo = new Map<String, String>();
        wrapper.rows = new List<ChecklistRowDTO>();
        wrapper.hasMoreRows = false;

        if (projectId == null) { return wrapper; }

        // Fetch Project details for default read-only mapping
        Project__c proj = [
            SELECT Id, Name, Account__r.Name, Project_Capacity__c, UOM__c, Project_Location__c 
            FROM Project__c 
            WHERE Id = :projectId 
            LIMIT 1
        ];

        List<String> queryFields = new List<String>{ 
            'Id', 'Parent_Project_HOTO_Checklist__c',
            'Client_Name__c', 'Project_Name__c', 'Project_Capacity__c', 'Project_Location__c',
            'Contractor_Name__c', 'Inspection_Date__c', 'Document_Number__c', 'Drawing_Reference_No__c'
        };
        
        for(ChecklistDef def : CHECKLIST_DEFS) {
            queryFields.add(def.fieldApi);
            queryFields.add('Remark' + def.index + '__c');
            queryFields.add('Status' + def.index + '__c');
        }

        String query = 'SELECT ' + String.join(queryFields, ', ') + 
                       ' FROM Project_HOTO_Checklist__c WHERE Project__c = :projectId' +
                       ' ORDER BY LastModifiedDate DESC LIMIT 1';

        List<Project_HOTO_Checklist__c> existing = Database.query(query);
        Project_HOTO_Checklist__c chk = existing.isEmpty() ? new Project_HOTO_Checklist__c() : existing[0];

        // Format combined Project Capacity string (e.g. "10 MW")
        String projCapacityStr = '';
        if (proj.Project_Capacity__c != null) {
            projCapacityStr = String.valueOf(proj.Project_Capacity__c);
            if (String.isNotBlank(proj.UOM__c)) {
                projCapacityStr += ' ' + proj.UOM__c;
            }
        }

        // Populate header fields: Prefer Checklist data first, fallback to Project__c data
        wrapper.projectInfo.put('clientName', String.isNotBlank((String)chk.get('Client_Name__c')) ? (String)chk.get('Client_Name__c') : (proj.Account__r != null ? proj.Account__r.Name : ''));
        wrapper.projectInfo.put('projectName', String.isNotBlank((String)chk.get('Project_Name__c')) ? (String)chk.get('Project_Name__c') : proj.Name);
        wrapper.projectInfo.put('projectCapacity', String.isNotBlank((String)chk.get('Project_Capacity__c')) ? (String)chk.get('Project_Capacity__c') : projCapacityStr);
        wrapper.projectInfo.put('projectLocation', String.isNotBlank((String)chk.get('Project_Location__c')) ? (String)chk.get('Project_Location__c') : (proj.Project_Location__c != null ? proj.Project_Location__c : ''));
        
        wrapper.projectInfo.put('contractorName', chk.get('Contractor_Name__c') != null ? (String)chk.get('Contractor_Name__c') : '');
        wrapper.projectInfo.put('inspectionDate', chk.get('Inspection_Date__c') != null ? String.valueOf(chk.get('Inspection_Date__c')) : '');
        wrapper.projectInfo.put('documentNumber', String.isNotBlank((String)chk.get('Document_Number__c')) ? (String)chk.get('Document_Number__c') : '');
        wrapper.projectInfo.put('drawingReferenceNo', chk.get('Drawing_Reference_No__c') != null ? (String)chk.get('Drawing_Reference_No__c') : '');

        for (Integer i = 0; i < CHECKLIST_DEFS.size(); i++) {
            ChecklistDef def = CHECKLIST_DEFS[i];
            
            Boolean isChecked = false;
            String currentStatus = '';
            String currentRemark = '';

            String dynamicRemarkField = 'Remark' + def.index + '__c';
            String dynamicStatusField = 'Status' + def.index + '__c';

            if (chk.Id != null) {
                Object chkObj = chk.get(def.fieldApi);
                isChecked = chkObj != null ? (Boolean)chkObj : false;
                
                Object statObj = chk.get(dynamicStatusField);
                currentStatus = statObj != null ? String.valueOf(statObj) : '';
                
                Object remObj = chk.get(dynamicRemarkField);
                currentRemark = remObj != null ? String.valueOf(remObj) : '';
            }

            if (isChecked == true || String.isNotBlank(currentStatus) || String.isNotBlank(currentRemark)) {
                continue; 
            }

            if (wrapper.rows.size() >= 10) {
                wrapper.hasMoreRows = true;
                break;
            }

            ChecklistRowDTO row = new ChecklistRowDTO();
            row.section = def.section;
            row.rowNumber = def.index; 
            row.globalIndex = i; 
            row.fieldApi = def.fieldApi;
            row.label = def.label;
            row.remarkField = dynamicRemarkField;
            row.statusField = dynamicStatusField;
            row.fileNames = new List<String>();
            row.documentIds = new List<String>();
            row.fileNamesText = '';
            row.hasFiles = false;
            row.recordId = chk.Id != null ? String.valueOf(chk.Id) : null;
            row.checked = false; 
            row.status = '';
            row.remark = '';

            wrapper.rows.add(row);
        }

        return wrapper;
    }

    @AuraEnabled
    public static Id saveChecklistPage(Id projectId, Map<String, String> projectInfo, List<ChecklistRowDTO> rows) {
        try {
            if (projectId == null) { throw new AuraHandledException('Project Id is required.'); }

            List<Project_HOTO_Checklist__c> existing = [
                SELECT Id, Parent_Project_HOTO_Checklist__c 
                FROM Project_HOTO_Checklist__c 
                WHERE Project__c = :projectId ORDER BY LastModifiedDate DESC LIMIT 1
            ];
            
            Project_HOTO_Checklist__c chk;

            if (existing.isEmpty()) {
                chk = new Project_HOTO_Checklist__c(Project__c = projectId);
                Parent_Project_HOTO_Checklist__c dummyParent = new Parent_Project_HOTO_Checklist__c(Project__c = projectId);
                insert dummyParent;
                chk.Parent_Project_HOTO_Checklist__c = dummyParent.Id;
            } else {
                chk = existing[0];
            }

            // Save the Header Info Fields
            if (projectInfo != null) {
                chk.Client_Name__c = projectInfo.get('clientName');
                chk.Project_Name__c = projectInfo.get('projectName');
                chk.Project_Capacity__c = projectInfo.get('projectCapacity');
                chk.Project_Location__c = projectInfo.get('projectLocation');
                chk.Contractor_Name__c = projectInfo.get('contractorName');
                chk.Document_Number__c = projectInfo.get('documentNumber');
                chk.Drawing_Reference_No__c = projectInfo.get('drawingReferenceNo');
                
                String inspDateStr = projectInfo.get('inspectionDate');
                if (String.isNotBlank(inspDateStr)) {
                    chk.Inspection_Date__c = Date.valueOf(inspDateStr);
                } else {
                    chk.Inspection_Date__c = null;
                }
            }

            for (ChecklistRowDTO row : rows) {
                ChecklistDef def = CHECKLIST_DEFS[row.globalIndex];
                chk.put(def.fieldApi, row.checked != null ? row.checked : false);
                chk.put(row.remarkField, row.remark != null ? row.remark : '');
                chk.put(row.statusField, row.status != null ? row.status : ''); 
            }

            upsert chk;

            List<ContentDocumentLink> newLinks = new List<ContentDocumentLink>();
            for (ChecklistRowDTO row : rows) {
                if (row.documentIds != null && !row.documentIds.isEmpty()) {
                    for (String docId : row.documentIds) {
                        newLinks.add(new ContentDocumentLink(
                            LinkedEntityId = chk.Id, ContentDocumentId = (Id)docId, ShareType = 'V', Visibility = 'AllUsers'
                        ));
                    }
                }
            }
            if (!newLinks.isEmpty()) { Database.insert(newLinks, false); }

            return chk.Id;
        } catch (Exception e) {
            throw new AuraHandledException('Save Error: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void deleteOrphanedFiles(List<String> documentIds) {
        if (documentIds == null || documentIds.isEmpty()) return;
        try {
            List<ContentDocument> docsToDelete = [SELECT Id FROM ContentDocument WHERE Id IN :documentIds];
            if (!docsToDelete.isEmpty()) {
                delete docsToDelete;
            }
        } catch (Exception e) {
            System.debug('Error deleting orphaned files: ' + e.getMessage());
        }
    }
}