classdef hNRUEMAC < hNRMAC
%hNRUEMAC Implements UE MAC functionality
%   The class implements the UE MAC and its interactions with RLC and Phy
%   for Tx and Rx chains. It involves adhering to packet transmission and
%   reception schedule and other related parameters which are received from
%   gNB in the form of uplink (UL) and downlink (DL) assignments. Reception
%   of uplink and downlink assignments on physical downlink control channel
%   (PDCCH) is not modeled and they are received as out-of-band packets
%   i.e. without using frequency resources and with guaranteed reception.
%   Additionally, physical uplink control channel (PUCCH) is not modeled.
%   The UE MAC sends the periodic buffer status report (BSR), PDSCH
%   feedback, and DL channel quality report out-of-band. Hybrid automatic
%   repeat request (HARQ) control mechanism to enable retransmissions is
%   implemented. MAC controls the HARQ processes residing in physical
%   layer.

%   Copyright 2019-2022 The MathWorks, Inc.

%#codegen

    properties
        % RNTI Radio network temporary identifier of a UE
        %   Specify the RNTI as an integer scalar within [1 65519]. Refer
        %   table 7.1-1 in 3GPP TS 38.321. The default value is 1.
        RNTI (1, 1) {mustBeInteger, mustBeInRange(RNTI, 1, 65519)} = 1;

        %SCS Subcarrier spacing used. The default value is 15 kHz
        SCS (1, 1) {mustBeMember(SCS, [15, 30, 60, 120])} = 15;

        %CurrSlot Current running slot number in the 10 ms frame
        CurrSlot = 0;

        %CurrSymbol Current running symbol of the current slot
        CurrSymbol = 0;

        %SFN System frame number (0 ... 1023)
        SFN = 0;

        %SchedulingType Type of scheduling (slot based or symbol based)
        % Value 0 means slot based and value 1 means symbol based. The
        % default value is 0
        SchedulingType (1, 1) {mustBeInteger, mustBeInRange(SchedulingType, 0, 1)} = 0;

        %DuplexMode Duplexing mode. Frequency division duplexing (FDD) or time division duplexing (TDD)
        % Value 0 means FDD and 1 means TDD. The default value is 0
        DuplexMode (1, 1) {mustBeInteger, mustBeInRange(DuplexMode, 0, 1)} = 0;

        % MCSTableUL MCS table used for uplink
        % It contains the mapping of MCS indices with Modulation and Coding
        % schemes
        MCSTableUL

        % MCSTableDL MCS table used for downlink
        % It contains the mapping of MCS indices with Modulation and Coding
        % schemes
        MCSTableDL

        %NumDLULPatternSlots Number of slots in DL-UL pattern (for TDD mode)
        % The default value is 5 slots
        NumDLULPatternSlots (1, 1) {mustBeInteger, mustBeGreaterThanOrEqual(NumDLULPatternSlots, 0), mustBeFinite} = 5;

        %NumDLSlots Number of full DL slots at the start of DL-UL pattern (for TDD mode)
        % The default value is 2 slots
        NumDLSlots (1, 1) {mustBeInteger, mustBeGreaterThanOrEqual(NumDLSlots, 0), mustBeFinite} = 2;

        %NumDLSyms Number of DL symbols after full DL slots in the DL-UL pattern (for TDD mode)
        % The default value is 8 symbols
        NumDLSyms (1, 1) {mustBeInteger, mustBeInRange(NumDLSyms, 0, 13)} = 8;

        %NumULSyms Number of UL symbols before full UL slots in the DL-UL pattern (for TDD mode)
        % The default value is 4 symbols
        NumULSyms (1, 1) {mustBeInteger, mustBeInRange(NumULSyms, 0, 13)} = 4;

        %NumULSlots Number of full UL slots at the end of DL-UL pattern (for TDD mode)
        % The default value is 2 slots
        NumULSlots (1, 1) {mustBeInteger, mustBeGreaterThanOrEqual(NumULSlots, 0), mustBeFinite} = 2;

        %DLULSlotFormat Format of the slots in DL-UL pattern (for TDD mode)
        % N-by-14 matrix where 'N' is number of slots in DL-UL pattern.
        % Each row contains the symbol type of the 14 symbols in the slot.
        % Value 0, 1 and 2 represent DL symbol, UL symbol, guard symbol,
        % respectively
        DLULSlotFormat

        %CurrDLULSlotIndex Slot index of the current running slot in the DL-UL pattern (for TDD mode)
        CurrDLULSlotIndex = 0;

        %NumPUSCHRBs Number of resource blocks (RBs) in the uplink bandwidth part
        % The default value is 52 RBs
        NumPUSCHRBs (1, 1) {mustBeInteger, mustBeInRange(NumPUSCHRBs, 1, 275)} = 52;

        %NumPDSCHRBs Number of resource blocks in the downlink bandwidth part
        % The default value is 52 RBs
        NumPDSCHRBs (1, 1) {mustBeInteger, mustBeInRange(NumPDSCHRBs, 1, 275)} = 52;

        %XOverheadPDSCH Additional overheads in PDSCH transmission
        XOverheadPDSCH = 6;

        %DMRSTypeAPosition Position of DM-RS in type A transmission
        DMRSTypeAPosition (1, 1) {mustBeMember(DMRSTypeAPosition, [2, 3])} = 2;

        %PUSCHDMRSConfigurationType PUSCH DM-RS configuration type (1 or 2)
        PUSCHDMRSConfigurationType (1,1) {mustBeMember(PUSCHDMRSConfigurationType, [1, 2])} = 1;

        %PUSCHDMRSAdditionalPosTypeA Additional PUSCH DM-RS positions for type A (0..3)
        PUSCHDMRSAdditionalPosTypeA (1, 1) {mustBeMember(PUSCHDMRSAdditionalPosTypeA, [0, 1, 2, 3])} = 0;

        %PUSCHDMRSAdditionalPosTypeB Additional PUSCH DM-RS positions for type B (0..3)
        PUSCHDMRSAdditionalPosTypeB (1, 1) {mustBeMember(PUSCHDMRSAdditionalPosTypeB, [0, 1, 2, 3])} = 0;

        %PDSCHDMRSConfigurationType PDSCH DM-RS configuration type (1 or 2)
        PDSCHDMRSConfigurationType (1,1) {mustBeMember(PDSCHDMRSConfigurationType, [1, 2])} = 1;

        %PDSCHDMRSAdditionalPosTypeA Additional PDSCH DM-RS positions for type A (0..3)
        PDSCHDMRSAdditionalPosTypeA (1, 1) {mustBeMember(PDSCHDMRSAdditionalPosTypeA, [0, 1, 2, 3])} = 0;

        %PDSCHDMRSAdditionalPosTypeB Additional PDSCH DM-RS positions for type B (0 or 1)
        PDSCHDMRSAdditionalPosTypeB (1, 1) {mustBeMember(PDSCHDMRSAdditionalPosTypeB, [0, 1])} = 0;

        %UplinkTxContext Uplink grant properties to be used for PUSCH transmissions
        % Cell array of size 'N' where 'N' is the number of symbols in a 10
        % ms frame. At index 'i', it contains the uplink grant for a
        % transmission which is scheduled to start at symbol number 'i'
        % w.r.t start of the frame. Value at an index is empty, if no
        % uplink transmission is scheduled for the symbol. An uplink grant
        % is an object of type hNRUplinkGrantFormat
        UplinkTxContext

        %DownlinkRxContext Downlink grant properties to be used for PDSCH reception
        % Cell array of size 'N' where N is the number of symbols in a 10
        % ms frame. An element at index 'i' stores the downlink grant for
        % PDSCH scheduled to be received at symbol 'i' from the start of
        % the frame. If no PDSCH reception is scheduled, cell element is
        % empty. A downlink grant is an object of type
        % hNRDownlinkGrantFormat
        DownlinkRxContext

        % PDSCHRxFeedback Feedback to be sent for PDSCH reception
        % N-by-3 array where 'N' is the number of HARQ process. For each
        % HARQ process, first column contains the symbol number w.r.t start
        % of 10ms frame where PDSCH feedback is scheduled to be
        % transmitted. Second column contains the feedback to be sent. The
        % third column contains time (in nanoseconds) at which
        % feedback has to be transmitted. Symbol number is -1 if no
        % feedback is scheduled for HARQ process. Feedback value 0 means
        % NACK while value 1 means ACK.
        PDSCHRxFeedback

        %NumHARQ Number of uplink HARQ processes. The default value is 16 HARQ processes
        NumHARQ (1, 1) {mustBeInteger, mustBeInRange(NumHARQ, 1, 16)} = 16;

        %HARQNDIUL Stores the last received NDI for uplink HARQ processes
        % Vector of length 'N' where 'N' is number of HARQ process. Value
        % at index 'i' stores last received NDI for the HARQ process index
        % 'i'. NDI in the UL grant is compared with this NDI to decide
        % whether grant is for new transmission or retransmission
        HARQNDIUL

        %HARQNDIDL Stores the last received NDI for downlink HARQ processes
        % Vector of length 'N' where 'N' is number of HARQ process. Value
        % at index 'i' stores last received NDI for the HARQ process index
        % 'i'. NDI in the DL grant is compared with this NDI to decide
        % whether grant is for new transmission or retransmission
        HARQNDIDL

        %TBSizeUL Stores the size of transport block sent for UL HARQ processes
        % Vector of length 'N' where 'N' is number of HARQ process. Value
        % at index 'i' stores transport block size for HARQ process index
        % 'i'. Value is 0, if HARQ process is free
        TBSizeUL

        %TBSizeDL Stores the size of transport block to be received for DL HARQ processes
        % Vector of length 'N' where 'N' is number of HARQ process. Value
        % at index 'i' stores transport block size for HARQ process index
        % 'i'. Value is 0 if no DL packet expected for HARQ process
        TBSizeDL

        %BSRPeriodicityInSF Buffer status report periodicity in subframes
        BSRPeriodicityInSF

        %CSIReportPeriodicity CSI reporting periodicity in milliseconds
        CSIReportPeriodicity

        %RSRPReportPeriodicity CSI reporting (cri-l1RSRP) periodicity in milliseconds
        RSRPReportPeriodicity = 1;

        %RBGSizeUL Resource block group size of uplink BWP in terms of number of RBs
        RBGSizeUL

        %RBGSizeDL Resource block group size of downlink BWP in terms of number of RBs
        RBGSizeDL

        %NumRBGsUL Number of RBGs in uplink BWP
        NumRBGsUL

        %NumRBGsDL Number of RBGs in downlink BWP
        NumRBGsDL

        %SrsConfig SRS resource configuration for the UE
        % It is an object of type nrSRSConfig and contains the
        % SRS resource configured for UE
        SrsConfig

        %CsirsConfig CSI-RS resource configuration for the UE
        % It is an array of size equal to number of UEs. An element at
        % index 'i' is an object of type nrCSIRSConfig and stores the CSI-RS
        % configuration of UE with RNTI 'i'. If only one CSI-RS
        % configuration is specified, it is assumed to be applicable for
        % all the UEs in the cell.
        CsirsConfig

        %CsirsConfigRSRP CSI-RS resource set configurations corresponding to the SSB directions
        % It is a cell array of length N-by-1 where 'N' is the maximum
        % number of SSBs in a SSB burst. Each element of the array at index
        % 'i' corresponds to the CSI-RS resource set associated with SSB
        % 'i'. The number of CSI-RS resources in each resource set is
        % same for all configurations.
        CsirsConfigRSRP

        %SSBIdx Index of the SSB associated to the UE
        SSBIdx

        %CSIMeasurement Channel state information (CSI) measurements
        % Structure with the fields: 'RankIndicator', 'PMISet', 'CQI'.
        % RankIndicator is a scalar value to representing the rank reported by a UE.
        % PMISET has the following fields:
        %   i1 - Indicates wideband PMI (1-based). It a three-element vector in the
        %        form of [i11 i12 i13].
        %   i2 - Indicates subband PMI (1-based). It is a vector of length equal to
        %        the number of subbands or number of PRGs.
        % CQI - Array of size equal to number of RBs in the bandwidth. Each index
        % contains the CQI value corresponding to the RB index.
        CSIMeasurement

        %StatTxThroughputBytes Number of MAC bytes sent to Phy
        StatTxThroughputBytes = 0;

        %StatTxGoodputBytes Number of new transmission MAC bytes sent to Phy
        StatTxGoodputBytes = 0;

        %StatResourceShare Number of RBs allocated to each UE
        StatResourceShare = 0;
    end

    properties (Access = private)
        %LCGBufferStatus Logical channel group buffer status
        LCGBufferStatus = zeros(8, 1);

        %NextBSRTime Time (in nanoseconds) at which next BSR will be sent
        NextBSRTime = 0;

        %NextCSIReportTime Time (in nanoseconds) at which next CSI report will be sent
        NextCSIReportTime = 0;

        %NextRSRPReportTime Time (in nanoseconds) at which next CSI report (cri-rsrp format) will be sent
        NextRSRPReportTime = Inf;

        %GuardDuration Guard period in the DL-UL pattern in terms of number of symbols (for TDD mode)
        GuardDuration

        %CSIRSRxInfo Information about CSI-RS reception
        % It is an array of size N-by-2 where N is the number of unique CSI-RS
        % periodicity, slot offset pairs configured for the UE.
        % Each row of the array contains CSI-RS reception periodicity (in
        % nanoseconds) and the next reception start time (in
        % nanoseconds) of the UE.
        CSIRSRxInfo

        %SRSTxInfo Information about SRS transmission
        % It is a vector of size 2. First element in the vector contains
        % SRS transmission periodicity (in nanoseconds) and the second
        % element contains the next transmisson start time (in
        % nanoseconds) of the UE.
        SRSTxInfo = [inf inf];
    end

    properties (Access = protected)
        %% Transient object maintained for optimization
        %CarrierConfigUL nrCarrierConfig object for UL
        CarrierConfigUL
        %CarrierConfigDL nrCarrierConfig object for DL
        CarrierConfigDL
        %PDSCHInfo hNRPDSCHInfo object
        PDSCHInfo
        %PUSCHInfo hNRPUSCHInfo object
        PUSCHInfo
    end

    methods
        function obj = hNRUEMAC(simParameters, rnti)
            %hNRUEMAC Construct a UE MAC object
            %
            % simParameters is a structure including the following fields:
            %
            % NCellID                  - Physical cell ID. Values: 0 to 1007 (TS 38.211, sec 7.4.2.1)
            % SCS                      - Subcarrier spacing
            % DuplexMode               - Duplexing mode. FDD (value 0) or TDD (value 1)
            % BSRPeriodicity(optional) - Periodicity for the BSR packet
            %                            generation. Default value is 5 subframes
            % NumRBs                   - Number of RBs in PUSCH and PDSCH bandwidth
            % NumHARQ                  - Number of HARQ processes on UEs
            % DLULPeriodicity          - Duration of the DL-UL pattern in ms (for TDD mode)
            % NumDLSlots               - Number of full DL slots at the start of DL-UL pattern (for TDD mode)
            % NumDLSyms                - Number of DL symbols after full DL slots of DL-UL pattern (for TDD mode)
            % NumULSyms                - Number of UL symbols before full UL slots of DL-UL pattern (for TDD mode)
            % NumULSlots               - Number of full UL slots at the end of DL-UL pattern (for TDD mode)
            % SchedulingType           - Slot based scheduling (value 0) or symbol based scheduling (value 1)
            % NumLogicalChannels       - Number of logical channels configured
            % RBGSizeConfig(optional)  - RBG size configuration as 1 (configuration-1 RBG table) or 2 (configuration-2 RBG table)
            %                            as defined in 3GPP TS 38.214 Section 5.1.2.2.1. It defines the
            %                            number of RBs in an RBG. Default value is 1
            % DMRSTypeAPosition        - DM-RS type A position (2 or 3)
            % PUSCHDMRSConfigurationType   - PUSCH DM-RS configuration type (1 or 2)
            % PUSCHDMRSAdditionalPosTypeA  - Additional PUSCH DM-RS positions for Type A (0..3)
            % PUSCHDMRSAdditionalPosTypeB  - Additional PUSCH DM-RS positions for Type B (0..3)
            % PDSCHDMRSConfigurationType   - PDSCH DM-RS configuration type (1 or 2)
            % PDSCHDMRSAdditionalPosTypeA  - Additional PDSCH DM-RS positions for Type A (0..3)
            % PDSCHDMRSAdditionalPosTypeB  - Additional PDSCH DM-RS positions for Type B (0 or 1)
            % UETxAnts                 - Number of UE Tx antennas
            % CSIRSConfig              - Cell array containing the CSI-RS configuration information as an
            %                            object of type nrCSIRSConfig. The element at index 'i' corresponds
            %                            to the CSI-RS configured for a UE with RNTI 'i'. If only one CSI-RS
            %                            configuration is specified, it is assumed to be applicable for
            %                            all the UEs in the cell.
            % CSIRSConfigRSRP          - CSI-RS resource set configurations corresponding to the SSB directions.
            %                            It is a cell array of length N-by-1 where 'N' is the number of
            %                            maximum number of SSBs in a SSB burst. Each element of the array
            %                            at index 'i' corresponds to the CSI-RS resource set associated
            %                            with SSB 'i-1'. The number of CSI-RS resources in each resource
            %                            set is same for all configurations.
            % SSBIdx                   - Scalar representing the index of SSB acquired by the UE during P-1 procedure
            % SRSConfig                - SRS configuration specified as an object of type nrSRSConfig
            %
            % The second input, RNTI, is the radio network temporary
            % identifier, specified within [1, 65519]. Refer table 7.1-1 in
            % 3GPP TS 38.321.

            obj.RNTI = rnti;

            if isfield(simParameters, 'NCellID')
                obj.NCellID = simParameters.NCellID;
            end
            if isfield(simParameters, 'SCS')
                obj.SCS = simParameters.SCS;
            end

            if isfield(simParameters, 'BSRPeriodicity')
                % Valid BSR periodicity in terms of number of subframes
                validBSRPeriodicity =  [1, 5, 10, 16, 20, 32, 40, 64, 80, 128, 160, 320, 640, 1280, 2560, inf];
                % Validate the BSR periodicity
                validateattributes(simParameters.BSRPeriodicity, {'numeric'}, {'nonempty'}, 'simParameters.BSRPeriodicity', 'BSRPeriodicity');
                if ~ismember(simParameters.BSRPeriodicity, validBSRPeriodicity)
                    error('nr5g:hNRUEMAC:InvalidBSRPeriodicity','BSRPeriodicity ( %d ) must be one of the set (1,5,10,16,20,32,40,64,80,128,160,320,640,1280,2560,inf).',simParameters.BSRPeriodicity);
                end
                obj.BSRPeriodicityInSF = simParameters.BSRPeriodicity;
            else
                % By default, for every 5 subframes BSR sent to the gNB
                obj.BSRPeriodicityInSF = 5;
            end
            obj.NextBSRTime = obj.BSRPeriodicityInSF * 1e6; % In nanoseconds

            if isfield(simParameters, 'SchedulingType')
                obj.SchedulingType = simParameters.SchedulingType;
            end
            if isfield(simParameters, 'NumHARQ')
                obj.NumHARQ = simParameters.NumHARQ;
            end

            obj.MACType = 1; % UE MAC
            slotDuration = 1/(obj.SCS/15); % In ms
            obj.SlotDurationInNS = slotDuration * 1e6; % In nanoseconds
            obj.NumSlotsFrame = 10/slotDuration; % Number of slots in a 10 ms frame
            obj.CSIReportPeriodicity = 2; % 2 ms i.e Send it every alternate subframe
            obj.NextCSIReportTime = obj.CSIReportPeriodicity*1e6; % In nanoseconds
            obj.SymbolEndTimesInSlot = round(((1:14)*slotDuration)/14, 4) * 1e6;
            obj.SymbolDurationsInSlot = obj.SymbolEndTimesInSlot(1:14) - [0 obj.SymbolEndTimesInSlot(1:13)];

            % Set the RBG size configuration (for defining number of RBs in
            % one RBG) to 1 (configuration-1 RBG table) or 2
            % (configuration-2 RBG table) as defined in 3GPP TS 38.214
            % Section 5.1.2.2.1. If it is not configured, take default
            % value as 1.
            if isfield(simParameters, 'RBGSizeConfig')
                RBGSizeConfig = simParameters.RBGSizeConfig;
            else
                RBGSizeConfig = 1;
            end
            if isfield(simParameters, 'DuplexMode')
                obj.DuplexMode = simParameters.DuplexMode;
            end
            if isfield(simParameters, 'NumRBs')
                obj.NumPUSCHRBs = simParameters.NumRBs;
                obj.NumPDSCHRBs = simParameters.NumRBs;
            end

            % Calculate UL and DL RBG size in terms of number of RBs
            uplinkRBGSizeIndex = min(find(obj.NumPUSCHRBs <= obj.NominalRBGSizePerBW(:, 1), 1));
            downlinkRBGSizeIndex = min(find(obj.NumPDSCHRBs <= obj.NominalRBGSizePerBW(:, 1), 1));
            if RBGSizeConfig == 1
                obj.RBGSizeUL = obj.NominalRBGSizePerBW(uplinkRBGSizeIndex, 2);
                obj.RBGSizeDL = obj.NominalRBGSizePerBW(downlinkRBGSizeIndex, 2);
            else % RBGSizeConfig is 2
                obj.RBGSizeUL = obj.NominalRBGSizePerBW(uplinkRBGSizeIndex, 3);
                obj.RBGSizeDL = obj.NominalRBGSizePerBW(downlinkRBGSizeIndex, 3);
            end

            if obj.DuplexMode == 1 % For TDD duplex
                % Validate the TDD configuration and populate the properties
                populateTDDConfiguration(obj, simParameters);

                % Set format of slots in the DL-UL pattern. Value 0 means
                % DL symbol, value 1 means UL symbol while symbols with
                % value 2 are guard symbols
                obj.DLULSlotFormat = obj.GuardType * ones(obj.NumDLULPatternSlots, 14);
                obj.DLULSlotFormat(1:obj.NumDLSlots, :) = obj.DLType; % Mark all the symbols of full DL slots as DL
                obj.DLULSlotFormat(obj.NumDLSlots + 1, 1 : obj.NumDLSyms) = obj.DLType; % Mark DL symbols following the full DL slots
                obj.DLULSlotFormat(obj.NumDLSlots + floor(obj.GuardDuration/14) + 1, (obj.NumDLSyms + mod(obj.GuardDuration, 14) + 1) : end)  ...
                        = obj.ULType; % Mark UL symbols at the end of slot before full UL slots
                obj.DLULSlotFormat((end - obj.NumULSlots + 1):end, :) = obj.ULType; % Mark all the symbols of full UL slots as UL type
            end

            obj.PDSCHRxFeedback = -1*ones(obj.NumHARQ, 3);
            obj.PDSCHRxFeedback(:, 3) = inf;
            obj.HARQNDIUL = zeros(obj.NumHARQ, 1); % Initialize NDI of each UL HARQ process to 0
            obj.HARQNDIDL = zeros(obj.NumHARQ, 1); % Initialize NDI of each DL HARQ process to 0
            obj.TBSizeDL = zeros(obj.NumHARQ, 1);

            % Stores uplink assignments (if any), corresponding to uplink
            % transmissions starting at different symbols of the frame
            obj.UplinkTxContext = cell(obj.NumSlotsFrame * 14, 1);

            % Stores downlink assignments (if any), corresponding to
            % downlink receptions starting at different symbols of the
            % frame
            obj.DownlinkRxContext = cell(obj.NumSlotsFrame * 14, 1);

            obj.NumSymInFrame = obj.NumSlotsFrame * 14;

            % Set non-zero-power (NZP) CSI-RS configuration for the UE
            if isfield(simParameters, 'CSIRSConfig')
                for idx = 1:length(simParameters.CSIRSConfig)
                    if ~isa(simParameters.CSIRSConfig{idx}, 'nrCSIRSConfig')
                        error('nr5g:hNRUEMAC:InvalidObjectType', "Each element of 'CSIRSConfig' must be specified as an object of type nrCSIRSConfig")
                    end
                end
                obj.CsirsConfig = simParameters.CSIRSConfig;
                if length(simParameters.CSIRSConfig) ~= 1
                    csirs  = simParameters.CSIRSConfig{obj.RNTI};
                else
                    csirs = simParameters.CSIRSConfig{1};
                end
            else
                % Avoid potential DM-RS and CSI-RS overlap
                if isfield(simParameters, 'PDSCHDMRSConfigurationType') && simParameters.PDSCHDMRSConfigurationType == 2
                    subcarrierLocations = 2;
                else
                    subcarrierLocations = 1;
                end
                csirs = nrCSIRSConfig("SubcarrierLocations", subcarrierLocations, 'SymbolLocations', 0,...
                    "NumRB", obj.NumPDSCHRBs, 'NID', obj.NCellID, 'RowNumber', 2);
                obj.CsirsConfig = {csirs};
            end

            if isfield(simParameters, 'CSIRSConfigRSRP')
                for csirsIdx = 1:length(simParameters.CSIRSConfigRSRP)
                    if ~isa(simParameters.CSIRSConfigRSRP{csirsIdx}, 'nrCSIRSConfig')
                        error('nr5g:hNRUEMAC:InvalidCSIResourceSetConfig', "Each element of 'CSIRSConfigRSRP' must be specified as an object of type nrCSIRSConfig")
                    end
                    if simParameters.CSIRSConfigRSRP{csirsIdx}.NumCSIRSPorts(1) ~= 1
                        error('nr5g:hNRUEMAC:InvalidNumCSIRSPorts',...
                            'Number of CSI-RS ports (%d) for L1-RSRP measurements must be 1.', simParameters.CSIRSConfigRSRP{csirsIdx}.NumCSIRSPorts(1));
                    end
                end
                obj.CsirsConfigRSRP = simParameters.CSIRSConfigRSRP;
                obj.NextRSRPReportTime = obj.RSRPReportPeriodicity*1e6; % In nanoseconds
            end

            % Calculate unique CSI-RS reception slots
            obj.CSIRSRxInfo = calculateCSIRSPeriodicity(obj, [{csirs} obj.CsirsConfigRSRP]);

            if isfield(simParameters, 'SSBIdx')
                obj.SSBIdx = simParameters.SSBIdx;
            end

            if isfield(simParameters, 'DMRSTypeAPosition')
                obj.DMRSTypeAPosition = simParameters.DMRSTypeAPosition;
            end
            % PUSCH DM-RS configuration
            if isfield(simParameters, 'PUSCHDMRSConfigurationType')
                obj.PUSCHDMRSConfigurationType = simParameters.PUSCHDMRSConfigurationType;
            end
            if isfield(simParameters, 'PUSCHDMRSAdditionalPosTypeA')
                obj.PUSCHDMRSAdditionalPosTypeA = simParameters.PUSCHDMRSAdditionalPosTypeA;
            end
            if isfield(simParameters, 'PUSCHDMRSAdditionalPosTypeB')
                obj.PUSCHDMRSAdditionalPosTypeB = simParameters.PUSCHDMRSAdditionalPosTypeB;
            end

            % PDSCH DM-RS configuration
            if isfield(simParameters, 'PDSCHDMRSConfigurationType')
                obj.PDSCHDMRSConfigurationType = simParameters.PDSCHDMRSConfigurationType;
            end
            if isfield(simParameters, 'PDSCHDMRSAdditionalPosTypeA')
                obj.PDSCHDMRSAdditionalPosTypeA = simParameters.PDSCHDMRSAdditionalPosTypeA;
            end
            if isfield(simParameters, 'PDSCHDMRSAdditionalPosTypeB')
                obj.PDSCHDMRSAdditionalPosTypeB = simParameters.PDSCHDMRSAdditionalPosTypeB;
            end

            if ~isfield(simParameters, 'UETxAnts')
                simParameters.UETxAnts = 1;
            % Validate the number of transmitter antennas on UEs
            elseif ~ismember(simParameters.UETxAnts, [1,2,4,8,16])
                error('nr5g:hNRUEMAC:InvalidAntennaSize',...
                    'Number of UE Tx antennas (%d) must be a member of [1,2,4,8,16].', simParameters.UETxAnts(rnti));
            end

            if isfield(simParameters, 'SRSConfig')
                if ~isa(simParameters.SRSConfig, 'nrSRSConfig')
                    error('nr5g:hNRUEMAC:InvalidObjectType', "'SRSConfig' must be specified as an object of type nrSRSConfig")
                end
                if simParameters.SRSConfig.NumSRSPorts > simParameters.UETxAnts
                    error('nr5g:hNRUEMAC:InvalidNumSRSPorts', 'Number of SRS antenna ports (%d) must be less than the number of UE Tx antennas.(%d)',...
                        simParameters.SRSConfig.NumSRSPorts, simParameters.UETxAnts)
                end
                obj.SrsConfig = simParameters.SRSConfig;

                % Calculate unique SRS transmission time and periodicity
                obj.SRSTxInfo = calculateSRSPeriodicity(obj, {obj.SrsConfig});
            end

            obj.MCSTableUL = getMCSTableUL(obj);
            obj.MCSTableDL = getMCSTableDL(obj);
            obj.LCHBufferStatus = zeros(1, obj.MaxLogicalChannels);
            obj.LCHBjList = zeros(1, obj.MaxLogicalChannels);
            obj.LogicalChannelsConfig = cell(1, obj.MaxLogicalChannels);
            obj.ElapsedTimeSinceLastLCP = 0;
            obj.TBSizeUL = zeros(obj.NumHARQ, 1);

            % Create carrier configuration object for UL
            obj.CarrierConfigUL = nrCarrierConfig('SubcarrierSpacing', obj.SCS, 'NSizeGrid', simParameters.NumRBs);
            % Create carrier configuration object for DL
            obj.CarrierConfigDL = obj.CarrierConfigUL;

            obj.PDSCHInfo = hNRPDSCHInfo;
            obj.PDSCHInfo.PDSCHConfig.DMRS = nrPDSCHDMRSConfig('DMRSConfigurationType', obj.PDSCHDMRSConfigurationType, ...
                'DMRSTypeAPosition', obj.DMRSTypeAPosition);
            obj.PUSCHInfo = hNRPUSCHInfo;
            obj.PUSCHInfo.PUSCHConfig.DMRS = nrPUSCHDMRSConfig('DMRSConfigurationType', obj.PUSCHDMRSConfigurationType, ...
                'DMRSTypeAPosition', obj.DMRSTypeAPosition);
        end

        function nextInvokeTime = run(obj, currentTime, packets)
            %run Run the UE MAC layer operations and return next invoke time in nanoseconds
            %   NEXTINVOKETIME = run(OBJ, CURRENTTIME, PACKETS) runs the
            %   MAC layer operations and returns the next invoke time (in
            %   nanoseconds).
            %
            %   NEXTINVOKETIME is the next invoke time (in nanoseconds) for
            %   MAC.
            %
            %   CURRENTTIME is the current time (in nanoseconds).
            %
            %   PACKETS are the received packets from other nodes.

            elapsedTime = currentTime - obj.LastRunTime; % In nanoseconds
            % Update the time
            if currentTime > obj.LastRunTime
                % Update LCP timers
                obj.ElapsedTimeSinceLastLCP  = obj.ElapsedTimeSinceLastLCP  + round(elapsedTime*1e-6, 4);
                % Update the last run time
                obj.LastRunTime = currentTime;

                % Find the current AFN
                obj.SFN = mod(floor(currentTime/obj.FrameDurationInNS), 1024);
                absoluteSlotNum = floor(currentTime/obj.SlotDurationInNS);
                % Current slot number in 10 ms frame
                obj.CurrSlot = mod(absoluteSlotNum, obj.NumSlotsFrame);

                if obj.DuplexMode == 1 % TDD
                    % Current slot number in DL-UL pattern
                    obj.CurrDLULSlotIndex = mod(absoluteSlotNum, obj.NumDLULPatternSlots);
                end

                % Find the duration completed in the current slot
                durationCompletedInCurrSlot = mod(currentTime, obj.SlotDurationInNS);
                % Find the current symbol in the current slot
                obj.CurrSymbol = find(durationCompletedInCurrSlot < obj.SymbolEndTimesInSlot, 1) - 1;

                % Update timing info context
                obj.TimingInfo.SFN = obj.SFN;
                obj.TimingInfo.CurrSlot = obj.CurrSlot;
                obj.TimingInfo.CurrSymbol = obj.CurrSymbol;
            end

            % Receive and process control packet
            for pktIdx = 1:numel(packets)
                if isfield(packets{pktIdx}, 'PacketType') && ...
                        packets{pktIdx}.NCellID == obj.NCellID
                    controlRx(obj, packets{pktIdx});
                end
            end

            symNumFrame = obj.CurrSlot * 14 + obj.CurrSymbol;
            if obj.PreviousSymbol == symNumFrame && elapsedTime < obj.SlotDurationInNS/14
                % Return the next invoke time for MAC
                nextInvokeTime = getNextInvokeTime(obj, currentTime);
                % Avoid running MAC operations more than once in the same
                % symbol
                return;
            end

            % Send Tx request to Phy for transmission which is scheduled to start at current
            % symbol. Construct and send the UL MAC PDUs scheduled for
            % current symbol to Phy
            dataTx(obj, currentTime);

            % Send Rx request to Phy for reception which is scheduled to start at current symbol
            dataRx(obj, currentTime);

            % Send BSR, PDSCH feedback (ACK/NACK) and CQI report
            controlTx(obj, currentTime);

            % Send requests to Phy for non-data receptions and
            % transmissions scheduled in this slot (currently only CSI-RS
            % and SRS are supported). Send these requests at the first
            % symbol of the slot
            if obj.CurrSymbol == 0
                dlControlRequest(obj, currentTime);
                ulControlRequest(obj, currentTime);
            end

            % Update the previous symbol to the current symbol in the frame
            obj.PreviousSymbol = symNumFrame;
            % Return the next invoke time for MAC
            nextInvokeTime = getNextInvokeTime(obj, currentTime);
        end

        function dataTx(obj, currentTime)
            %dataTx Construct and send the UL MAC PDUs scheduled for current symbol to Phy
            %
            %   dataTx(OBJ, CURRENTTIME) Based on the uplink grants received in earlier,
            %   if current symbol is the start symbol of a Tx then send the UL MAC PDU to
            %   Phy.
            %
            %   CURRENTTIME is the current time (in nanoseconds).

            symbolNumFrame = obj.CurrSlot*14 + obj.CurrSymbol;
            uplinkGrant = obj.UplinkTxContext{symbolNumFrame + 1};
            % If there is any uplink grant corresponding to which a transmission is scheduled at the current symbol
            if ~isempty(uplinkGrant)
                % Construct and send MAC PDU to Phy
                [sentPDULen, type] = sendMACPDU(obj, uplinkGrant, currentTime);
                obj.UplinkTxContext{symbolNumFrame + 1} = []; % Tx done. Clear the context
                obj.StatTxThroughputBytes = obj.StatTxThroughputBytes + sentPDULen;
                if strcmp(type, 'newTx')
                    obj.StatTxGoodputBytes = obj.StatTxGoodputBytes + sentPDULen;
                end

                rbgMap = uplinkGrant.RBGAllocationBitmap;
                if rbgMap(end) == 1 && mod(obj.NumPUSCHRBs, obj.RBGSizeUL)
                    % If the number of RBs in last RBG is less than RBGSize
                    numRBs = (nnz(rbgMap) - 1) * obj.RBGSizeUL +  mod(obj.NumPUSCHRBs, obj.RBGSizeUL);
                else
                    numRBs = nnz(rbgMap) * obj.RBGSizeUL;
                end
                obj.StatResourceShare = obj.StatResourceShare + numRBs;
            end
        end

        function dataRx(obj, currentTime)
            %dataRx Send Rx start request to Phy for the reception scheduled to start now
            %
            %   dataRx(OBJ, CURRENTTIME) sends the Rx start request to Phy
            %   for the reception scheduled to start now, as per the
            %   earlier received downlink assignments.
            %
            %   CURRENTTIME is the current time (in nanoseconds).

            downlinkGrant = obj.DownlinkRxContext{obj.CurrSlot*14 + obj.CurrSymbol + 1}; % Rx context of current symbol
            if ~isempty(downlinkGrant) % If PDSCH reception is expected
                % Calculate feedback transmission symbol number w.r.t start
                % of 10ms frame
                feedbackSlot = mod(obj.CurrSlot + downlinkGrant.FeedbackSlotOffset, obj.NumSlotsFrame);
                %For TDD, the symbol at which feedback would be transmitted
                %is kept as first UL symbol in feedback slot. For FDD, it
                %simply the first symbol in the feedback slot
                if obj.DuplexMode % TDD
                    feedbackSlotDLULIdx = mod(obj.CurrDLULSlotIndex + downlinkGrant.FeedbackSlotOffset, obj.NumDLULPatternSlots);
                    feedbackSlotPattern = obj.DLULSlotFormat(feedbackSlotDLULIdx + 1, :);
                    feedbackSym = (find(feedbackSlotPattern == obj.ULType, 1, 'first')) - 1; % Check for location of first UL symbol in the feedback slot
                else % FDD
                    feedbackSym = 0;  % First symbol
                end
                obj.PDSCHRxFeedback(downlinkGrant.HARQID+1, 1) = feedbackSlot*14 + feedbackSym; % Set symbol number for PDSCH feedback transmission

                % Absolute feedback symbol number
                obj.PDSCHRxFeedback(downlinkGrant.HARQID+1, 3) = downlinkGrant.FeedbackSlotOffset*14 + feedbackSym;

                rxRequestToPhy(obj, downlinkGrant, currentTime); % Indicate Rx start to Phy
                 % Clear the Rx context
                obj.DownlinkRxContext{(obj.CurrSlot * 14) + obj.CurrSymbol + 1} = [];
            end
        end

        function rxIndication(obj, macPDU, crc, rxInfo)
            %rxIndication Packet reception from Phy
            %   rxIndication(OBJ, MACPDU, CRC, RXINFO) receives a MAC PDU from
            %   Phy.
            %   MACPDU is the PDU received from Phy.
            %   CRC is the success(value as 0)/failure(value as 1)
            %   indication from Phy.
            %   RXINFO is an object of type hNRRxIndicationInfo containing
            %   information about the reception.

            isRxSuccess = ~crc; % CRC value 0 indicates successful reception
            if isRxSuccess % Packet received is error-free
                % Parse Downlink MAC PDU
                [lcidList, sduList] = hNRMACPDUParser(macPDU, obj.DLType);
                for sduIndex = 1:numel(lcidList)
                    if lcidList(sduIndex) >=1 && lcidList(sduIndex) <= 32
                        obj.RLCRxFcn(obj.RNTI, lcidList(sduIndex), sduList{sduIndex});
                    end
                end
                obj.PDSCHRxFeedback(rxInfo.HARQID+1, 2) = 1;  % Positive ACK
            else % Packet corrupted
                obj.PDSCHRxFeedback(rxInfo.HARQID+1, 2) = 0; % NACK
            end
        end

        function dlControlRequest(obj, currentTime)
            % dlControlRequest Request from MAC to Phy to receive non-data DL receptions
            %
            %   dlControlRequest(OBJ, CURRENTTIME) sends a request to Phy for non-data
            %   downlink receptions in the current slot. MAC sends it at
            %   the start of a DL slot for all the scheduled DL receptions
            %   in the slot (except PDSCH, which is received using dataRx
            %   function of this class).
            %
            %   CURRENTTIME is the current time (in nanoseconds).

            % Check if current slot is a slot with DL symbols. For FDD (Value 0),
            % there is no need to check as every slot is a DL slot. For
            % TDD (Value 1), check if current slot has any DL symbols
            if(obj.DuplexMode == 0 || ~isempty(find(obj.DLULSlotFormat(obj.CurrDLULSlotIndex + 1, :) == obj.DLType, 1)))
                dlControlType = zeros(1, 2);
                dlControlPDUs = cell(1, 2);
                numDLControlPDUs = 0;

                if ~isempty(obj.CsirsConfigRSRP)
                    csirsLocations = obj.CsirsConfigRSRP{obj.SSBIdx}.SymbolLocations; % CSI-RS symbol locations
                    if obj.DuplexMode == 0 || all(obj.DLULSlotFormat(obj.CurrDLULSlotIndex + 1, cell2mat(csirsLocations) + 1) == obj.DLType)
                        % Set carrier configuration object
                        carrier = obj.CarrierConfigDL;
                        carrier.NSlot = obj.CurrSlot;
                        carrier.NFrame = obj.SFN;
                        csirsIndRSRP = nrCSIRSIndices(carrier, obj.CsirsConfigRSRP{obj.SSBIdx});

                        if ~isempty(csirsIndRSRP)
                            numDLControlPDUs = numDLControlPDUs + 1;
                            dlControlType(numDLControlPDUs) = hNRPhyInterface.CSIRSPDUType;
                            dlControlPDUs{numDLControlPDUs} = obj.CsirsConfigRSRP{obj.SSBIdx};
                        end
                    end
                end

                if length(obj.CsirsConfig) ~= 1
                    csirsConfig = obj.CsirsConfig{obj.RNTI};
                else
                    csirsConfig = obj.CsirsConfig{1};
                end
                % To account for consecutive symbols in CDM pattern
                additionalCSIRSSyms = [0 0 0 0 1 0 1 1 0 1 1 1 1 1 3 1 1 3];
                csirsSymbolRange = zeros(2, 1);
                csirsSymbolRange(1) = min(csirsConfig.SymbolLocations); % First CSI-RS symbol
                csirsSymbolRange(2) = max(csirsConfig.SymbolLocations) + ... % Last CSI-RS symbol
                    additionalCSIRSSyms(csirsConfig.RowNumber);
                % Check whether the mode is FDD OR if it is TDD then all the CSI-RS symbols must be DL symbols
                if obj.DuplexMode == 0 || all(obj.DLULSlotFormat(obj.CurrDLULSlotIndex + 1, csirsSymbolRange+1) == obj.DLType)
                    % Set carrier configuration object
                    carrier = obj.CarrierConfigDL;
                    carrier.NSlot = obj.CurrSlot;
                    carrier.NFrame = obj.SFN;
                    csirsInd = nrCSIRSIndices(carrier, csirsConfig);
                    if ~isempty(csirsInd)  % Empty value means CSI-RS is not scheduled to be received in the current slot
                        numDLControlPDUs = numDLControlPDUs + 1;
                        dlControlType(numDLControlPDUs) = hNRPhyInterface.CSIRSPDUType;
                        dlControlPDUs{numDLControlPDUs} = csirsConfig;
                    end
                end
                if numDLControlPDUs > 0 % Send request when there is CSI-RS transmission
                    obj.TimingInfo.Timestamp = currentTime;
                    obj.DlControlRequestFcn(dlControlType(1:numDLControlPDUs), dlControlPDUs(1:numDLControlPDUs), obj.TimingInfo); % Send DL control request to Phy
                end
            end
            % Update the next CSI-RS tx times
            idxList = find(obj.CSIRSRxInfo(:, 2) == currentTime);
            obj.CSIRSRxInfo(idxList, 2) = obj.CSIRSRxInfo(idxList, 1) + currentTime;
        end

        function ulControlRequest(obj, currentTime)
            %ulControlRequest Request from MAC to Phy to send non-data UL transmissions
            %   ulControlRequest(OBJ, CURRENTTIME) sends a request to Phy for non-data
            %   uplink transmission scheduled for the current slot. MAC
            %   sends it at the start of a UL slot for all the scheduled UL
            %   transmissions in the slot (except PUSCH, which is sent
            %   using dataTx function of this class).
            %
            %   CURRENTTIME is the current time (in nanoseconds).

            if ~isempty(obj.SrsConfig)
                % Check if current slot is a slot with UL symbols. For FDD (Value 0),
                % there is no need to check as every slot is a UL slot. For
                % TDD (Value 1), check if current slot has any UL symbols
                if(obj.DuplexMode == 0 || ~isempty(find(obj.DLULSlotFormat(obj.CurrDLULSlotIndex + 1, :) == obj.ULType, 1)))
                    ulControlType = [];
                    ulControlPDUs = {};

                    srsLocations = obj.SrsConfig.SymbolStart : (obj.SrsConfig.SymbolStart+obj.SrsConfig.NumSRSSymbols-1); % SRS symbol locations
                    % Check whether the mode is FDD OR if it is TDD then all the SRS symbols must be UL symbols
                    if obj.DuplexMode == 0 || all(obj.DLULSlotFormat(obj.CurrDLULSlotIndex + 1, srsLocations+1) == obj.ULType)
                        % Set carrier configuration object
                        carrier = obj.CarrierConfigUL;
                        carrier.NSlot = obj.CurrSlot;
                        carrier.NFrame = obj.SFN;
                        srsInd = nrSRSIndices(carrier, obj.SrsConfig);
                        if ~isempty(srsInd) % Empty value means SRS is not scheduled to be sent in the current slot
                            ulControlType(1) = hNRPhyInterface.SRSPDUType;
                            ulControlPDUs{1} = obj.SrsConfig;
                        end
                    end
                    obj.TimingInfo.Timestamp = currentTime;
                    obj.UlControlRequestFcn(ulControlType, ulControlPDUs, obj.TimingInfo); % Send UL control request to Phy
                end

                % Update the next SRS tx times
                if obj.SRSTxInfo(2) == currentTime
                    obj.SRSTxInfo(2) = obj.SRSTxInfo(1) + currentTime;
                end
            end
        end

        function csirsIndication(obj, varargin)
            %csirsIndication Reception of CSI measurements from Phy
            %   csirsIndication(OBJ, RANK, PMISET, CQI) receives the DL channel
            %   measurements from Phy, measured on the configured CSI-RS for the
            %   UE.
            %   RANK - Rank indicator
            %   PMISET - PMI set corresponding to RANK. It is a structure
            %   with fields 'i11', 'i12', 'i13', 'i2'.
            %   CQI - CQI corresponding to RANK and PMISET. It is a vector
            %   of size 'N', where 'N' is number of RBs in bandwidth. Value
            %   at index 'i' represents CQI value at RB-index 'i'.
            %
            %   csirsIndication(OBJ, CRI, L1RSRP) receives the DL beam
            %   measurements from Phy, measured on the configured CSI-RS for the UE
            %   CRI - CSI-RS resource indicator. It is a scalar
            %   representing the CSI-RS resource with the highest L1-RSRP
            %   measurement.
            %   L1RSRP - Layer 1 Reference Signal Received Power(L1-RSRP). This
            %   contains the L1-RSRP measurement for the CSI-RS resource
            %   indicated by CRI.

            if nargin == 4
                obj.CSIMeasurement.RankIndicator = varargin{1};
                obj.CSIMeasurement.PMISet = varargin{2};
                obj.CSIMeasurement.CQI = varargin{3};
            elseif nargin == 3
                obj.CSIMeasurement.CRI = varargin{1};
                obj.CSIMeasurement.L1RSRP = varargin{2};
            end
        end

        function controlTx(obj, currentTime)
            %controlTx Send BSR packet, PDSCH feedback and CQI report
            %   controlTx(OBJ, CURRENTTIME) sends the buffer status report
            %   feedback for PDSCH receptions, and DL channel quality
            %   information. These are sent out-of-band to gNB's MAC
            %   without the need of frequency resources

            % Send BSR if its transmission periodicity reached
            if currentTime >= obj.NextBSRTime
                if obj.DuplexMode == 1 % TDD
                    % UL symbol is checked
                    if obj.DLULSlotFormat(obj.CurrDLULSlotIndex + 1, obj.CurrSymbol+1) == obj.ULType % UL symbol
                        bsrTx(obj);
                        obj.NextBSRTime = currentTime + obj.BSRPeriodicityInSF*1e6;
                    else
                        obj.NextBSRTime = currentTime + getNextULSymbolTime(obj); % In nanoseconds
                    end
                else % For FDD, no need to check for UL symbol
                    bsrTx(obj);
                    obj.NextBSRTime = currentTime + obj.BSRPeriodicityInSF*1e6;
                end
            end

            % Send PDSCH feedback (ACK/NACK), if scheduled
            symNumFrame = obj.CurrSlot*14 + obj.CurrSymbol;
            feedback = -1*ones(obj.NumHARQ, 1);
            for harqIdx=1:obj.NumHARQ
                if obj.PDSCHRxFeedback(harqIdx, 1) == symNumFrame % If any feedback is scheduled in current symbol
                    feedback(harqIdx) = obj.PDSCHRxFeedback(harqIdx, 2); % Set the feedback (ACK/NACK)
                    obj.PDSCHRxFeedback(harqIdx, :) = [-1 -1 Inf]; % Clear the context
                end
            end
            if any(feedback ~=-1) % If any PDSCH feedback is scheduled to be sent
                % Construct packet information
                pktInfo.Packet = feedback;
                pktInfo.PacketType = obj.PDSCHFeedback;
                pktInfo.NCellID = obj.NCellID;
                pktInfo.RNTI = obj.RNTI;
                obj.TxOutofBandFcn(pktInfo); % Send the PDSCH feedback out-of-band to gNB's MAC
            end
            
            % Send CSI report(ri-pmi-cqi format) if the transmission periodicity has reached
            if currentTime >= obj.NextCSIReportTime
                obj.NextCSIReportTime = currentTime + obj.CSIReportPeriodicity*1e6; % In nanoseconds
                if isfield(obj.CSIMeasurement, 'CQI')
                    % Construct packet information
                    pktInfo.PacketType = obj.CSIReport;
                    pktInfo.NCellID = obj.NCellID;
                    pktInfo.RNTI = obj.RNTI;

                    if obj.DuplexMode == 1 % TDD
                        % UL symbol is checked
                        if obj.DLULSlotFormat(obj.CurrDLULSlotIndex + 1, obj.CurrSymbol+1) == obj.ULType % UL symbol
                            pktInfo.Packet = obj.CSIMeasurement;
                            obj.TxOutofBandFcn(pktInfo); % Send the CSI report out-of-band to gNB's MAC
                            obj.NextCSIReportTime = currentTime + obj.CSIReportPeriodicity*1e6; % In nanoseconds
                        else
                            % Find next UL symbol
                            obj.NextCSIReportTime = currentTime + getNextULSymbolTime(obj); % In nanoseconds
                        end
                    else % For FDD, no need to check for UL symbol
                        csiReport.RankIndicator = obj.CSIMeasurement.RankIndicator;
                        csiReport.PMISet = obj.CSIMeasurement.PMISet;
                        csiReport.CQI = obj.CSIMeasurement.CQI;
                        pktInfo.Packet = csiReport;
                        obj.TxOutofBandFcn(pktInfo); % Send the CSI report out-of-band to gNB's MAC
                        obj.NextCSIReportTime = currentTime + obj.CSIReportPeriodicity*1e6; % In nanoseconds
                    end
                end
            end

            % Send CSI report(CRI-RSRP format) if the transmission periodicity has reached
            if currentTime >= obj.NextRSRPReportTime
                obj.NextRSRPReportTime = currentTime + obj.RSRPReportPeriodicity*1e6; % In nanoseconds
                if isfield(obj.CSIMeasurement, 'CRI')
                    % Construct packet information
                    pktInfo.PacketType = obj.CSIReportRSRP;
                    pktInfo.NCellID = obj.NCellID;
                    pktInfo.RNTI = obj.RNTI;

                    if (obj.DuplexMode == 1 && obj.DLULSlotFormat(obj.CurrDLULSlotIndex + 1, obj.CurrSymbol+1) == obj.ULType) || (obj.DuplexMode == 0)
                        criRSRPReport.CRI = obj.CSIMeasurement.CRI;
                        criRSRPReport.L1RSRP = obj.CSIMeasurement.L1RSRP;
                        pktInfo.Packet = criRSRPReport;
                        obj.TxOutofBandFcn(pktInfo); % Send the CSI report out-of-band to gNB's MAC
                        obj.NextRSRPReportTime = currentTime + obj.RSRPReportPeriodicity*1e6; % In nanoseconds
                    elseif obj.DuplexMode == 1
                        % Find next UL symbol
                        obj.NextRSRPReportTime = currentTime + getNextULSymbolTime(obj); % In nanoseconds
                    end
                end
            end
        end

        function controlRx(obj, pktInfo)
            %controlRx Receive callback for uplink and downlink grants for this UE

            if obj.RNTI ~= pktInfo.RNTI
                % Don't process the unintended packet
                return;
            end

            pktType = pktInfo.PacketType;
            switch(pktType)
                case obj.ULGrant % Uplink grant received
                    uplinkGrant = pktInfo.Packet;
                    % Store the uplink grant at the corresponding Tx start
                    % symbol. The uplink grant is later used for PUSCH
                    % transmission at the transmission time defined by
                    % uplink grant
                    numSymFrame = obj.NumSlotsFrame * 14; % Number of symbols in 10 ms frame
                    txStartSymbol = mod((obj.CurrSlot + uplinkGrant.SlotOffset)*14 + uplinkGrant.StartSymbol, numSymFrame);
                    % Store the grant at the PUSCH start symbol w.r.t the 10 ms frame
                    obj.UplinkTxContext{txStartSymbol + 1} = uplinkGrant;

                case obj.DLGrant % Downlink grant received
                    downlinkGrant = pktInfo.Packet;
                    % Store the downlink grant at the corresponding Rx start
                    % symbol. The downlink grant is later used for PDSCH
                    % reception at the reception time defined by
                    % downlink grant
                    numSymFrame = obj.NumSlotsFrame * 14; % Number of symbols in 10 ms frame
                    rxStartSymbol = mod((obj.CurrSlot + downlinkGrant.SlotOffset)*14 + downlinkGrant.StartSymbol, numSymFrame);
                    obj.DownlinkRxContext{rxStartSymbol + 1} = downlinkGrant; % Store the grant at the PDSCH start symbol w.r.t the 10 ms frame
            end
        end

        function buffStatus = getUEBufferStatus(obj)
            %getUEBufferStatus Get the pending buffer amount (bytes) on the UE
            %
            %   BUFFSTATUS = getUEBufferStatus(OBJ) Returns the pending
            %   buffer amount (bytes) on the UE
            %
            %   BUFFSTATUS - Represents the buffer size in bytes.

            buffStatus = sum(obj.LCGBufferStatus);
        end

        function cqiRBs = getChannelQualityStatus(obj)
            %getChannelQualityStatus Get DL CQI values for the RBs of bandwidth
            %
            %   CQIRBS = getChannelQualityStatus(OBJ) gets DL CQI values for
            %   the RBs of bandwidth.
            %
            %   CQIRBS - It is a vector of size 'N', where 'N' is number of
            %   RBs in bandwidth. Value at index 'i' represents CQI value at
            %   RB-index 'i'.
            cqiRBs = obj.CSIMeasurement.CQI(:);
        end

        function updateChannelQualityDL(obj, channelQualityInfo)
            %updateChannelQualityDL Update downlink channel quality information for a UE
            %   UPDATECHANNELQUALITYDL(OBJ, CHANNELQUALITYINFO) updates
            %   downlink (DL) channel quality information for a UE.
            %   CHANNELQUALITYINFO is a structure with following fields.
            %       RNTI - RNTI of the UE
            %       RankIndicator - Rank indicator for the UE
            %       PMISet - Precoding matrix indicator. It is a structure with following fields.
            %           i1 - Indicates wideband PMI (1-based). It a three-element vector in the
            %                form of [i11 i12 i13].
            %           i2 - Indicates subband PMI (1-based). It is a vector of length equal to
            %                the number of subbands or number of PRGs.
            %       CQI - CQI corresponding to RANK and TPMI. It is a
            %       vector of size 'N', where 'N' is number of RBs in UL
            %       bandwidth. Value at index 'i' represents CQI value at
            %       RB-index 'i'

            obj.CSIMeasurement.CQI = channelQualityInfo.CQI;
            if isfield(channelQualityInfo, 'PMISet')
                obj.CSIMeasurement.PMISet = channelQualityInfo.PMISet;
            end
            if isfield(channelQualityInfo, 'RankIndicator')
                obj.CSIMeasurement.RankIndicator = channelQualityInfo.RankIndicator;
            end
        end

        function lastNDIs = getLastNDIFlagHarq(obj, linkDir)
            %getLastNDIFlagHarq Return the last received NDI flag for the UL/DL HARQ processes

            % LASTNDISTATUS = getLastNDIFlagHarq(OBJ, LINKDIR) Returns last
            % received NDI flag value at UE, for all the HARQ processes of
            % the specified link direction, LINKDIR (Value 0 for DL and
            % Value 1 for UL).
            %
            % LASTNDISTATUS - It is a vector of integers of size equals to
            % the number of HARQ processes. It contains the last received
            % NDI flag value for the HARQ processes.

            lastNDIs = zeros(obj.NumHARQ,1);
            for i=1:obj.NumHARQ
                if linkDir % UL
                    lastNDIs(i) = obj.HARQNDIUL(i); % Read NDI of UL HARQ process
                else % DL
                    lastNDIs(i) = obj.HARQNDIDL(i); % Read NDI of DL HARQ process
                end
            end
        end

        function updateBufferStatus(obj, lcBufferStatus)
            %updateBufferStatus Update the buffer status of the logical channel
            %
            %   updateBufferStatus(OBJ, LCBUFFERSTATUS) Updates the buffer
            %   status of a logical channel based on information present in
            %   LCBUFFERSTATUS object
            %
            %   LCBUFFERSTATUS - Represents an object which contains the
            %   current buffer status of a logical channel. It contains the
            %   following properties:
            %       RNTI                    - UE's radio network temporary identifier
            %       LogicalChannelID        - Logical channel identifier
            %       BufferStatus            - Number of bytes in the logical
            %                                 channel's Tx buffer

            lcgID = -1;
            for i = 1:length(obj.LogicalChannelsConfig)
                if ~isempty(obj.LogicalChannelsConfig{i}) && (obj.LogicalChannelsConfig{i}.LCID == lcBufferStatus.LogicalChannelID)
                    lcgID = obj.LogicalChannelsConfig{i}.LCGID;
                    break;
                end
            end
            if lcgID == -1
                error('nr5g:hNRUEMAC:InvalidLCIDMapping', ['The logical channel with id ', lcBufferStatus.LogicalChannelID, ' is not mapped to any LCG id']);
            end
            % Subtract from the old buffer status report of the corresponding
            % logical channel
            lcgIdIndex = lcgID + 1; % Indexing starts from 1

            % Update the buffer status of LCG to which this logical channel
            % belongs to. Subtract the current logical channel buffer
            % amount and adding the new amount
            obj.LCGBufferStatus(lcgIdIndex) = obj.LCGBufferStatus(lcgIdIndex) -  ...
                obj.LCHBufferStatus(lcBufferStatus.LogicalChannelID) + lcBufferStatus.BufferStatus;

            % Update the new buffer status
            obj.LCHBufferStatus(lcBufferStatus.LogicalChannelID) = lcBufferStatus.BufferStatus;
        end

        function [throughputServing, goodputServing] = getTTIBytes(obj)
            %getTTIBytes Return the amount of throughput and goodput MAC
            %bytes sent till current time
            %
            % [THROUGHPUTPUTSERVING, GOODPUTPUTSERVING] =
            % getTTIBytes(OBJ) returns the amount of throughput and
            % goodput bytes sent till current time
            %
            % THROUGHPUTPUTSERVING represents the amount of MAC bytes sent
            % as per the uplink assignments till current time
            %
            % GOODPUTPUTSERVING represents the amount of new-Tx MAC bytes
            % sent as per the uplink assignments till current time
            %
            % Throughput and goodput bytes are same, if it is new
            % transmission. For retransmission, goodput is zero

            throughputServing = obj.StatTxThroughputBytes;
            goodputServing = obj.StatTxGoodputBytes;
        end
    end

    methods (Access = private)
        function [pduLen, type] = sendMACPDU(obj, uplinkGrant, currentTime)
            %sendMACPDU Send MAC PDU as per the parameters of the uplink grant
            % Uplink grant and its parameters were sent beforehand by gNB
            % in uplink grant. Based on the NDI received in the uplink
            % grant, either the packet in the HARQ buffer would be retransmitted
            % or a new MAC packet would be sent

            macPDU = [];
            % Populate PUSCH information to be sent to Phy, along with the MAC
            % PDU
            puschInfo = obj.PUSCHInfo;
            RBGAllocationBitmap = uplinkGrant.RBGAllocationBitmap;
            ULGrantRBs = -1*ones(obj.NumPUSCHRBs, 1); % To store RB indices of UL grant
            for RBGIndex = 0:(length(RBGAllocationBitmap)-1) % Get RB indices of UL grant
                if RBGAllocationBitmap(RBGIndex+1)
                    % If the last RBG of BWP is assigned, then it might
                    % not have the same number of RBs as other RBG
                    startRBInRBG = obj.RBGSizeUL*RBGIndex;
                    if RBGIndex == (length(RBGAllocationBitmap)-1)
                        ULGrantRBs(startRBInRBG + 1 : end) =  ...
                            startRBInRBG : obj.NumPUSCHRBs-1 ;
                    else
                        ULGrantRBs((startRBInRBG + 1) : (startRBInRBG + obj.RBGSizeUL)) =  ...
                            startRBInRBG : (startRBInRBG + obj.RBGSizeUL -1);
                    end
                end
            end
            ULGrantRBs = ULGrantRBs(ULGrantRBs >= 0);
            puschInfo.PUSCHConfig.PRBSet = ULGrantRBs;
            % Get the corresponding row from the mcs table
            mcsInfo = obj.MCSTableUL(uplinkGrant.MCS + 1, :);
            modSchemeBits = mcsInfo(1); % Bits per symbol for modulation scheme (stored in column 1)
            puschInfo.TargetCodeRate = mcsInfo(2)/1024; % Coderate (stored in column 2)
            modScheme = modSchemeStr(obj, modSchemeBits);
            puschInfo.PUSCHConfig.Modulation = modScheme(1);
            puschInfo.PUSCHConfig.RNTI = obj.RNTI;
            puschInfo.PUSCHConfig.SymbolAllocation = [uplinkGrant.StartSymbol uplinkGrant.NumSymbols];
            puschInfo.PUSCHConfig.NID = obj.NCellID;
            puschInfo.NSlot = obj.CurrSlot;
            puschInfo.HARQID = uplinkGrant.HARQID;
            puschInfo.RV = uplinkGrant.RV;
            puschInfo.PUSCHConfig.MappingType = uplinkGrant.MappingType;
            puschInfo.PUSCHConfig.TransmissionScheme = 'codebook';
            puschInfo.PUSCHConfig.NumLayers = uplinkGrant.NumLayers;
            puschInfo.PUSCHConfig.NumAntennaPorts = uplinkGrant.NumAntennaPorts;
            puschInfo.PUSCHConfig.TPMI = uplinkGrant.TPMI;
            if isequal(uplinkGrant.MappingType, 'A')
                dmrsAdditonalPos = obj.PUSCHDMRSAdditionalPosTypeA;
            else
                dmrsAdditonalPos = obj.PUSCHDMRSAdditionalPosTypeB;
            end
            puschInfo.PUSCHConfig.DMRS.DMRSLength = uplinkGrant.DMRSLength;
            puschInfo.PUSCHConfig.DMRS.DMRSAdditionalPosition = dmrsAdditonalPos;
            puschInfo.PUSCHConfig.DMRS.NumCDMGroupsWithoutData = uplinkGrant.NumCDMGroupsWithoutData;

            % Carrier configuration
            carrierConfig = obj.CarrierConfigUL;
            carrierConfig.NSlot = puschInfo.NSlot;

            uplinkGrantHARQId =  uplinkGrant.HARQID;
            lastNDI = obj.HARQNDIUL(uplinkGrantHARQId+1); % Last receive NDI for this HARQ process
            if uplinkGrant.NDI ~= lastNDI
                % NDI has been toggled, so send a new MAC packet. This acts
                % as an ACK for the last sent packet of this HARQ process,
                % in addition to acting as an uplink grant
                type = 'newTx';
                % TBS calculation
                [~, puschIndicesInfo] = nrPUSCHIndices(carrierConfig, puschInfo.PUSCHConfig); % Calculate PUSCH indices
                tbs = nrTBS(puschInfo.PUSCHConfig.Modulation, puschInfo.PUSCHConfig.NumLayers, length(ULGrantRBs), ...
                    puschIndicesInfo.NREPerPRB, puschInfo.TargetCodeRate); % TBS calcuation
                pduLen = floor(tbs/8); % In bytes
                % Generate MAC PDU
                macPDU = constructMACPDU(obj, pduLen);
                % Store the uplink grant NDI for this HARQ process which
                % will be used in taking decision of 'newTx' or 'reTx' when
                % an uplink grant for the same HARQ process comes
                obj.HARQNDIUL(uplinkGrantHARQId+1) = uplinkGrant.NDI; % Update NDI
                obj.TBSizeUL(uplinkGrantHARQId+1) = pduLen;
            else
                type = 'reTx';
                pduLen = obj.TBSizeUL(uplinkGrantHARQId+1);
            end
            puschInfo.TBS = pduLen;
            obj.TimingInfo.Timestamp = currentTime;
            obj.TxDataRequestFcn(puschInfo, macPDU, obj.TimingInfo);
        end

        function rxRequestToPhy(obj, downlinkGrant, currentTime)
            % Send Rx request to Phy

            pdschInfo = obj.PDSCHInfo; % Information to be passed to Phy for PDSCH reception
            RBGAllocationBitmap = downlinkGrant.RBGAllocationBitmap;
            DLGrantRBs = -1*ones(obj.NumPDSCHRBs, 1); % To store RB indices of DL grant
            for RBGIndex = 0:(length(RBGAllocationBitmap)-1) % Get RB indices of DL grant
                if RBGAllocationBitmap(RBGIndex+1) == 1
                    startRBInRBG = obj.RBGSizeDL * RBGIndex;
                    % If the last RBG of BWP is assigned, then it might
                    % not have the same number of RBs as other RBG
                    if RBGIndex == (length(RBGAllocationBitmap)-1)
                        DLGrantRBs((startRBInRBG+1) : end) =  ...
                            startRBInRBG : obj.NumPDSCHRBs-1 ;
                    else
                        DLGrantRBs((startRBInRBG+1) : (startRBInRBG + obj.RBGSizeDL)) =  ...
                            startRBInRBG : (startRBInRBG + obj.RBGSizeDL -1) ;
                    end
                end
            end
            DLGrantRBs = DLGrantRBs(DLGrantRBs >= 0);
            pdschInfo.PDSCHConfig.PRBSet = DLGrantRBs;
            % Get the corresponding row from the mcs table
            mcsInfo = obj.MCSTableDL(downlinkGrant.MCS + 1, :);
            modSchemeBits = mcsInfo(1); % Bits per symbol for modulation scheme(stored in column 1)
            pdschInfo.TargetCodeRate = mcsInfo(2)/1024; % Coderate (stored in column 2)
            modScheme = modSchemeStr(obj, modSchemeBits);
            pdschInfo.PDSCHConfig.Modulation = modScheme(1);
            pdschInfo.PDSCHConfig.RNTI = obj.RNTI;
            pdschInfo.PDSCHConfig.NID = obj.NCellID;
            pdschInfo.PDSCHConfig.SymbolAllocation = [downlinkGrant.StartSymbol downlinkGrant.NumSymbols];
            pdschInfo.NSlot = obj.CurrSlot;
            pdschInfo.PDSCHConfig.MappingType = downlinkGrant.MappingType;
            pdschInfo.PDSCHConfig.NumLayers = downlinkGrant.NumLayers;
            if isequal(downlinkGrant.MappingType, 'A')
                dmrsAdditonalPos = obj.PDSCHDMRSAdditionalPosTypeA;
            else
                dmrsAdditonalPos = obj.PDSCHDMRSAdditionalPosTypeB;
            end
            pdschInfo.PDSCHConfig.DMRS.DMRSLength = downlinkGrant.DMRSLength;
            pdschInfo.PDSCHConfig.DMRS.DMRSAdditionalPosition = dmrsAdditonalPos;
            pdschInfo.PDSCHConfig.DMRS.NumCDMGroupsWithoutData = downlinkGrant.NumCDMGroupsWithoutData;

            % Carrier configuration
            carrierConfig = obj.CarrierConfigDL;
            carrierConfig.NSlot = pdschInfo.NSlot;
            carrierConfig.NFrame = obj.SFN;

            if obj.HARQNDIDL(downlinkGrant.HARQID+1) ~= downlinkGrant.NDI % NDI toggled: new transmission
                % Calculate TBS
                [~, pdschIndicesInfo] = nrPDSCHIndices(carrierConfig, pdschInfo.PDSCHConfig); % Calculate PDSCH indices
                tbs = nrTBS(pdschInfo.PDSCHConfig.Modulation, pdschInfo.PDSCHConfig.NumLayers, length(DLGrantRBs), ...
                    pdschIndicesInfo.NREPerPRB, pdschInfo.TargetCodeRate, obj.XOverheadPDSCH); % Calculate the transport block size
                pdschInfo.TBS = floor(tbs/8);
                obj.TBSizeDL(downlinkGrant.HARQID+1) = pdschInfo.TBS;
            else % Retransmission
                % Use TBS of the original transmission
                pdschInfo.TBS = obj.TBSizeDL(downlinkGrant.HARQID+1);
            end

            obj.HARQNDIDL(downlinkGrant.HARQID+1) = downlinkGrant.NDI; % Update the stored NDI for HARQ process
            pdschInfo.HARQID = downlinkGrant.HARQID;
            pdschInfo.RV = downlinkGrant.RV;

            % Set reserved REs information. Generate 0-based
            % carrier-oriented CSI-RS indices in linear indexed form
            for csirsIdx = 1:length(obj.CsirsConfig)
                csirsLocations = obj.CsirsConfig{csirsIdx}.SymbolLocations; % CSI-RS symbol locations
                if obj.DuplexMode == 0 || all(obj.DLULSlotFormat(obj.CurrDLULSlotIndex + 1, csirsLocations+1) == obj.DLType)
                    % (Mode is FDD) OR (Mode is TDD And CSI-RS symbols are DL symbols)
                    pdschInfo.PDSCHConfig.ReservedRE = [pdschInfo.PDSCHConfig.ReservedRE ; ...
                        nrCSIRSIndices(carrierConfig, obj.CsirsConfig{csirsIdx}, 'IndexBase', '0based')]; % Reserve CSI-RS REs
                end
            end
            for idx = 1:length(obj.CsirsConfigRSRP)
                csirsLocations = obj.CsirsConfigRSRP{idx}.SymbolLocations; % CSI-RS symbol locations
                if obj.DuplexMode == 0 || all(obj.DLULSlotFormat(obj.CurrDLULSlotIndex + 1, cell2mat(csirsLocations)+1) == obj.DLType)
                    % (Mode is FDD) OR (Mode is TDD And CSI-RS symbols are DL symbols)
                    pdschInfo.PDSCHConfig.ReservedRE = [pdschInfo.PDSCHConfig.ReservedRE ; ...
                        nrCSIRSIndices(carrierConfig, obj.CsirsConfigRSRP{idx}, 'IndexBase', '0based')]; % Reserve CSI-RS REs
                end
            end

            obj.TimingInfo.Timestamp = currentTime;
            % Call Phy to start receiving PDSCH
            obj.RxDataRequestFcn(pdschInfo, obj.TimingInfo);
        end

        function bsrTx(obj)
            %bsrTx Construct and send a BSR

            % Construct BSR
            [lcid, bsr] = nrMACBSR(obj.LCGBufferStatus);
            % Generate the subPDU
            subPDU = nrMACSubPDU(obj.ULType, lcid, bsr);
            % Construct packet information
            pktInfo.Packet = subPDU;
            pktInfo.PacketType = obj.BSR;
            pktInfo.NCellID = obj.NCellID;
            pktInfo.RNTI = obj.RNTI;
            obj.TxOutofBandFcn(pktInfo); % Send the BSR out-of-band to gNB's MAC
        end

        function populateTDDConfiguration(obj, simParameters)
            %populateTDDConfiguration Validate TDD configuration and
            %populate the properties

            % Validate the DL-UL pattern duration
            validDLULPeriodicity{1} =  { 1 2 5 10 }; % Applicable for scs = 15 kHz
            validDLULPeriodicity{2} =  { 0.5 1 2 2.5 5 10 }; % Applicable for scs = 30 kHz
            validDLULPeriodicity{3} =  { 0.5 1 1.25 2 2.5 5 10 }; % Applicable for scs = 60 kHz
            validDLULPeriodicity{4} =  { 0.5 0.625 1 1.25 2 2.5 5 10}; % Applicable for scs = 120 kHz
            validSCS = [15 30 60 120];
            if ~ismember(obj.SCS, validSCS)
                error('nr5g:hNRUEMAC:InvalidSCS','The subcarrier spacing ( %d ) must be one of the set (%s).',obj.SCS, sprintf(repmat('%d ', 1, length(validSCS)), validSCS));
            end
            numerology = find(validSCS==obj.SCS, 1, 'first');
            validSet = cell2mat(validDLULPeriodicity{numerology});

            if isfield(simParameters, 'DLULPeriodicity')
                validateattributes(simParameters.DLULPeriodicity, {'numeric'}, {'nonempty'}, 'simParameters.DLULPeriodicity', 'DLULPeriodicity');
                if ~ismember(simParameters.DLULPeriodicity, cell2mat(validDLULPeriodicity{numerology}))
                    error('nr5g:hNRUEMAC:InvalidNumDLULSlots','DLULPeriodicity (%.3f) must be one of the set (%s).', ...
                        simParameters.DLULPeriodicity, sprintf(repmat('%.3f ', 1, length(validSet)), validSet));
                end
                numSlotsDLDULPattern = simParameters.DLULPeriodicity/(obj.SlotDurationInNS*1e-6);

                % Validate the number of full DL slots at the beginning of DL-UL pattern
                validateattributes(simParameters.NumDLSlots, {'numeric'}, {'nonempty'}, 'simParameters.NumDLSlots', 'NumDLSlots');
                if~(simParameters.NumDLSlots <= (numSlotsDLDULPattern-1))
                    error('nr5g:hNRUEMAC:InvalidNumDLSlots','Number of full DL slots (%d) must be less than numSlotsDLDULPattern(%d).', ...
                        simParameters.NumDLSlots, numSlotsDLDULPattern);
                end

                % Validate the number of full UL slots at the end of DL-UL pattern
                validateattributes(simParameters.NumULSlots, {'numeric'}, {'nonempty'}, 'simParameters.NumULSlots', 'NumULSlots');
                if~(simParameters.NumULSlots <= (numSlotsDLDULPattern-1))
                    error('nr5g:hNRUEMAC:InvalidNumULSlots','Number of full UL slots (%d) must be less than numSlotsDLDULPattern(%d).', ...
                        simParameters.NumULSlots, numSlotsDLDULPattern);
                end

                if~(simParameters.NumDLSlots + simParameters.NumULSlots  <= (numSlotsDLDULPattern-1))
                    error('nr5g:hNRUEMAC:InvalidNumDLULSlots','Sum of full DL and UL slots(%d) must be less than numSlotsDLDULPattern(%d).', ...
                        simParameters.NumDLSlots + simParameters.NumULSlots, numSlotsDLDULPattern);
                end

                % Validate that there must be some UL resources in the DL-UL pattern
                if obj.SchedulingType == 0 && simParameters.NumULSlots == 0
                    error('nr5g:hNRUEMAC:InvalidNumULSlots','Number of full UL slots (%d) must be greater than {0} for slot based scheduling', simParameters.NumULSlots);
                end
                if obj.SchedulingType == 1 && simParameters.NumULSlots == 0 && simParameters.NumULSyms == 0
                    error('nr5g:hNRUEMAC:InvalidULResources','DL-UL pattern must contain UL resources. Set NumULSlots(%d) or NumULSyms(%d) to a positive integer).', ...
                        simParameters.NumULSlots, simParameters.NumULSyms);
                end
                % Validate that there must be some DL resources in the DL-UL pattern
                if(simParameters.NumDLSlots == 0 && simParameters.NumDLSyms == 0)
                    error('nr5g:hNRUEMAC:InvalidDLResources','DL-UL pattern must contain DL resources. Set NumDLSlots(%d) or NumDLSyms(%d) to a positive integer).', ...
                        simParameters.NumDLSlots, simParameters.NumDLSyms);
                end

                obj.NumDLULPatternSlots = simParameters.DLULPeriodicity/(obj.SlotDurationInNS*1e-6);
                obj.NumDLSlots = simParameters.NumDLSlots;
                obj.NumULSlots = simParameters.NumULSlots;
                obj.NumDLSyms = simParameters.NumDLSyms;
                obj.NumULSyms = simParameters.NumULSyms;

                % All the remaining symbols in DL-UL pattern are assumed to
                % be guard symbols
                obj.GuardDuration = (obj.NumDLULPatternSlots * 14) - ...
                    (((obj.NumDLSlots + obj.NumULSlots)*14) + ...
                    obj.NumDLSyms + obj.NumULSyms);
            end
        end

        function modScheme = modSchemeStr(~, modSchemeBits)
            %modSchemeStr Return the modulation scheme string based on modulation scheme bits

            % Modulation scheme and corresponding bits/symbol
            fullmodlist = ["pi/2-BPSK", "BPSK", "QPSK", "16QAM", "64QAM", "256QAM"]';
            qm = [1 1 2 4 6 8];
            modScheme = fullmodlist((modSchemeBits == qm)); % Get modulation scheme string
        end

        function nextInvokeTime = getNextInvokeTime(obj, currentTime)
            %getNextInvokeTime Return the next invoke time in nanoseconds

            % Find the duration completed in the current symbol
            durationCompletedInCurrSlot = mod(currentTime, obj.SlotDurationInNS);
            currSymDurCompleted = obj.SymbolDurationsInSlot(obj.CurrSymbol+1) - obj.SymbolEndTimesInSlot(obj.CurrSymbol+1) + durationCompletedInCurrSlot;

            symbolNumFrame = obj.CurrSlot*14 + obj.CurrSymbol;
            totalSymbols = obj.NumSymInFrame;
            nextInvokeTime = inf;

            % Next Tx start symbol
            nextTxSymbol = find(~cellfun('isempty',obj.UplinkTxContext(symbolNumFrame+2:totalSymbols)), 1);
            if isempty(nextTxSymbol)
                nextTxSymbol = (totalSymbols-symbolNumFrame) + find(~cellfun('isempty',obj.UplinkTxContext(1:symbolNumFrame)), 1);
            end

            % Next Rx start symbol
            nextRxSymbol = find(~cellfun('isempty',obj.DownlinkRxContext(symbolNumFrame+2:totalSymbols)), 1);
            if isempty(nextRxSymbol)
                nextRxSymbol = (totalSymbols-symbolNumFrame) + find(~cellfun('isempty',obj.DownlinkRxContext(1:symbolNumFrame)), 1);
            end

            nextInvokeSymbol = min([inf nextTxSymbol nextRxSymbol min(obj.PDSCHRxFeedback(:, 3))]);
            if nextInvokeSymbol ~= inf
                numSlots = floor(nextInvokeSymbol/14);
                numSymbols = mod(nextInvokeSymbol,14);
                if obj.CurrSymbol + numSymbols > 14
                    totalSymbolDuration = sum(obj.SymbolDurationsInSlot(obj.CurrSymbol+1:14)) + sum(obj.SymbolDurationsInSlot(1:obj.CurrSymbol+numSymbols-14));
                else
                    totalSymbolDuration = sum(obj.SymbolDurationsInSlot(obj.CurrSymbol+1:obj.CurrSymbol+numSymbols));
                end
                nextInvokeTime = currentTime + (numSlots * obj.SlotDurationInNS) + totalSymbolDuration - currSymDurCompleted;
            end

            % Control Tx
            controlTxStartTime = min([obj.NextRSRPReportTime obj.NextBSRTime obj.NextCSIReportTime obj.SRSTxInfo(2)]);
            % Control Rx
            controlRxStartTime = min(obj.CSIRSRxInfo(:, 2));

            nextInvokeTime = min([nextInvokeTime controlTxStartTime controlRxStartTime]);
        end

        function totDuration = getNextULSymbolTime(obj)
            %getNextULSymbolTime Return the next UL time

            % Find the next UL symbol in the current slot
            ulSymbols = find(obj.DLULSlotFormat(obj.CurrDLULSlotIndex + 1, obj.CurrSymbol+2:end) == obj.ULType, 1);
            if isempty(ulSymbols) % Find the next UL symbol in the future slots
                totDuration = sum(obj.SymbolDurationsInSlot(obj.CurrSymbol+1:end));
                numDLULSlots = size(obj.DLULSlotFormat, 1);
                for idx=1:numDLULSlots
                    dlulSlotIndex = mod(obj.CurrDLULSlotIndex+idx, numDLULSlots);
                    ulSymbols = find(obj.DLULSlotFormat(dlulSlotIndex+1, 1:14) == obj.ULType, 1);
                    if isempty(ulSymbols)
                        totDuration = totDuration + obj.SlotDurationInNS;
                    else
                        totDuration = totDuration + sum(obj.SymbolDurationsInSlot(1:ulSymbols-1));
                        break;
                    end
                end
            else % UL symbol is present in the current slot
                totDuration = sum(obj.SymbolDurationsInSlot(obj.CurrSymbol+1:obj.CurrSymbol+ulSymbols));
            end
        end
    end
end