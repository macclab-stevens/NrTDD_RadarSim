classdef hCustomScheduler < hNRScheduler
    %hCustomScheduler Implements custom scheduling strategy.
    %   The class implements round-robin scheduling strategy without
    %   support for retransmissions. Each user equipment (UE) gets every
    %   'N'th resource block group (RBG) in the bandwidth, where 'N' is the
    %   number of UEs in the cell. Uplink and downlink scheduling assigns
    %   RBGs to a UE only if there is non-zero buffer amount for the UE in
    %   the corresponding direction. The class implements FDD mode
    %   scheduling.

    %   Copyright 2021 The MathWorks, Inc.

    properties(Access = private)
        % NumUEs Number of UEs in the cell
        NumUEs;

        % CurrHarqUL Last HARQ ID used for uplink direction
        % 1-by-N cell array where 'N' is the number of UEs. Value at index
        % 'i' indicates the HARQ ID of the last UL HARQ process used for UE
        % with RNTI as 'i'
        CurrHarqUL;

        % CurrHarqDL Last HARQ ID used for downlink direction
        % 1-by-N cell array where 'N' is the number of UEs. Value at index
        % 'i' indicates the HARQ ID of the last DL HARQ process used for UE
        % with RNTI as 'i'
        CurrHarqDL;
    end
    methods
        function obj = hCustomScheduler(simParameters)
            % Construct an instance of this class
            % Invoke the super class constructor to initialize the properties
            obj = obj@hNRScheduler(simParameters);
            obj.NumUEs = length(obj.UEs); % Number of UEs in the cell
            obj.CurrHarqUL = -1 * ones(1, obj.NumUEs); % Initialize current UL HARQ process ID
            obj.CurrHarqDL = -1 * ones(1, obj.NumUEs); % Initialize current DL HARQ process ID
        end
    end
    methods(Access = protected)
        function uplinkGrants = scheduleULResourcesSlot(obj, slotNum)
            %scheduleULResourcesSlot Schedule UL resources of a slot
            %   UPLINKGRANTS = scheduleULResourcesSlot(OBJ, SLOTNUM)
            %   assigns UL resources of the slot, SLOTNUM. UPLINKGRANTS are
            %   returned as output to convey the resource assignment by
            %   uplink scheduler using custom scheduling strategy for
            %   different UEs.
            %
            %   SLOTNUM is the slot number in the 10 ms frame whose UL
            %   resources are getting scheduled.
            %
            %   UPLINKGRANTS is a cell array where each cell-element is a
            %   structure representing an uplink grant and has the
            %   following fields:
            %
            %   RNTI                       Uplink grant is for this UE
            %
            %   Type                       Assignment is for new transmission ('newTx')
            %
            %   HARQID                     Selected uplink UE HARQ process ID
            %
            %   RBGAllocationBitmap        Frequency-domain resource assignment.
            %                              A bitmap of RBGs of the PUSCH bandwidth.
            %                              Value 1 indicates RBG is assigned to 
            %                              the UE
            %
            %   StartSymbol                Start symbol of time-domain resources. Assumed to be
            %                              0 as time-domain assignment granularity is kept as
            %                              full slot
            %
            %   NumSymbols                 Number of symbols allotted in time-domain
            %
            %   SlotOffset                 Slot-offset of PUSCH assignments for upcoming slot
            %                              w.r.t the current slot
            %
            %   MCS                        Selected modulation and coding scheme for UE with
            %                              respect to the resource assignment done
            %
            %   NDI                        New data indicator flag
            %
            %   DMRSLength                 DM-RS length
            %
            %   MappingType                Mapping type
            %
            %   NumLayers                  Number of transmission layers
            %
            %   NumAntennaPorts            Number of antenna ports
            %
            %   TPMI                       Transmitted precoding matrix indicator
            %
            %   NumCDMGroupsWithoutData    Number of DM-RS code division multiplexing (CDM) groups without data

            % Calculate offset of the slot to be scheduled, from the
            % current slot
            if slotNum >= obj.CurrSlot % Slot to be scheduled is in the current frame
                slotOffset = slotNum - obj.CurrSlot;
            else % Slot to be scheduled is in the next frame
                slotOffset = (obj.NumSlotsFrame + slotNum) - obj.CurrSlot;
            end

            uplinkGrants = cell(1, obj.NumUEs); % Array of uplink grants
            grantIndex = 0; % Grant index

            for i = 1: obj.NumUEs % For each UE
                if(sum(obj.BufferStatusUL(i, :)) > 0)
                    grantIndex = grantIndex + 1;  % Increment grant index
                    uplinkGrants{grantIndex}.RNTI = i;
                    uplinkGrants{grantIndex}.Type = 'newTx';
                    uplinkGrants{grantIndex}.RBGAllocationBitmap = zeros(1,obj.NumRBGsUL);
                    uplinkGrants{grantIndex}.RBGAllocationBitmap(i:obj.NumUEs:obj.NumRBGsUL) = 1; % ith RBG is assigned to ith UE
                    uplinkGrants{grantIndex}.StartSymbol = 0;
                    uplinkGrants{grantIndex}.NumSymbols = 14;
                    uplinkGrants{grantIndex}.SlotOffset = slotOffset;
                    uplinkGrants{grantIndex}.MappingType = 'A';
                    uplinkGrants{grantIndex}.DMRSLength = 1;
                    uplinkGrants{grantIndex}.NumLayers = 1;
                    uplinkGrants{grantIndex}.NumCDMGroupsWithoutData = 2;
                    uplinkGrants{grantIndex}.NumAntennaPorts = 1;
                    % Convert RBGBitmap to corresponding RB indices
                    rbSet = convertRBGBitmapToRBs(obj,uplinkGrants{grantIndex}.RBGAllocationBitmap,1); % Uplink
                    % Obtain the measured CQI index for corresponding UE
                    ueCQI = obj.CSIMeasurementUL(i).CQI;
                    % Average the CQI index corresponding to the grant allocation
                    avgCQIGrantRBs = mean(ueCQI(rbSet+1));
                    % Map the average CQI index in MCS table to obtain corresponding MCS index
                    uplinkGrants{grantIndex}.MCS = getMCSIndex(obj,floor(avgCQIGrantRBs)-1);
                    uplinkGrants{grantIndex}.TPMI = 0;
                    uplinkGrants{grantIndex}.RV = 0;
                    obj.CurrHarqUL(i) = mod(obj.CurrHarqUL(i) + 1, obj.NumHARQ);
                    uplinkGrants{grantIndex}.HARQID =  obj.CurrHarqUL(i);
                    uplinkGrants{grantIndex}.NDI = ~obj.HarqNDIUL(i,obj.CurrHarqUL(i) + 1); % Toggle NDI to indicate new transmission
                end
            end
            uplinkGrants = uplinkGrants(1:grantIndex);
        end

        function downlinkGrants = scheduleDLResourcesSlot(obj, slotNum)
            %scheduleDLResourcesSlot Schedule DL resources of a slot
            %   DOWNLINKGRANTS = scheduleDLResourcesSlot(OBJ, SLOTNUM)
            %   assigns DL resources of the slot, SLOTNUM. DOWNLINKGRANTS
            %   are returned as output to convey the resource assignment by
            %   downlink scheduler using custom scheduling strategy for
            %   different UEs.
            %
            %   SLOTNUM is the slot number in the 10 ms frame whose DL
            %   resources are getting scheduled.
            %
            %   DOWNLINKGRANTS is a cell array where each cell-element is a
            %   structure representing a downlink grant and has the
            %   following fields:
            %
            %   RNTI                       Downlink grant is for this UE
            %
            %   Type                       Assignment is for new transmission ('newTx')
            %
            %   HARQID                     Selected downlink HARQ process ID
            %
            %   RBGAllocationBitmap        Frequency-domain resource assignment.
            %                              A bitmap of RBGs of the PDSCH bandwidth.                             
            %                              Value 1 indicates RBG is assigned to
            %                              the UE
            %
            %   StartSymbol                Start symbol of time-domain resources
            %
            %   NumSymbols                 Number of symbols allotted in time-domain
            %
            %   SlotOffset                 Slot offset of PDSCH assignment
            %                              w.r.t the current slot
            %
            %   MCS                        Selected modulation and coding scheme for UE with
            %                              respect to the resource assignment done
            %
            %   NDI                        New data indicator flag
            %
            %   FeedbackSlotOffset         Slot offset of PDSCH ACK/NACK from
            %                              PDSCH transmission slot (i.e. k1).
            %                              Currently, only a value >=2 is supported
            %
            %   DMRSLength                 DM-RS length
            %
            %   MappingType                Mapping type
            %
            %   NumLayers                  Number of transmission layers
            %
            %   NumCDMGroupsWithoutData    Number of CDM groups without data (1...3)
            %
            %   PrecodingMatrix            Selected precoding matrix.
            %                              It is an array of size NumLayers-by-P-by-NPRG, where NPRG is the
            %                              number of precoding resource block groups (PRGs) in the carrier
            %                              and P is the number of CSI-RS ports. It defines a different
            %                              precoding matrix of size NumLayers-by-P for each PRG. The effective
            %                              PRG bundle size (precoder granularity) is Pd_BWP = ceil(NRB / NPRG).
            %                              For SISO, set it to 1

            % Calculate offset of the slot to be scheduled, from the
            % current slot
            if slotNum >= obj.CurrSlot % Slot to be scheduled is in the current frame
                slotOffset = slotNum - obj.CurrSlot;
            else % Slot to be scheduled is in the next frame
                slotOffset = (obj.NumSlotsFrame + slotNum) - obj.CurrSlot;
            end

            downlinkGrants = cell(1,obj.NumUEs); % Array of downlink grants
            grantIndex = 0; % Grant index

            for i = 1: obj.NumUEs % For each UE
                if(sum(obj.BufferStatusDL(i, :)) > 0)
                    grantIndex = grantIndex + 1;  % Increment grant index
                    downlinkGrants{grantIndex}.RNTI = i;
                    downlinkGrants{grantIndex}.Type = 'newTx';
                    downlinkGrants{grantIndex}.RBGAllocationBitmap = zeros(1,obj.NumRBGsDL);
                    downlinkGrants{grantIndex}.RBGAllocationBitmap(i:obj.NumUEs:obj.NumRBGsDL) = 1; % ith RBG is assigned to ith UE
                    downlinkGrants{grantIndex}.StartSymbol = 0;
                    downlinkGrants{grantIndex}.NumSymbols = 14;
                    downlinkGrants{grantIndex}.SlotOffset = slotOffset;
                    downlinkGrants{grantIndex}.MappingType = 'A';
                    downlinkGrants{grantIndex}.DMRSLength = 1;
                    downlinkGrants{grantIndex}.NumLayers = 1;
                    downlinkGrants{grantIndex}.NumCDMGroupsWithoutData = 2;
                    downlinkGrants{grantIndex}.PrecodingMatrix = 1;
                    % Convert RBGBitmap to corresponding RB indices
                    rbSet = convertRBGBitmapToRBs(obj,downlinkGrants{grantIndex}.RBGAllocationBitmap,0); % Downlink
                    % Obtain the measured CQI index for corresponding UE
                    ueCQI = obj.CSIMeasurementDL(i).CQI;
                    % Average the CQI index corresponding to the grant allocation
                    avgCQIGrantRBs = mean(ueCQI(rbSet+1));
                    % Map the average CQI index in MCS table to obtain corresponding MCS index
                    downlinkGrants{grantIndex}.MCS = getMCSIndex(obj,floor(avgCQIGrantRBs)-1);
                    downlinkGrants{grantIndex}.FeedbackSlotOffset = 2;
                    downlinkGrants{grantIndex}.RV = 0;
                    obj.CurrHarqDL(i) = mod(obj.CurrHarqDL(i) + 1, obj.NumHARQ);
                    downlinkGrants{grantIndex}.HARQID =  obj.CurrHarqDL(i);
                    downlinkGrants{grantIndex}.NDI = ~obj.HarqNDIDL(i,obj.CurrHarqDL(i) + 1); % Toggle NDI to indicate new transmission
                end
            end
            downlinkGrants = downlinkGrants(1:grantIndex);
        end

        function mcsIndex = getMCSIndex(obj, cqiIndex)
            %getMCSIndex Returns the mcsIndex based on cqiIndex

            % Valid rows in MCS table (Indices 28, 29, 30, 31 are reserved)
            % Indexing starts from 1
            validRows = (0:27) + 1;
            cqiRow = obj.CQITableUL(cqiIndex + 1, :);
            modulation = cqiRow(1);
            coderate = cqiRow(2);
            % List of matching indices in MCS table for modulation scheme
            % as per 'cqiIndex'
            modulationList = find(modulation == obj.MCSTableUL(validRows, 1));

            % Indices in 'modulationList' which have code rate less than or
            % equal to the code rate as per the 'cqiIndex'
            coderateList = find(obj.MCSTableUL(modulationList, 2) <= coderate);
            if isempty(coderateList)
                % If no match found, take the first value in 'modulationList'
                coderateList = modulationList(1);
            end
            % Take the value from 'modulationList' with highest code rate
            mcsIndex = modulationList(coderateList(end)) - 1;
        end
    end
end