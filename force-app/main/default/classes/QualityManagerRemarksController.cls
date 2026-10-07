public with sharing class QualityManagerRemarksController {

    public class InitWrapper {
        @AuraEnabled public Map<String, String> headerInfo { get; set; }
        @AuraEnabled public List<RowDTO> rows { get; set; }
        @AuraEnabled public Id qmaRecordId { get; set; }
    }

    public class RowDTO {
        @AuraEnabled public Integer rowNumber { get; set; }
        @AuraEnabled public String fieldApi { get; set; }
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public Boolean hotoChecked { get; set; }
        @AuraEnabled public String qmStatus { get; set; }
        @AuraEnabled public String qmRemark { get; set; }
    }

    // Small wrapper class to link the API Name with your exact custom label
    public class FieldDef {
        public String apiName;
        public String label;
        public FieldDef(String apiName, String label) {
            this.apiName = apiName;
            this.label = label;
        }
    }

    // CRITICAL FIX: Explicitly mapping the exact sequence and your custom labels
    private static List<FieldDef> getChecklistDefinitions() {
        return new List<FieldDef>{
            new FieldDef('Approved_Civil_Drawings_GA_Foundation__c', 'Approved Civil Drawings (GA, Foundation, RCC, Trenches)'), // 1
            new FieldDef('As_per_Drawing_L_x_B_x_H__c', 'As per Drawing (L x B x H)'), // 2
            new FieldDef('Foundation_Layout_Approved__c', 'Foundation Layout Approved'), // 3
            new FieldDef('Size_of_Civil_foundation__c', 'Size of Civil foundation'), // 4
            new FieldDef('Cube_Test_Reports__c', 'Cube Test Reports'), // 5
            new FieldDef('MaterialTestCert_Cement_Steel_Aggregate__c', 'Material Test Certificates (Cement, Steel, Aggregates)'), // 6
            new FieldDef('Backfilling_Compaction__c', 'Backfilling & Compaction'), // 7
            new FieldDef('Site_Compacted_Level_Verified__c', 'Site Compacted & Level Verified'), // 8
            new FieldDef('No_Water_Logging_Observed__c', 'No Water Logging Observed'), // 9
            new FieldDef('Foundation_Location_as_per_Layout__c', 'Foundation Location as per Layout'), // 10
            new FieldDef('Alignment_Row_Spacing_Verified__c', 'Alignment & Row Spacing Verified'), // 11
            new FieldDef('Foundation_Top_Level_Checked__c', 'Foundation Top Level Checked'), // 12
            new FieldDef('AnchorBoltsPosition_AlignmentVerified__c', 'Anchor Bolts Position & Alignment Verified'), // 13
            new FieldDef('Bolt_Tightening_Done__c', 'Bolt Tightening Done'), // 14
            new FieldDef('Curing_Records_Available__c', 'Curing Records Available'), // 15
            new FieldDef('No_Cracks_Honeycombing__c', 'No Cracks / Honeycombing'), // 16
            new FieldDef('Inverter_Foundation_Dimensions_Verified__c', 'Inverter Foundation Dimensions Verified'), // 17
            new FieldDef('Number_of_foundations__c', 'Number of foundations'), // 18
            new FieldDef('White_washing_of_the_pedestal_done__c', 'White washing of the pedestal done'), // 19
            new FieldDef('No_gap_between_pedestal_and_floor__c', 'No gap between pedestal and floor'), // 20
            new FieldDef('Ladder_as_per_requirement__c', 'Ladder as per requirement'), // 21
            new FieldDef('Nitobond_Application_as_per_requirement__c', 'Nitobond Application as per requirement'), // 22
            new FieldDef('MMS_installed_as_per_design__c', 'MMS installed as per design'), // 23
            new FieldDef('MMS_Aligment__c', 'MMS Aligment'), // 24
            new FieldDef('ProperTighteningTheNutBoltsInFoundation__c', 'Proper tightening of the Nut Bolts in foundation and structure'), // 25
            new FieldDef('FinalTorquingMarkWithPermanentMarkerNuts__c', 'Final torquing mark with permanent marker on all structure nuts & bolts'), // 26
            new FieldDef('Tilt_Angle_of_the_panels__c', 'Tilt Angle of the panels'), // 27
            new FieldDef('Structure_Horizontal_alignment__c', 'Structure Horizontal alignment'), // 28
            new FieldDef('Tieting_of_proper_module__c', 'Tieting of proper module'), // 29
            new FieldDef('Gaps_between_panels_as_per_drawing__c', 'Gaps between panels as per drawing'), // 30
            new FieldDef('Module_status_if_any_damages_etc__c', 'Module status (if any damages etc.)'), // 31
            new FieldDef('CanopySuitableToProtectSunlightAndRain__c', 'Canopy suitable to protect direct sunlight and rain showers from top as well as from sides.'), // 32
            new FieldDef('Water_Pump_installed__c', 'Water Pump installed'), // 33
            new FieldDef('PumpCableLayingDoneInconduitAndOnStub__c', 'Pump cable laying done in conduit and on stub'), // 34
            new FieldDef('Whether_installed_separate_water_tank__c', 'Whether installed separate water tank'), // 35
            new FieldDef('Capacity_of_tank__c', 'Capacity of tank'), // 36
            new FieldDef('Proper_Canopy_for_Pump_installed__c', 'Proper Canopy for Pump installed'), // 37
            new FieldDef('Plumbing_Network_as_per_drawing__c', 'Plumbing Network as per drawing'), // 38
            new FieldDef('AvailabiltyNozzleWithValveCoveringPlant__c', 'Availabilty of nozzle with valve covering whole plant (Not more than 15 meter from farthest panel).'), // 39
            new FieldDef('SufficientWaterPressureAtTheEndOfWTRPipe__c', 'Sufficient water pressure at the end of water pipe network as well as last panel'), // 40
            new FieldDef('CableLayingThrough_HDPE_Conduit_GI_Cable__c', 'Cable laying through HDPE conduit / GI cable tray with proper clamping & cover routing and dressing'), // 41
            new FieldDef('Cable_used_is_multistrand_copper_FRLS__c', 'Cable used is multistrand copper FRLS'), // 42
            new FieldDef('Ferrule_marking_on_both_cable_ends__c', 'Ferrule marking on both cable ends'), // 43
            new FieldDef('Connector_tightness_and_damage__c', 'Connector tightness and damage'), // 44
            new FieldDef('Both_ends_of_pipe_sealed_with_foam__c', 'Both ends of pipe sealed with foam'), // 45
            new FieldDef('CableJointsMadeThroughHeatShrinkSleeves__c', 'Cable joints made through heat shrink sleeves and hygroscopically sealed with proper marking'), // 46
            new FieldDef('MP4ConnectorsTightnessAndCheckContinuity__c', 'MP4 connectors tightness and check of continuity'), // 47
            new FieldDef('SurfaceCableLayingThroughCableTrayCover__c', 'Surface Cable laying through cable tray with cover and proper clamping on stub for ground support'), // 48
            new FieldDef('InCaseOfUnderGround_ConfirmLayingHumePip__c', 'In case of under ground, confirm laying in Hume pipes with both ends sealed'), // 49
            new FieldDef('Road_crossing_for_buried_cables__c', 'Road crossing for buried cables'), // 50
            new FieldDef('Cable_crossing__c', 'Cable crossing'), // 51
            new FieldDef('CableRouteMarkerProvidedForAllBuriedCbl__c', 'Cable route marker provided for all buried cables at specified distance'), // 52
            new FieldDef('U_G_cablesLayingWithProperBrick_SND_STN__c', 'U/G cables laying with proper brick, sand and stone pad cover as per standards'), // 53
            new FieldDef('Cable_tagging_ferrules_at_both_ends__c', 'Cable tagging & ferrules at both ends'), // 54
            new FieldDef('CableClamping_ThermoplasticClampDis_50__c', 'Cable Clamping (Thermoplastic clamp at Distance < 50cm)'), // 55
            new FieldDef('CableTerminationOnClientBus_barsWithLugs__c', 'Cable termination on client Bus-bars with proper lugs, colour code sleeve and tightening'), // 56
            new FieldDef('SufficientLoopingOfExtraCablesAtBothEnds__c', 'Sufficient looping of extra cables at both ends'), // 57
            new FieldDef('NoMultiCablesTerminatedAtSinglePointOnCl__c', 'No multiple cables terminated at single point on client ACDB'), // 58
            new FieldDef('No_overlapping_of_AC_and_DC_cables__c', 'No overlapping of AC and DC cables'), // 59
            new FieldDef('Separate_layin_of_AC_and_DC_cable__c', 'Separate layin of AC and DC cable'), // 60
            new FieldDef('Inverter_Rating_with_serial_number__c', 'Inverter Rating with serial number'), // 61
            new FieldDef('Number_of_Inverters__c', 'Number of Inverters'), // 62
            new FieldDef('Dongle_is_sync_with_data_loger__c', 'Dongle is sync with data loger'), // 63
            new FieldDef('AllCBlConnectorsAreTightened_RoutedGland__c', 'All cables connectors are properly tightened & routed through glands'), // 64
            new FieldDef('Proper_cross_tagging_of_the_cables__c', 'Proper cross tagging of the cables'), // 65
            new FieldDef('CableEntryInsideInverterInBotton_U_Shape__c', 'Cable entry inside Inverter in proper bottom forming U shape'), // 66
            new FieldDef('InverterDoorOpeningShouldBeAssessible__c', 'Inverter door opening should be properly assessible'), // 67
            new FieldDef('CanopyProvidedForInvrtrWithSufficientOve__c', 'Canopy provided for Inverter with sufficient overhung to protect from top as well as from sides'), // 68
            new FieldDef('Panel_mounting_Indoor_Outdoor__c', 'Panel mounting Indoor/ Outdoor'), // 69
            new FieldDef('Structure_mounted_wall_mounted_ACDB__c', 'Structure mounted / wall mounted ACDB have sufficient space and suitable mounting for heat dissipation arrangement and ease of maintenance'), // 70
            new FieldDef('Secure_fixing_of_ACDB_on_wall_Plinth__c', 'Secure fixing of ACDB on wall/Plinth'), // 71
            new FieldDef('ProtectiveCageProvidedFor_ACDB_If_Req__c', 'Protective Cage provided for ACDB (If required)'), // 72
            new FieldDef('Cable_Amour_to_be_grounded_at_both_end__c', 'Cable Amour to be grounded at both end'), // 73
            new FieldDef('Earthing_connected_at_two_points__c', 'Earthing connected at two points'), // 74
            new FieldDef('All_display_working_at_panel__c', 'All display working at panel'), // 75
            new FieldDef('MultiCblConnectedToBusbarWithGapsInCBLs__c', 'Multiple cables connected to busbar with specified gap in between cables (no overlapping of cables)'), // 76
            new FieldDef('CIEG_is_done__c', 'CIEG is done'), // 77
            new FieldDef('Net_metering_done__c', 'Net metering done.'), // 78
            new FieldDef('IfNetMetringNotApplicableZeroExportInst__c', 'If net metring not applicable Zero export installed.'), // 79
            new FieldDef('Number_of_Earthing_as_per_Drawing__c', 'Number of Earthing as per Drawing'), // 80
            new FieldDef('AlternateEarthPathProvidedForEachStruct__c', 'Alternate earth path provided for each structure and equipment'), // 81
            new FieldDef('GIEarthStripOnInsulator_T_JointWithSuppo__c', 'GI Earth strip on insulator & T joint with cross support'), // 82
            new FieldDef('GIEarthStripJointsAreWeldedWithOverOf150__c', 'GI Earth strip joints are welded with overlap of min 150 mm'), // 83
            new FieldDef('Earthing_conductor_buried_and_embedded__c', 'Earthing conductor buried and embedded'), // 84
            new FieldDef('Earthing_pit_marked_with_resistanceValue__c', 'Earthing pit marked with resistance value'), // 85
            new FieldDef('ProvidedWithSufficientClamping_support__c', 'Provided with sufficient Clamping/support in case of routing through wall, column etc.'), // 86
            new FieldDef('Earth_chamber_size_as_per_specification__c', 'Earth chamber size as per specification'), // 87
            new FieldDef('NoOverlappingOfEarthStripWith_DC_AC_Cbl__c', 'No overlapping of Earth strip with DC/ AC cable'), // 88
            new FieldDef('NoClientEarthStrip_PitHasBeenUsed_If_Rq__c', 'No client earth strip/ pit has been used (If Required)'), // 89
            new FieldDef('OvelappingWithOtherEartStripSeperatedBy__c', 'Ovelapping with other eart strip seperated by insulators'), // 90
            new FieldDef('Type_of_LA_and_Make_MOV_Franklin_RodType__c', 'Type of LA and Make, MOV/Franklin Rod type'), // 91
            new FieldDef('LAShould_placedAtTheHighestPointCoverage__c', 'LA should be placed at the highest point of coverage area (As per drawing)'), // 92
            new FieldDef('Proper_earthing_done_fior_LA__c', 'Proper earthing done for LA'), // 93
            new FieldDef('InstallationOfFireExtinguishersAsPerSafe__c', 'Installation of Fire Extinguishers as per safety norms (separate incase of ACDB and inverter placed at distance)'), // 94
            new FieldDef('DangerBoardInstalledAtHighVol_AC__c', 'Danger Board installed at proper places for high voltage AC (Inverter, ACDB)'), // 95
            new FieldDef('DangerBoardInstalledAtPlacesHighVol_DC__c', 'Danger Board installed at proper places for high voltage DC (AJB/DCDB, Inverter etc.)'), // 96
            new FieldDef('RadiumStickersProvidedOnStructureInFront__c', 'Radium stickers provided on structure in front of entrance'), // 97
            new FieldDef('Are_emergency_contact_numbers_displayed__c', 'Are emergency contact numbers displayed?'), // 98
            new FieldDef('First_Module_Cleaning__c', 'First Module Cleaning'), // 99
            new FieldDef('House_Keeping_Cleaning_of_site__c', 'House Keeping & Cleaning of site'), // 100
            new FieldDef('Cage_work_for_meters_if_required__c', 'Cage work for meters, if required'), // 101
            new FieldDef('LifeLineAvailbleToAnchorSafteyHarness__c', 'Life line available to anchor safety harness during panel cleaning for panel height > 1.8 Meter'), // 102
            new FieldDef('All_damage_material_removed_in_site__c', 'All damage material removed in site.'), // 103
            new FieldDef('Data_Logger_Installed__c', 'Data Logger Installed'), // 104
            new FieldDef('Communication_Cable_Tested__c', 'Communication Cable Tested'), // 105
            new FieldDef('Inverter_Data_Visible__c', 'Inverter Data Visible'), // 106
            new FieldDef('Weather_Station_Installed__c', 'Weather Station Installed'), // 107
            new FieldDef('Pyranometer_Calibrated__c', 'Pyranometer Calibrated'), // 108
            new FieldDef('Remote_Monitoring_Working__c', 'Remote Monitoring Working'), // 109
            new FieldDef('Earthing_Checklist__c', 'Earthing Checklist'), // 110
            new FieldDef('Ac_cable_megger__c', 'Ac cable megger'), // 111
            new FieldDef('String_VOC_Checklist__c', 'String VOC Checklist'), // 112
            new FieldDef('Cube_Test_Reports_T_C__c', 'Cube Test Reports'), // 113
            new FieldDef('Module_Checklist__c', 'Module Checklist'), // 114
            new FieldDef('Inverters_Checklist__c', 'Inverters Checklist'), // 115
            new FieldDef('ACDB_Checklist__c', 'ACDB Checklist'), // 116
            new FieldDef('Cable_AC_DC__c', 'Cable AC DC'), // 117
            new FieldDef('Sensors_Communication_Checklist__c', 'Sensors & Communication Checklist'), // 118
            new FieldDef('Module_cleaning_system__c', 'Module cleaning system'), // 119
            new FieldDef('Walkway_Installation__c', 'Walkway Installation'), // 120
            new FieldDef('Isolator_Panel_Checklist__c', 'Isolator Panel Checklist') // 121
        };
    }

    private static List<String> buildParentSelectFields() {
        List<String> fields = new List<String>{
            'Id',
            'Project__r.Name',
            'Project__r.Account__r.Name'
        };
        // Pull API names from our wrapper list
        for(FieldDef def : getChecklistDefinitions()) {
            fields.add(def.apiName);
        }
        return fields;
    }

    private static List<String> buildQmaSelectFields() {
        List<String> fields = new List<String>{
            'Id',
            'Project_HOTO_Checklist__c',
            'Project_Name__c',
            'Client_Name__c'
        };

        Integer rowCount = getChecklistDefinitions().size();
        for (Integer i = 1; i <= rowCount; i++) {
            fields.add('QM_Status_' + i + '__c');
            fields.add('QM_Remarks_' + i + '__c');
        }
        return fields;
    }

    @AuraEnabled(cacheable=true)
    public static InitWrapper getInitData(Id projectHotoChecklistId) {
        if (projectHotoChecklistId == null) {
            throw new AuraHandledException('Project HOTO Checklist Id is required.');
        }

        String parentQuery =
            'SELECT ' + String.join(buildParentSelectFields(), ', ') +
            ' FROM Project_HOTO_Checklist__c WHERE Id = :projectHotoChecklistId LIMIT 1';

        Project_HOTO_Checklist__c parentRec = Database.query(parentQuery);

        String qmaQuery =
            'SELECT ' + String.join(buildQmaSelectFields(), ', ') +
            ' FROM Quality_Manager_Approval__c WHERE Project_HOTO_Checklist__c = :projectHotoChecklistId LIMIT 1';

        List<Quality_Manager_Approval__c> qmaList = Database.query(qmaQuery);
        Quality_Manager_Approval__c existingQma = qmaList.isEmpty() ? null : qmaList[0];

        InitWrapper wrap = new InitWrapper();
        wrap.headerInfo = new Map<String, String>();
        wrap.rows = new List<RowDTO>();
        wrap.qmaRecordId = existingQma != null ? existingQma.Id : null;

        String projectNameVal = '';
        String clientNameVal = '';

        if (existingQma != null) {
            projectNameVal = String.isNotBlank(existingQma.Project_Name__c) ? existingQma.Project_Name__c : '';
            clientNameVal = String.isNotBlank(existingQma.Client_Name__c) ? existingQma.Client_Name__c : '';
        }

        if (String.isBlank(projectNameVal) && parentRec.Project__r != null) {
            projectNameVal = parentRec.Project__r.Name;
        }

        if (String.isBlank(clientNameVal) && parentRec.Project__r != null && parentRec.Project__r.Account__r != null) {
            clientNameVal = parentRec.Project__r.Account__r.Name;
        }

        wrap.headerInfo.put('projectName', projectNameVal);
        wrap.headerInfo.put('clientName', clientNameVal);

        Integer i = 1;
        // Loop directly through our definitions to assign hardcoded labels
        for (FieldDef def : getChecklistDefinitions()) {
            RowDTO row = new RowDTO();
            row.rowNumber = i;
            row.fieldApi = def.apiName;
            row.label = def.label; // Assigns the exact custom string you provided

            try {
                row.hotoChecked = (Boolean)parentRec.get(def.apiName);
            } catch (Exception e) {
                row.hotoChecked = false;
            }

            row.qmStatus = 'Yes';
            row.qmRemark = '';

            if (existingQma != null) {
                String statusField = 'QM_Status_' + i + '__c';
                String remarkField = 'QM_Remarks_' + i + '__c';

                try {
                    Object statusVal = existingQma.get(statusField);
                    if (statusVal != null) {
                        row.qmStatus = String.valueOf(statusVal);
                    }
                } catch (Exception e) {} 

                try {
                    Object remarkVal = existingQma.get(remarkField);
                    if (remarkVal != null) {
                        row.qmRemark = String.valueOf(remarkVal);
                    }
                } catch (Exception e) {}
            }

            wrap.rows.add(row);
            i++;
        }

        return wrap;
    }

    @AuraEnabled
    public static Id savePage(Id projectHotoChecklistId, Map<String, String> headerInfo, List<RowDTO> rows) {
        if (projectHotoChecklistId == null) {
            throw new AuraHandledException('Project HOTO Checklist Id is required.');
        }
        if (rows == null || rows.isEmpty()) {
            throw new AuraHandledException('No rows received.');
        }

        List<Quality_Manager_Approval__c> existingList = [
            SELECT Id, Project_HOTO_Checklist__c, Project_Name__c, Client_Name__c
            FROM Quality_Manager_Approval__c
            WHERE Project_HOTO_Checklist__c = :projectHotoChecklistId
            LIMIT 1
        ];

        Quality_Manager_Approval__c qma = existingList.isEmpty()
            ? new Quality_Manager_Approval__c(Project_HOTO_Checklist__c = projectHotoChecklistId)
            : existingList[0];

        if (headerInfo != null) {
            String projectName = headerInfo.get('projectName');
            String clientName = headerInfo.get('clientName');

            if (String.isNotBlank(projectName)) {
                qma.Project_Name__c = projectName;
            }
            if (String.isNotBlank(clientName)) {
                qma.Client_Name__c = clientName;
            }
        }

        Integer rowCount = getChecklistDefinitions().size();

        for (RowDTO row : rows) {
            if (row.rowNumber == null || row.rowNumber < 1 || row.rowNumber > rowCount) {
                continue;
            }

            String statusField = 'QM_Status_' + row.rowNumber + '__c';
            String remarkField = 'QM_Remarks_' + row.rowNumber + '__c';
            String finalStatus = String.isBlank(row.qmStatus) ? 'Yes' : row.qmStatus;

            if (finalStatus == 'No' && String.isBlank(row.qmRemark)) {
                throw new AuraHandledException('QM Remarks are mandatory when QM Status is No. Please check row ' + row.rowNumber + ' - ' + row.label);
            }

            try {
                qma.put(statusField, finalStatus);
            } catch (System.SObjectException e) {
                // Safely catch if object schema doesn't match
            }
            
            try {
                qma.put(remarkField, row.qmRemark);
            } catch (System.SObjectException e) {
                // Safely catch if object schema doesn't match
            }
        }

        upsert qma;
        return qma.Id;
    }
}