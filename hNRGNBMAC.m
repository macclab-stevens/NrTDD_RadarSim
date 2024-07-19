classdef hNRGNBMAC < hNRMAC
    %hNRGNBMAC Implements gNB MAC functionality
    %   The class implements the gNB MAC and its interactions with RLC and
    %   Phy for Tx and Rx chains. Both, frequency division duplex (FDD) and
    %   time division duplex (TDD) modes are supported. It contains
    %   scheduler entity which takes care of uplink (UL) and downlink (DL)
    %   scheduling. Using the output of UL and DL schedulers, it implements
    %   transmission of UL and DL assignments. UL and DL assignments are
    %   sent out-of-band from MAC itself (without using frequency resources
    %   and with guaranteed reception), as physical downlink control
    %   channel (PDCCH) is not modeled. Physical uplink control channel
    %   (PUCCH) is not modeled too, so the control packets from UEs: buffer
    %   status report (BSR), PDSCH feedback, and DL channel state
    %   information (CSI) report are also received out-of-band. Hybrid
    %   automatic repeat request (HARQ) control mechanism to enable
    %   retransmissions is implemented. MAC controls the HARQ processes
    %   residing in physical layer

    %   Copyright 2019-2022 The MathWorks, Inc.

    properties
        %UEs RNTIs of the UEs connected to the gNB
        UEs {mustBeInteger, mustBeInRange(UEs, 1, 65519)};

        %SCS Subcarrier spacing used. The default value is 15 kHz
        SCS (1, 1) {mustBeMember(SCS, [15, 30, 60, 120])} = 15;

        %SFN System frame number (0 ... 1023)
        SFN = 0;

        %CurrSlot Current running slot number in the 10 ms frame
        CurrSlot = 0;

        %CurrSymbol Current running symbol number of the current slot
        CurrSymbol = 0;

        %CurrDLULSlotIndex Slot index of the current running slot in the DL-UL pattern (for TDD mode)
        CurrDLULSlotIndex = 0;

        %Scheduler Scheduler object
        Scheduler

        %DownlinkTxContext Tx context used for PDSCH transmissions
        % N-by-P cell array where is N is number of UEs and 'P' is number of
        % symbols in a 10 ms frame. An element at index (i, j) stores the
        % downlink grant for UE 'i' with PDSCH transmission scheduled to
        % start at symbol 'j' from the start of the frame. If no PDSCH
        % transmission scheduled, cell element is empty
        DownlinkTxContext

        %UplinkRxContext Rx context used for PUSCH reception
        % N-by-P cell array where 'N' is the number of UEs and 'P' is the
        % number of symbols in a 10 ms frame. It stores uplink resource
        % assignment details done to UEs. This is used by gNB in the
        % reception of uplink packets. An element at position (i, j) stores
        % the uplink grant corresponding to a PUSCH reception expected from
        % UE 'i' starting at symbol 'j' from the start of the frame. If
        % there no assignment, cell element is empty
        UplinkRxContext

        %RxContextFeedback Rx context at gNB used for feedback reception (ACK/NACK) of PDSCH transmissions
        % N-by-P-by-K cell array where 'N' is the number of UEs, 'P' is the
        % number of symbols in a 10 ms frame and K is the number of
        % downlink HARQ processes. This is used by gNB in the reception of
        % ACK/NACK from UEs. An element at index (i, j, k) in this array,
        % stores the downlink grant for the UE with RNTI 'i' where
        % 'j' is the symbol number from the start of the frame where
        % ACK/NACK is expected for UE's HARQ process number 'k'
        RxContextFeedback

        %NumHARQ Number of HARQ processes. The default value is 16
        NumHARQ (1, 1) {mustBeInteger, mustBeInRange(NumHARQ, 1, 16)} = 16;

        %CsirsConfig CSI-RS resource configuration for all the UEs
        % Cell array containing the CSI-RS configuration information as an
        % object of type nrCSIRSConfig. The element at index 'i' corresponds
        % to the CSI-RS configured for a UE with RNTI 'i'. If only one CSI-RS
        % configuration is specified, it is assumed to be applicable for
        % all the UEs in the cell.
        CsirsConfig

        %CsirsConfigRSRP CSI-RS resource set configurations corresponding to the SSB directions
        % It is a cell array of length N-by-1 where 'N' is the number of
        % maximum number of SSBs in a SSB burst. Each element of the array
        % at index 'i' corresponds to the CSI-RS resource set associated
        % with SSB 'i'. The number of CSI-RS resources in each resource
        % set is same for all configurations.
        CsirsConfigRSRP

        %SrsConfig Sounding reference signal (SRS) resource configuration for the UEs
        % It is a cell array of size equal to number of UEs. An element at
        % index 'i' is an object of type nrSRSConfig and stores the SRS
        % configuration of UE with RNTI 'i'
        SrsConfig

        %CurrDLAssignments DL assignments done by scheduler on running at current symbol
        % This information is used for logging. If scheduler did not run or did not do any
        % DL assignment at the current symbol this is empty
        CurrDLAssignments = {};

        %SISOChannelReciprocity Channel reciprocity flag (only applicable for SISO)
        % Value as 0 or 1. Value as 1 implies that the channel quality
        % reported by a UE for DL direction is assumed to be applicable in
        % UL direction too
        SISOChannelReciprocity = 0;

        %CurrULAssignments UL assignments done by scheduler on running at current symbol
        % This information is used for logging. If scheduler did not run or did not do any
        % UL assignment at the current symbol this is empty
        CurrULAssignments = {};

        %StatTxThroughputBytes Number of MAC bytes sent for each UE
        % Vector of length 'N', where N is the number of UEs
        StatTxThroughputBytes

        %StatTxGoodputBytes Number of new transmission MAC bytes sent for each UE
        % Vector of length 'N', where N is the number of UEs
        StatTxGoodputBytes

        %StatResourceShare Number of RBs allocated to each UE
        % Vector of length 'N', where N is the number of UEs
        StatResourceShare
    end

    properties (Access = private)
        %CSIRSTxInfo Information about CSI-RS transmissions
        % It is an array of size N-by-2 where N is the number of unique
        % CSI-RS periodicity, start time pairs configured for the UEs. Each
        % row of the array contains CSI-RS transmission periodicity (in
        % nanoseconds) and the next transmission start time (in
        % nanoseconds) to the UEs.
        CSIRSTxInfo

        %SRSRxInfo Information about SRS receptions
        % It is an array of size N-by-2 where N is the number of unique SRS
        % periodicity, reception start time pairs configured for the UEs.
        % Each row of the array contains SRS reception periodicity (in
        % nanoseconds) and the next reception start time (in nanoseconds)
        % from the UEs.
        SRSRxInfo

        %SchedulerNextInvokeTime Time (in nanoseconds) at which scheduler will get invoked next time
        SchedulerNextInvokeTime = 0;
    end

    properties (Access = protected)
        %% Transient objects maintained for optimization
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
        function obj = hNRGNBMAC(simParameters)
            %hNRGNBMAC Construct a gNB MAC object
            %
            % simParameters is a structure including the following fields:
            % NCellID            - Physical cell ID. Values: 0 to 1007 (TS 38.211, sec 7.4.2.1)
            % NumUEs             - Number of UEs in the cell
            % SCS                - Subcarrier spacing used
            % NumLogicalChannels - Number of logical channels configured
            % NumHARQ            - Number of HARQ processes
            % NumRBs             - Number of RBs in the bandwidth
            % GNBTxAnts          - Number of gNB Tx antennas
            % UETxAnts           - Number of UE Tx antennas
            % CSIRSConfig        - Cell array containing the CSI-RS configuration information as an
            %                      object of type nrCSIRSConfig. The element at index 'i' corresponds
            %                      to the CSI-RS configured for a UE with RNTI 'i'. If only one CSI-RS
            %                      configuration is specified, it is assumed to be applicable for
            %                      all the UEs in the cell.
            % CSIRSConfigRSRP    - CSI-RS resource set configurations corresponding to the SSB directions.
            %                      It is a cell array of length N-by-1 where 'N' is the number of
            %                      maximum number of SSBs in a SSB burst. Each element of the array
            %                      at index 'i' corresponds to the CSI-RS resource set associated
            %                      with SSB 'i'. The number of CSI-RS resources in each resource
            %                      set is same for all configurations.
            % SRSConfig          - Cell array of size equal to number of UEs. An element at
            %                      index 'i' is an object of type nrSRSConfig and stores the SRS
            %                      configuration of UE with RNTI 'i'

            obj.MACType = 0; % gNB MAC type
            if isfield(simParameters, 'NCellID')
                obj.NCellID = simParameters.NCellID;
            end
            if isfield(simParameters, 'SCS')
                obj.SCS = simParameters.SCS;
            end
            % Validate the number of UEs
            validateattributes(simParameters.NumUEs, {'numeric'}, {'nonempty', ...
                'integer', 'scalar', '>', 0, '<=', 65519}, 'simParameters.NumUEs', 'NumUEs');
            % UEs are assumed to have sequential radio network temporary
            % identifiers (RNTIs) from 1 to NumUEs
            obj.UEs = 1:simParameters.NumUEs;

            numUEs = length(obj.UEs);
            slotDuration = 1/(obj.SCS/15); % In ms
            obj.SlotDurationInNS = slotDuration * 1e6; % In nanoseconds
            obj.NumSlotsFrame = 10/slotDuration; % Number of slots in a 10 ms frame
            obj.ElapsedTimeSinceLastLCP = zeros(numUEs, 1);
            if isfield(simParameters, 'NumHARQ')
                obj.NumHARQ = simParameters.NumHARQ;
            end
            obj.NumSymInFrame = obj.NumSlotsFrame * 14;

            obj.StatTxThroughputBytes = zeros(numUEs, 1);
            obj.StatTxGoodputBytes = zeros(numUEs, 1);
            obj.StatResourceShare = zeros(numUEs, 1);
            % Configuration of logical channels for UEs
            obj.LogicalChannelsConfig = cell(numUEs, obj.MaxLogicalChannels);
            obj.LCHBjList = zeros(numUEs, obj.MaxLogicalChannels);
            obj.LCHBufferStatus = zeros(numUEs, obj.MaxLogicalChannels);
            % Initialize LCG with least priorities for all the UEs
            obj.LCGPriority = 16*ones(numUEs,8);
            % Calculate symbol end times (in nanoseconds) in a slot for the
            % given SCS
            obj.SymbolEndTimesInSlot = round(((1:14)*slotDuration)/14, 4) * 1e6;
            % Duration of each symbol (in nanoseconds)
            obj.SymbolDurationsInSlot = obj.SymbolEndTimesInSlot(1:14) - [0 obj.SymbolEndTimesInSlot(1:13)];
            
            if ~isfield(simParameters, 'GNBTxAnts')
                simParameters.GNBTxAnts = 1;
                % Validate the number of transmitter antennas on gNB
            elseif ~ismember(simParameters.GNBTxAnts, [1,2,4,8,16,32,64,128,256,512,1024])
                error('nr5g:hNRGNBMAC:InvalidAntennaSize',...
                    'Number of gNB Tx antennas (%d) must be a member of [1,2,4,8,16,32,64,128,256,512,1024].', simParameters.GNBTxAnts);
            end
            if ~isfield(simParameters, 'UETxAnts')
                simParameters.UETxAnts = ones(1, simParameters.NumUEs);
                % Validate the number of transmitter antennas on UEs
            elseif any(~ismember(simParameters.UETxAnts, [1,2,4,8,16]))
                error('nr5g:hNRGNBMAC:InvalidAntennaSize',...
                    'Number of UE Tx antennas must be a member of [1,2,4,8,16].');
            end
            % Set non-zero-power (NZP) CSI-RS configuration. If unset, all the UEs
            % are assumed to use same configuration
            if isfield(simParameters, 'CSIRSConfig')
                % Validate the number of CSI-RS ports for the given gNB antenna
                % configuration
                for csirsIdx = 1:length(simParameters.CSIRSConfig)
                    if ~isa(simParameters.CSIRSConfig{csirsIdx}, 'nrCSIRSConfig')
                        error('nr5g:hNRGNBMAC:InvalidObjectType', "Each element of 'CSIRSConfig' must be specified as an object of type nrCSIRSConfig")
                    end
                    if simParameters.CSIRSConfig{csirsIdx}.NumCSIRSPorts > simParameters.GNBTxAnts
                        error('nr5g:hNRGNBMAC:InvalidCSIRSRowNumber',...
                            'Number of CSI-RS ports (%d) corresponding to CSI-RS row number (%d) must be less than or equal to GNBTxAnts (%d)',...
                            simParameters.CSIRSConfig{csirsIdx}.NumCSIRSPorts, simParameters.CSIRSConfig{csirsIdx}.RowNumber, simParameters.GNBTxAnts);
                    end
                end
                obj.CsirsConfig = simParameters.CSIRSConfig;
            else
                % Avoid potential DM-RS and CSI-RS overlap
                if isfield(simParameters, 'PDSCHDMRSConfigurationType') && simParameters.PDSCHDMRSConfigurationType == 2
                    subCarrierLocations = 2;
                else
                    subCarrierLocations = 1;
                end
                csirsConfig = nrCSIRSConfig('SubcarrierLocations', subCarrierLocations, 'SymbolLocations', 0,...
                    'RowNumber', 2, 'NumRB', simParameters.NumRBs, 'NID', obj.NCellID);
                obj.CsirsConfig = {csirsConfig};
            end

            % Set CSI-RS resource set configuration for downlink beam refinement
            if isfield(simParameters, 'CSIRSConfigRSRP')
                for csirsIdx = 1:length(simParameters.CSIRSConfigRSRP)
                    if ~isa(simParameters.CSIRSConfigRSRP{csirsIdx}, 'nrCSIRSConfig')
                        error('nr5g:hNRGNBMAC:InvalidCSIResourceSetConfig', "Each element of 'CSIRSConfigRSRP' must be specified as an object of type nrCSIRSConfig")
                    end
                    if simParameters.CSIRSConfigRSRP{csirsIdx}.NumCSIRSPorts(1) ~= 1
                        error('nr5g:hNRGNBMAC:InvalidNumCSIRSPorts',...
                            'Number of CSI-RS ports (%d) for L1-RSRP measurements must be 1.', simParameters.CSIRSConfigRSRP{csirsIdx}.NumCSIRSPorts(1));
                    end
                end
                obj.CsirsConfigRSRP = simParameters.CSIRSConfigRSRP;
            end

            % Calculate unique CSI-RS transmission slots
            obj.CSIRSTxInfo = calculateCSIRSPeriodicity(obj, [obj.CsirsConfig obj.CsirsConfigRSRP]);

            if isfield(simParameters, 'SRSConfig')
                for idx = 1:length(simParameters.SRSConfig)
                    if ~isa(simParameters.SRSConfig{idx}, 'nrSRSConfig')
                        error('nr5g:hNRGNBMAC:InvalidObjectType', "Each element of 'SRSConfig' must be specified as an object of type nrSRSConfig")
                    end
                    if simParameters.SRSConfig{idx}.NumSRSPorts > simParameters.UETxAnts(idx)
                        error('nr5g:hNRGNBMAC:InvalidNumSRSPorts', 'Number of SRS antenna ports (%d) must be less than or equal to the number of UE Tx antennas.(%d)',...
                            simParameters.SRSConfig{idx}.NumSRSPorts, simParameters.UETxAnts(idx))
                    end
                end
                obj.SrsConfig = simParameters.SRSConfig;

                % Calculate unique SRS reception time and periodicity
                obj.SRSRxInfo = calculateSRSPeriodicity(obj, obj.SrsConfig);
            else
                % If SRS is not configured then assume channel reciprocity
                obj.SISOChannelReciprocity = 1;
                % SRS resource is absent
                obj.SRSRxInfo = inf(1, 2);
            end

            % Create carrier configuration object for UL
            obj.CarrierConfigUL = nrCarrierConfig;
            obj.CarrierConfigUL.SubcarrierSpacing = obj.SCS;
            obj.CarrierConfigUL.NSizeGrid = simParameters.NumRBs;
            % Create carrier configuration object for DL
            obj.CarrierConfigDL = obj.CarrierConfigUL;

            obj.PDSCHInfo = hNRPDSCHInfo;
            obj.PUSCHInfo = hNRPUSCHInfo;
        end

        function nextInvokeTime = run(obj, currentTime, packets)
            %run Run the gNB MAC layer operations and return the next invoke time in nanoseconds
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
            if currentTime > obj.LastRunTime
                % Advance the time
                % Update LCP timers
                obj.ElapsedTimeSinceLastLCP  = obj.ElapsedTimeSinceLastLCP + round(elapsedTime*1e-6, 4);
                % Update the last run time
                obj.LastRunTime = currentTime;

                % Find the current AFN
                obj.SFN = mod(floor(currentTime/obj.FrameDurationInNS), 1024);
                absoluteSlotNum = floor(currentTime/obj.SlotDurationInNS);
                % Current slot number in 10 ms frame
                obj.CurrSlot = mod(absoluteSlotNum, obj.NumSlotsFrame);

                if obj.Scheduler.DuplexMode == 1 % TDD
                    % Current slot number in DL-UL pattern
                    obj.CurrDLULSlotIndex = mod(absoluteSlotNum, obj.Scheduler.NumDLULPatternSlots);
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
                % Update the last run time
                obj.LastRunTime = currentTime;
                % Avoid running MAC operations more than once in the same
                % symbol
                return;
            end

            % Send data Tx request to Phy for transmission(s) which is(are)
            % scheduled to start at current symbol. Construct and send the
            % DL MAC PDUs scheduled for current symbol to Phy
            dataTx(obj, currentTime);
            
            % Run schedulers (UL and DL) and send the resource assignment information to the UEs.
            % Resource assignments returned by a scheduler (either UL or
            % DL) is empty, if either scheduler was not scheduled to run at
            % the current time or no resource got assigned
            if currentTime == obj.SchedulerNextInvokeTime % Run scheduler at slot boundary
                resourceAssignmentsUL = runULScheduler(obj);
                resourceAssignmentsDL = runDLScheduler(obj);
                % Check if UL/DL assignments are done
                if ~isempty(resourceAssignmentsUL) || ~isempty(resourceAssignmentsDL)
                    % Construct and send UL assignments and DL assignments to
                    % UEs. UL and DL assignments are assumed to be sent
                    % out-of-band without using any frequency-time resources,
                    % from gNB's MAC to UE's MAC
                    controlTx(obj, resourceAssignmentsUL, resourceAssignmentsDL);
                end
                obj.SchedulerNextInvokeTime = obj.SchedulerNextInvokeTime + obj.SlotDurationInNS;
            end

            % Send request to Phy for:
            % (i) Non-data transmissions scheduled in this slot (currently
            % only CSI-RS supported)
            % (ii) Non-data receptions scheduled in this slot (currently
            % only SRS supported)
            %
            % Send at the first symbol of the slot for all the non-data
            % transmissions/receptions scheduled in the entire slot
            idxList = find(obj.CSIRSTxInfo(:, 2) == currentTime);
            if ~isempty(idxList)
                dlControlRequest(obj, currentTime);
                % Update the next CSI-RS Tx times
                obj.CSIRSTxInfo(idxList, 2) = obj.CSIRSTxInfo(idxList, 1) + currentTime;
            end
            idxList = find(obj.SRSRxInfo(:, 2) == currentTime);
            if ~isempty(idxList)
                ulControlRequest(obj, currentTime);
                % Update the next SRS Rx times
                obj.SRSRxInfo(idxList, 2) = obj.SRSRxInfo(idxList, 1) + currentTime;
            end

            % Send data Rx request to Phy for reception(s) which is(are) scheduled to start at current symbol
            dataRx(obj, currentTime);

            % Update the previous symbol to the current symbol in the frame
            obj.PreviousSymbol = symNumFrame;
            % Return the next invoke time for MAC
            nextInvokeTime = getNextInvokeTime(obj, currentTime);
            % Update the last run time
            obj.LastRunTime = currentTime;
        end

        function addScheduler(obj, scheduler)
            %addScheduler Add scheduler object to MAC
            %   addScheduler(OBJ, SCHEDULER) adds the scheduler to MAC.
            %
            %   SCHEDULER Scheduler object.

            obj.Scheduler = scheduler;
            % Create Tx/Rx contexts
            obj.UplinkRxContext = cell(length(obj.UEs), obj.NumSlotsFrame * 14);
            obj.DownlinkTxContext = cell(length(obj.UEs), obj.NumSlotsFrame * 14);
            obj.RxContextFeedback = cell(length(obj.UEs), obj.NumSlotsFrame*14, obj.Scheduler.NumHARQ);

            obj.PDSCHInfo.PDSCHConfig.DMRS = nrPDSCHDMRSConfig('DMRSConfigurationType', obj.Scheduler.PDSCHDMRSConfigurationType, ...
                'DMRSTypeAPosition', obj.Scheduler.DMRSTypeAPosition);
            obj.PUSCHInfo.PUSCHConfig.DMRS = nrPUSCHDMRSConfig('DMRSConfigurationType', obj.Scheduler.PUSCHDMRSConfigurationType, ...
                'DMRSTypeAPosition', obj.Scheduler.DMRSTypeAPosition);
        end

        function symbolType = currentSymbolType(obj)
            %currentSymbolType Get current running symbol type: DL/UL/Guard
            %   SYMBOLTYPE = currentSymbolType(OBJ) returns the symbol type of
            %   current symbol.
            %
            %   SYMBOLTYPE is the symbol type. Value 0, 1 and 2 represent
            %   DL, UL, guard symbol respectively.

            symbolType = obj.Scheduler.DLULSlotFormat(obj.CurrDLULSlotIndex + 1, obj.CurrSymbol + 1);
        end

        function resourceAssignments = runULScheduler(obj)
            %runULScheduler Run the UL scheduler
            %
            %   RESOURCEASSIGNMENTS = runULScheduler(OBJ) runs the UL scheduler
            %   and returns the resource assignments structure array.
            %
            %   RESOURCEASSIGNMENTS is a structure that contains the
            %   UL resource assignments information.

            resourceAssignments = runULScheduler(obj.Scheduler, obj.TimingInfo);
            % Set Rx context at gNB by storing the UL grants. It is set at
            % symbol number in the 10 ms frame, where UL reception is
            % expected to start. gNB uses this to anticipate the reception
            % start time of uplink packets
            for i = 1:length(resourceAssignments)
                grant = resourceAssignments{i};
                slotNum = mod(obj.CurrSlot + grant.SlotOffset, obj.NumSlotsFrame); % Slot number in the frame for the grant
                obj.UplinkRxContext{grant.RNTI, slotNum*14 + grant.StartSymbol + 1} = grant;
            end
            obj.CurrULAssignments = resourceAssignments;
        end

        function resourceAssignments = runDLScheduler(obj)
            %runDLScheduler Run the DL scheduler
            %
            %   RESOURCEASSIGNMENTS = runDLScheduler(OBJ) runs the DL scheduler
            %   and returns the resource assignments structure array.
            %
            %   RESOURCEASSIGNMENTS is a structure that contains the
            %   DL resource assignments information.

            resourceAssignments = runDLScheduler(obj.Scheduler, obj.TimingInfo);
            % Update Tx context at gNB by storing the DL grants at the
            % symbol number (in the 10 ms frame) where DL transmission
            % is scheduled to start
            for i = 1:length(resourceAssignments)
                grant = resourceAssignments{i};
                slotNum = mod(obj.CurrSlot + grant.SlotOffset, obj.NumSlotsFrame); % Slot number in the frame for the grant
                obj.DownlinkTxContext{grant.RNTI, slotNum*14 + grant.StartSymbol + 1} = grant;
            end
            obj.CurrDLAssignments = resourceAssignments;
        end

        function dataTx(obj, currentTime)
            % dataTx Construct and send the DL MAC PDUs scheduled for current symbol to Phy
            %
            % dataTx(OBJ, CURRENTTIME) Based on the downlink grants sent earlier, if
            % current symbol is the start symbol of downlink transmissions then
            % send the DL MAC PDUs to Phy.
            %
            % CURRENTTIME is the current time (in nanoseconds).

            symbolNumFrame = obj.CurrSlot*14 + obj.CurrSymbol; % Current symbol number in the 10 ms frame
            numRBsDL = obj.Scheduler.NumPDSCHRBs; % Number of RBs in downlink
            rbgSize = obj.Scheduler.RBGSizeDL; % RBG size in downlink
            for rnti = 1:length(obj.UEs) % For all UEs
                downlinkGrant = obj.DownlinkTxContext{rnti, symbolNumFrame + 1};
                % If there is any downlink grant corresponding to which a transmission is scheduled at the current symbol
                if ~isempty(downlinkGrant)
                    % Construct and send MAC PDU in adherence to downlink grant
                    % properties
                    [sentPDULen, type] = sendMACPDU(obj, rnti, downlinkGrant, currentTime);
                    % Tx done. Clear the context
                    obj.DownlinkTxContext{rnti, symbolNumFrame + 1} = [];

                    % Calculate the slot number where PDSCH ACK/NACK is
                    % expected
                    feedbackSlot = mod(obj.CurrSlot + downlinkGrant.FeedbackSlotOffset, obj.NumSlotsFrame);

                    % For TDD, the selected symbol at which feedback would
                    % be transmitted by UE is the first UL symbol in
                    % feedback slot. For FDD, it is the first symbol in the
                    % feedback slot (as every symbol is UL)
                    if obj.Scheduler.DuplexMode == 1 % TDD
                        feedbackSlotDLULIdx = mod(obj.CurrDLULSlotIndex + downlinkGrant.FeedbackSlotOffset, obj.Scheduler.NumDLULPatternSlots);
                        feedbackSlotPattern = obj.Scheduler.DLULSlotFormat(feedbackSlotDLULIdx + 1, :);
                        feedbackSym = (find(feedbackSlotPattern == obj.ULType, 1, 'first')) - 1; % Check for location of first UL symbol in the feedback slot
                    else % FDD
                        feedbackSym = 0;  % First symbol
                    end

                    % Update the context for this UE at the symbol number
                    % w.r.t start of the frame where feedback is expected
                    % to be received
                    obj.RxContextFeedback{rnti, ((feedbackSlot*14) + feedbackSym + 1), downlinkGrant.HARQID + 1} = downlinkGrant;

                    obj.StatTxThroughputBytes(rnti) = obj.StatTxThroughputBytes(rnti) + sentPDULen;
                    if(strcmp(type, 'newTx'))
                        obj.StatTxGoodputBytes(rnti) = obj.StatTxGoodputBytes(rnti) + sentPDULen;
                    end

                    rbgMap = downlinkGrant.RBGAllocationBitmap;
                    if rbgMap(end) == 1 && mod(numRBsDL, rbgSize)
                        % If the number of RBs in last RBG is less than RBGSize
                        numRBs = (nnz(rbgMap) - 1) * rbgSize +  mod(numRBsDL, rbgSize);
                    else
                        numRBs = nnz(rbgMap) * rbgSize;
                    end
                    obj.StatResourceShare(rnti) = obj.StatResourceShare(rnti) + numRBs;
                end
            end
        end

        function srsIndication(obj, rnti, rank, tpmi, cqi)
            %srsIndication Reception of SRS measurements from Phy
            %   srsIndication(OBJ, RNTI, RANK, PMISET, CQI) receives the UL channel
            %   measurements from Phy, measured on the configured SRS for the
            %   UE.
            %   RNTI - UE corresponding to the SRS
            %   RANK - Rank indicator
            %   TPMI - Measured transmitted precoding matrix indicator (TPMI)
            %   CQI - CQI corresponding to RANK and TPMI. It is a vector
            %   of size 'N', where 'N' is number of RBs in bandwidth. Value
            %   at index 'i' represents CQI value at RB-index 'i'.

            csiMeasurement.RNTI = rnti;
            csiMeasurement.RankIndicator = rank;
            csiMeasurement.TPMI = tpmi;
            csiMeasurement.CQI = cqi;
            updateChannelQualityUL(obj.Scheduler, csiMeasurement);
        end

        function controlTx(obj, resourceAssignmentsUL, resourceAssignmentsDL)
            %controlTx Construct and send the uplink and downlink assignments to the UEs
            %
            %   controlTx(obj, RESOURCEASSIGNMENTSUL, RESOURCEASSIGNMENTSDL)
            %   Based on the resource assignments done by uplink and
            %   downlink scheduler, send assignments to UEs. UL and DL
            %   assignments are sent out-of-band without the need of
            %   frequency resources.
            %
            %   RESOURCEASSIGNMENTSUL is a cell array of structures that
            %   contains the UL resource assignments information.
            %
            %   RESOURCEASSIGNMENTSDL is a cell array of structures that
            %   contains the DL resource assignments information.

            % Construct and send uplink grants
            if ~isempty(resourceAssignmentsUL)
                uplinkGrant = hNRUplinkGrantFormat;
                for i = 1:length(resourceAssignmentsUL) % For each UL assignment
                    grant = resourceAssignmentsUL{i};
                    uplinkGrant.RBGAllocationBitmap = grant.RBGAllocationBitmap;
                    uplinkGrant.StartSymbol = grant.StartSymbol;
                    uplinkGrant.NumSymbols = grant.NumSymbols;
                    uplinkGrant.SlotOffset = grant.SlotOffset;
                    uplinkGrant.MCS = grant.MCS;
                    uplinkGrant.NDI = grant.NDI;
                    uplinkGrant.RV = grant.RV;
                    uplinkGrant.HARQID = grant.HARQID;
                    uplinkGrant.MappingType = grant.MappingType;
                    uplinkGrant.DMRSLength = grant.DMRSLength;
                    uplinkGrant.NumLayers = grant.NumLayers;
                    uplinkGrant.NumCDMGroupsWithoutData = grant.NumCDMGroupsWithoutData;
                    uplinkGrant.TPMI = grant.TPMI;
                    uplinkGrant.NumAntennaPorts = grant.NumAntennaPorts;

                    % Construct packet information
                    pktInfo.Packet = uplinkGrant;
                    pktInfo.PacketType = obj.ULGrant;
                    pktInfo.NCellID = obj.NCellID;
                    pktInfo.RNTI = grant.RNTI;
                    obj.TxOutofBandFcn(pktInfo); % Send the UL grant out-of-band to UE's MAC
                end
            end

            % Construct and send downlink grants
            if ~isempty(resourceAssignmentsDL)
                downlinkGrant = hNRDownlinkGrantFormat;
                for i = 1:length(resourceAssignmentsDL) % For each DL assignment
                    grant = resourceAssignmentsDL{i};
                    downlinkGrant.RBGAllocationBitmap = grant.RBGAllocationBitmap;
                    downlinkGrant.StartSymbol = grant.StartSymbol;
                    downlinkGrant.NumSymbols = grant.NumSymbols;
                    downlinkGrant.SlotOffset = grant.SlotOffset;
                    downlinkGrant.MCS = grant.MCS;
                    downlinkGrant.NDI = grant.NDI;
                    downlinkGrant.RV = grant.RV;
                    downlinkGrant.HARQID = grant.HARQID;
                    downlinkGrant.FeedbackSlotOffset = grant.FeedbackSlotOffset;
                    downlinkGrant.MappingType = grant.MappingType;
                    downlinkGrant.DMRSLength = grant.DMRSLength;
                    downlinkGrant.NumLayers = grant.NumLayers;
                    downlinkGrant.NumCDMGroupsWithoutData = grant.NumCDMGroupsWithoutData;

                    % Construct packet information
                    pktInfo.Packet = downlinkGrant;
                    pktInfo.PacketType = obj.DLGrant;
                    pktInfo.NCellID = obj.NCellID;
                    pktInfo.RNTI = grant.RNTI;
                    obj.TxOutofBandFcn(pktInfo); % Send the DL grant out-of-band to UE's MAC
                end
            end
        end

        function controlRx(obj, pktInfo)
            %controlRx Receive callback for BSR, feedback(ACK/NACK) for
            % PDSCH, and CSI report. CSI report can either be of the format
            % ri-pmi-cqi or cri-l1RSRP. The ri-pmi-cqi format specifies the
            % rank indicator (RI), precoding matrix indicator (PMI) and the channel
            % quality indicator (CQI) values. the cri-rsrp format specifies the
            % CSI-RS resource indicator (CRI) and layer-1 reference signal
            % received power (L1-RSRP) values.

            pktType = pktInfo.PacketType;
            switch(pktType)
                case obj.BSR % BSR received
                    bsr = pktInfo.Packet;
                    [lcid, payload] = hNRMACPDUParser(bsr, 1); % Parse the BSR
                    macCEInfo.RNTI = pktInfo.RNTI;
                    macCEInfo.LCID = lcid;
                    macCEInfo.Packet = payload{1};
                    processMACControlElement(obj.Scheduler, macCEInfo, obj.LCGPriority(pktInfo.RNTI,:));

                case obj.PDSCHFeedback % PDSCH feedback received
                    feedbackList = pktInfo.Packet;
                    symNumFrame = obj.CurrSlot*14 + obj.CurrSymbol;
                    for harqId = 0:obj.Scheduler.NumHARQ-1 % Check for all HARQ processes
                        feedbackContext =  obj.RxContextFeedback{pktInfo.RNTI, symNumFrame+1, harqId+1};
                        if ~isempty(feedbackContext) % If any ACK/NACK expected from the UE for this HARQ process
                            rxResult = feedbackList(feedbackContext.HARQID+1); % Read Rx success/failure result
                            % Notify PDSCH Rx result to scheduler for updating the HARQ context
                            rxResultInfo.RNTI = pktInfo.RNTI;
                            rxResultInfo.RxResult = rxResult;
                            rxResultInfo.HARQID = harqId;
                            handleDLRxResult(obj.Scheduler, rxResultInfo);
                            obj.RxContextFeedback{pktInfo.RNTI, symNumFrame+1, harqId+1} = []; % Clear the context
                        end
                    end

                case obj.CSIReport % CSI report received containing RI, PMI and CQI
                    csiReport = pktInfo.Packet;
                    channelQualityInfo.RNTI = pktInfo.RNTI;
                    channelQualityInfo.RankIndicator = csiReport.RankIndicator;
                    channelQualityInfo.PMISet = csiReport.PMISet;
                    channelQualityInfo.CQI = csiReport.CQI;
                    updateChannelQualityDL(obj.Scheduler, channelQualityInfo);
                    if obj.SISOChannelReciprocity
                        channelQualityUL.RNTI = pktInfo.RNTI;
                        % Assuming UL channel quality to be same as DL channel quality reported in CSI measurement report
                        channelQualityUL.CQI = csiReport.CQI;
                        updateChannelQualityUL(obj.Scheduler, channelQualityUL);
                    end

                case obj.CSIReportRSRP % CSI report received containing CRI and RSRP
                    csiReport = pktInfo.Packet;
                    channelQualityInfo.RNTI = pktInfo.RNTI;
                    channelQualityInfo.CRI = csiReport.CRI;
                    channelQualityInfo.L1RSRP = csiReport.L1RSRP;
                    updateChannelQualityDL(obj.Scheduler, channelQualityInfo);
            end
        end

        function dataRx(obj, currentTime)
            %dataRx Send Rx start request to Phy for the receptions scheduled to start now
            %
            %   dataRx(OBJ, CURRENTTIME) sends the Rx start request to Phy for the
            %   receptions scheduled to start now, as per the earlier sent
            %   uplink grants.
            %
            %   CURRENTTIME is the current time (in nanoseconds).

            gNBRxContext = obj.UplinkRxContext(:, (obj.CurrSlot * 14) + obj.CurrSymbol + 1); % Rx context of current symbol
            txUEs = find(~cellfun(@isempty, gNBRxContext)); % UEs which are assigned uplink grants starting at this symbol
            for i = 1:length(txUEs)
                % For the UE, get the uplink grant information
                uplinkGrant = gNBRxContext{txUEs(i)};
                % Clear UE uplink RX context
                rxRequestToPhy(obj, txUEs(i), uplinkGrant, currentTime);
            end
            obj.UplinkRxContext(:, (obj.CurrSlot * 14) + obj.CurrSymbol + 1) = {[]}; % Clear uplink RX context
        end

        function rxIndication(obj, macPDU, crc, rxInfo)
            %rxIndication Packet reception from Phy
            %   rxIndication(OBJ, MACPDU, CRC, RXINFO) receives a MAC PDU from
            %   Phy.
            %   MACPDU is the PDU received from Phy.
            %   CRC is the success(value as 0)/failure(value as 1) indication
            %   from Phy.
            %   RXINFO is an object of type hNRRxIndicationInfo containing
            %   information about the reception.

            isRxSuccess = ~crc; % CRC value 0 indicates successful reception

            % Notify PUSCH Rx result to scheduler for updating the HARQ context
            rxResultInfo.RNTI = rxInfo.RNTI;
            rxResultInfo.RxResult = isRxSuccess;
            rxResultInfo.HARQID = rxInfo.HARQID;
            handleULRxResult(obj.Scheduler, rxResultInfo);
            if isRxSuccess % Packet received is error free
                [lcidList, sduList] = hNRMACPDUParser(macPDU, obj.ULType);
                for sduIndex = 1:numel(lcidList)
                    if lcidList(sduIndex) >=1 && lcidList(sduIndex) <= 32
                        obj.RLCRxFcn(rxInfo.RNTI, lcidList(sduIndex), sduList{sduIndex});
                    end
                end
            end
        end

        function dlControlRequest(obj, currentTime)
            %dlControlRequest Request from MAC to Phy to send non-data DL transmissions
            %   dlControlRequest(OBJ) sends a request to Phy for non-data downlink
            %   transmission scheduled for the current slot. MAC sends it at the
            %   start of a DL slot for all the scheduled DL transmissions in
            %   the slot (except PDSCH, which is sent using dataTx
            %   function of this class).

            % Check if current slot is a slot with DL symbols. For FDD (Value 0),
            % there is no need to check as every slot is a DL slot. For
            % TDD (Value 1), check if current slot has any DL symbols
            maxNumCSIRS = length(obj.CsirsConfigRSRP) + length(obj.CsirsConfig);
            dlControlType = zeros(1, maxNumCSIRS);
            dlControlPDUs = cell(1, maxNumCSIRS);
            numDLControlPDU = 0; % Variable to hold the number of DL control PDUs
            if ~isempty(obj.CsirsConfigRSRP) % CSI-RS resource set for downlink beam refinement
                if(obj.Scheduler.DuplexMode == 0 || ~isempty(find(obj.Scheduler.DLULSlotFormat(obj.CurrDLULSlotIndex + 1, :) == obj.DLType, 1)))
                    % Determine the SSB directions currently in use for all the UEs
                    activeSSBs = unique(obj.Scheduler.SSBIdx);
                    for ssbIdx = 1:length(activeSSBs)
                        csirsLocations = obj.CsirsConfigRSRP{activeSSBs(ssbIdx)}.SymbolLocations; % CSI-RS symbol locations
                        if obj.Scheduler.DuplexMode == 0 || all(obj.Scheduler.DLULSlotFormat(obj.CurrDLULSlotIndex + 1, cell2mat(csirsLocations)+1) == obj.DLType)
                            % Set carrier configuration object
                            carrier = obj.CarrierConfigDL;
                            carrier.NSlot = obj.CurrSlot;
                            carrier.NFrame = obj.SFN;
                            csirsIndRSRP = nrCSIRSIndices(carrier, obj.CsirsConfigRSRP{activeSSBs(ssbIdx)});

                            if ~isempty(csirsIndRSRP)
                                numDLControlPDU = numDLControlPDU + 1;
                                dlControlType(numDLControlPDU) = hNRPhyInterface.CSIRSPDUType;
                                numCSIRS = length(obj.CsirsConfigRSRP{1}.RowNumber);
                                dlControlPDUs{numDLControlPDU} = {obj.CsirsConfigRSRP{activeSSBs(ssbIdx)}, (activeSSBs(ssbIdx)-1)*numCSIRS + (1:numCSIRS)};
                            end
                        end
                    end
                end
            end
           csirsConfigLen = length(obj.CsirsConfig);
            % To account for consecutive symbols in CDM pattern
            additionalCSIRSSyms = [0 0 0 0 1 0 1 1 0 1 1 1 1 1 3 1 1 3];
            for csirsIdx = 1:csirsConfigLen % CSI-RS for downlink channel measurement
                csirsSymbolRange(1) = min(obj.CsirsConfig{csirsIdx}.SymbolLocations); % First CSI-RS symbol
                csirsSymbolRange(2) = max(obj.CsirsConfig{csirsIdx}.SymbolLocations) + ... % Last CSI-RS symbol
                    additionalCSIRSSyms(obj.CsirsConfig{csirsIdx}.RowNumber);
                % Check whether the mode is FDD OR if it is TDD then all the CSI-SRS symbols must be DL symbols
                if obj.Scheduler.DuplexMode == 0 || all(obj.Scheduler.DLULSlotFormat(obj.CurrDLULSlotIndex + 1, csirsSymbolRange+1) == obj.DLType)
                    % Set carrier configuration object
                    carrier = obj.CarrierConfigDL;
                    carrier.NSlot = obj.CurrSlot;
                    carrier.NFrame = obj.SFN;
                    csirsInd = nrCSIRSIndices(carrier, obj.CsirsConfig{csirsIdx});
                    if ~isempty(csirsInd) % Empty value means CSI-RS is not scheduled in the current slot
                        numDLControlPDU = numDLControlPDU + 1;
                        dlControlType(numDLControlPDU) = hNRPhyInterface.CSIRSPDUType;
                        if ~isempty(obj.Scheduler.CSIMeasurementDL(csirsIdx).CSIResourceIndicator)
                            numCSIRSBeams = length(obj.CsirsConfigRSRP{1}.RowNumber);
                            beamIdx = (obj.Scheduler.SSBIdx(csirsIdx)-1)*numCSIRSBeams + obj.Scheduler.CSIMeasurementDL(csirsIdx).CSIResourceIndicator;
                        else
                            beamIdx = [];
                        end
                        dlControlPDUs{numDLControlPDU} = {obj.CsirsConfig{csirsIdx}, beamIdx};
                    end
                end
            end
            obj.TimingInfo.Timestamp = currentTime;
            obj.DlControlRequestFcn(dlControlType(1:numDLControlPDU), dlControlPDUs(1:numDLControlPDU), obj.TimingInfo); % Send DL control request to Phy

        end

        function ulControlRequest(obj, currentTime)
            %ulControlRequest Request from MAC to Phy to receive non-data UL transmissions
            %   ulControlRequest(OBJ) sends a request to Phy for non-data
            %   uplink reception scheduled for the current slot. MAC
            %   sends it at the start of a UL slot for all the scheduled UL
            %   receptions in the slot (except PUSCH, which is received
            %   using dataRx function of this class).

            if ~isempty(obj.SrsConfig) % Check if SRS is enabled
                % Check if current slot is a slot with UL symbols. For FDD
                % (value 0), there is no need to check as every slot is a
                % UL slot. For TDD (value 1), check if current slot has any
                % UL symbols
                if obj.Scheduler.DuplexMode == 0 || ~isempty(find(obj.Scheduler.DLULSlotFormat(obj.CurrDLULSlotIndex + 1, :) == obj.ULType, 1))
                    ulControlType = zeros(1, length(obj.UEs));
                    ulControlPDUs = cell(1, length(obj.UEs));
                    numSRSUEs = 0; % Initialize number of UEs from which SRS is expected in this slot
                    for rnti=1:length(obj.UEs) % Send SRS reception request to Phy for the UEs
                        srsConfigUE = obj.SrsConfig{rnti};
                        srsLocations = srsConfigUE.SymbolStart : (srsConfigUE.SymbolStart + srsConfigUE.NumSRSSymbols-1); % SRS symbol locations
                        % Check whether the mode is FDD OR if it is TDD then all the SRS symbols must be UL symbols
                        if obj.Scheduler.DuplexMode == 0 || all(obj.Scheduler.DLULSlotFormat(obj.CurrDLULSlotIndex + 1, srsLocations+1) == obj.ULType)
                            % Set carrier configuration object
                            carrier = obj.CarrierConfigUL;
                            carrier.NSlot = obj.CurrSlot;
                            carrier.NFrame = obj.SFN;
                            srsInd = nrSRSIndices(carrier, srsConfigUE);
                            if ~isempty(srsInd) % Empty value means SRS is not scheduled to be received in the current slot for this UE
                                numSRSUEs = numSRSUEs+1;
                                ulControlType(numSRSUEs) = hNRPhyInterface.SRSPDUType;
                                ulControlPDUs{numSRSUEs}{1} = rnti;
                                ulControlPDUs{numSRSUEs}{2} = srsConfigUE;
                            end
                        end
                    end
                    ulControlType = ulControlType(1:numSRSUEs);
                    ulControlPDUs = ulControlPDUs(1:numSRSUEs);
                    obj.TimingInfo.Timestamp = currentTime;
                    obj.UlControlRequestFcn(ulControlType, ulControlPDUs, obj.TimingInfo); % Send UL control request to Phy
                end
            end
        end

        function [throughputServing, goodputServing] = getTTIBytes(obj)
            %getTTIBytes Return the amount of throughput and goodput MAC bytes sent till current time, for each UE
            %
            %   [THROUGHPUTPUTSERVING, GOODPUTPUTSERVING] =
            %   getTTIBytes(OBJ) returns the amount of throughput and
            %   goodput bytes sent till current time
            %
            %   THROUGHPUTPUTSERVING is a vector of length 'N' where 'N' is
            %   the number of UEs. Value at index 'i' represents the amount
            %   of MAC bytes sent for UE 'i' till this symbol.
            %
            %   GOODPUTPUTSERVING is a vector of length 'N' where 'N' is
            %   the number of UEs. Value at index 'i' represents the amount
            %   of new-Tx MAC bytes sent for UE 'i' till this symbol.

            throughputServing = obj.StatTxThroughputBytes;
            goodputServing = obj.StatTxGoodputBytes;
        end

        function [ulAssignments, dlAssignments] = getCurrentSchedulingAssignments(obj)
            %getCurrentSchedulingAssignments Return the UL and DL assignments done by scheduler on running at current symbol
            %
            %   [ULASSIGNMENTS, DLASSIGNMENTS] =
            %   getCurrentSchedulingAssignments(OBJ) returns the UL and DL
            %   assignments done by scheduler on running at current symbol.
            %   ULASSIGNMENTS would be empty if UL scheduler did not run or
            %   did not schedule any UL resources. Likewise, for
            %   DLASSIGNMENTS.
            %
            %   ULASSIGNMENTS is the cell array of uplink assignments.
            %   DLASSIGNMENTS is the cell array of downlink assignments.

            dlAssignments = obj.CurrDLAssignments;
            obj.CurrDLAssignments = {};
            ulAssignments = obj.CurrULAssignments;
            obj.CurrULAssignments = {};
        end

        function channelQualityInfo = getChannelQualityStatus(obj, linkDir, rnti)
            %getChannelQualityStatus Get channel state information report
            %
            % CHANNELQUALITYINFO = getChannelQualityStatus(OBJ, LINKDIR, RNTI) Gets channel
            % state information report
            %
            % LINKDIR - Represents the transmission direction
            % (uplink/downlink) with respect to UE
            %    LINKDIR = 0 represents downlink and
            %    LINKDIR = 1 represents uplink.
            %
            % RNTI is a radio network temporary identifier, specified
            % within [1, 65519]. Refer table 7.1-1 in 3GPP TS 38.321.
            %
            % CHANNELQUALITYINFO - It is a structure containing the
            % following fields in the case of downlink: 'RankIndicator', 'PMISet', 'CQI'
            %   RankIndicator is a scalar value to representing the rank reported by a UE.
            %   PMISet has the following fields:
            %       i1 - Indicates wideband PMI (1-based). It a three-element vector in the
            %            form of [i11 i12 i13].
            %       i2 - Indicates subband PMI (1-based). It is a vector of length equal to
            %            the number of subbands or number of PRGs.
            %   CQI - Array of size equal to number of RBs in the bandwidth. Each index
            %         contains the CQI value corresponding to the RB index.
            % If CSI reporting for CRI & L1-RSRP measurements are
            % configured, it contains the following additional fields
            %   CSIResourceIndicator - CSI-RS Resource Indicator corresponding to the
            %                          beam with the highest RSRP measurement
            %   L1RSRP               - Highest L1-RSRP measurement among all the
            %                          refined CSI-RS beam directions
            % For uplink direction, it is a structure with the fields: 'RankIndicator', 'TPMI', 'CQI'
            %   RankIndicator is a scalar value to representing the rank estimated for a UE.
            %   TPMI - Transmission precoding matrix indicator
            %   CQI  - Array of size equal to number of RBs in the bandwidth. Each index
            %          contains the CQI value corresponding to the RB index.


            if linkDir % Uplink
                channelQualityInfo = obj.Scheduler.CSIMeasurementUL(rnti);
            else % Downlink
                channelQualityInfo = obj.Scheduler.CSIMeasurementDL(rnti);
            end
        end

        function buffStatus = getUEBufferStatus(obj)
            %getUEBufferStatus Get the pending downlink buffer amount (in bytes) for the UEs
            %
            %   BUFFSTATUS = getUEBufferStatus(OBJ) returns the pending
            %   amount of buffer in bytes at gNB for UEs.
            %
            %   BUFFSTATUS is a vector of size 'N', where N is the number
            %   of UEs. Value at index 'i' contains pending DL buffer
            %   amount in bytes, for UE with rnti 'i'.

            buffStatus = zeros(length(obj.UEs), 1);
            for i=1:length(obj.UEs)
                buffStatus(i) = sum(obj.LCHBufferStatus(i, :));
            end
        end

        function updateBufferStatus(obj, lcBufferStatus)
            %updateBufferStatus Update DL buffer status for UEs, as notified by RLC
            %
            %   updateBufferStatus(obj, LCBUFFERSTATUS) updates the
            %   DL buffer status for a logical channel of specified UE
            %
            %   LCBUFFERSTATUS is the report sent by RLC. It is a
            %   structure with 3 fields:
            %       RNTI - Specified UE
            %       LogicalChannelID - ID of logical channel
            %       BufferStatus - Pending amount in bytes for the specified logical channel of UE.

            updateLCBufferStatusDL(obj.Scheduler, lcBufferStatus);
            obj.LCHBufferStatus(lcBufferStatus.RNTI, lcBufferStatus.LogicalChannelID) = ...
                lcBufferStatus.BufferStatus;
        end
    end

    methods (Access = private)
        function [pduLen, type] = sendMACPDU(obj, rnti, downlinkGrant, currentTime)
            %sendMACPDU Sends MAC PDU to Phy as per the parameters of the downlink grant
            % Based on the NDI in the downlink grant, either new
            % transmission or retransmission would be indicated to Phy

            macPDU = [];
            % Populate PDSCH information to be sent to Phy, along with the MAC
            % PDU
            pdschInfo = obj.PDSCHInfo;
            RBGAllocationBitmap = downlinkGrant.RBGAllocationBitmap;
            DLGrantRBs = -1*ones(obj.Scheduler.NumPDSCHRBs, 1); % To store RB indices of DL grant
            for RBGIndex = 0:(length(RBGAllocationBitmap)-1) % Get RB indices of DL grant
                if RBGAllocationBitmap(RBGIndex+1) == 1
                    startRBInRBG = obj.Scheduler.RBGSizeDL * RBGIndex;
                    % If the last RBG of BWP is assigned, then it might
                    % not have the same number of RBs as other RBG.
                    if RBGIndex == length(RBGAllocationBitmap)-1
                        DLGrantRBs(startRBInRBG+1 : end) =  ...
                            startRBInRBG : obj.Scheduler.NumPDSCHRBs-1;
                    else
                        DLGrantRBs(startRBInRBG+1 : (startRBInRBG + obj.Scheduler.RBGSizeDL)) =  ...
                            startRBInRBG : (startRBInRBG + obj.Scheduler.RBGSizeDL -1) ;
                    end
                end
            end
            DLGrantRBs = DLGrantRBs(DLGrantRBs >= 0);
            pdschInfo.PDSCHConfig.PRBSet = DLGrantRBs;
            % Get the corresponding row from the mcs table
            mcsInfo = obj.Scheduler.MCSTableDL(downlinkGrant.MCS + 1, :);
            modSchemeBits = mcsInfo(1); % Bits per symbol for modulation scheme(stored in column 1)
            pdschInfo.TargetCodeRate = mcsInfo(2)/1024; % Coderate (stored in column 2)
            % Modulation scheme and corresponding bits/symbol
            fullmodlist = ["pi/2-BPSK", "BPSK", "QPSK", "16QAM", "64QAM", "256QAM"]';
            qm = [1 1 2 4 6 8];
            modScheme = fullmodlist((modSchemeBits == qm)); % Get modulation scheme string
            pdschInfo.PDSCHConfig.Modulation = modScheme(1);
            pdschInfo.PDSCHConfig.SymbolAllocation = [downlinkGrant.StartSymbol downlinkGrant.NumSymbols];
            pdschInfo.PDSCHConfig.RNTI = rnti;
            pdschInfo.PDSCHConfig.NID = obj.NCellID;
            pdschInfo.NSlot = obj.CurrSlot;
            pdschInfo.HARQID = downlinkGrant.HARQID;
            pdschInfo.RV = downlinkGrant.RV;
            pdschInfo.PrecodingMatrix = downlinkGrant.PrecodingMatrix;
            pdschInfo.BeamIndex = downlinkGrant.BeamIndex;
            pdschInfo.PDSCHConfig.MappingType = downlinkGrant.MappingType;
            pdschInfo.PDSCHConfig.NumLayers = downlinkGrant.NumLayers;
            if isequal(downlinkGrant.MappingType, 'A')
                dmrsAdditonalPos = obj.Scheduler.PDSCHDMRSAdditionalPosTypeA;
            else
                dmrsAdditonalPos = obj.Scheduler.PDSCHDMRSAdditionalPosTypeB;
            end
            pdschInfo.PDSCHConfig.DMRS.DMRSLength =  downlinkGrant.DMRSLength;
            pdschInfo.PDSCHConfig.DMRS.DMRSAdditionalPosition = dmrsAdditonalPos;
            pdschInfo.PDSCHConfig.DMRS.NumCDMGroupsWithoutData =  downlinkGrant.NumCDMGroupsWithoutData;

            % Carrier configuration
            carrierConfig = obj.CarrierConfigDL;
            carrierConfig.NFrame = obj.SFN;
            carrierConfig.NSlot = pdschInfo.NSlot;

            downlinkGrantHarqIndex = downlinkGrant.HARQID;
            if strcmp(downlinkGrant.Type, 'newTx')
                type = 'newTx';
                [~, pdschIndicesInfo] = nrPDSCHIndices(carrierConfig, pdschInfo.PDSCHConfig); % Calculate PDSCH indices
                tbs = nrTBS(pdschInfo.PDSCHConfig.Modulation, pdschInfo.PDSCHConfig.NumLayers, length(DLGrantRBs), ...
                    pdschIndicesInfo.NREPerPRB, pdschInfo.TargetCodeRate, obj.Scheduler.XOverheadPDSCH); % Calculate the transport block size
                pduLen = floor(tbs/8); % In bytes
                % Generate MAC PDU
                macPDU = constructMACPDU(obj, pduLen, rnti);
            else
                type = 'reTx';
                pduLen = obj.Scheduler.TBSizeDL(rnti, downlinkGrantHarqIndex+1);
            end
            pdschInfo.TBS = pduLen;

            % Set reserved REs information. Generate 0-based
            % carrier-oriented CSI-RS indices in linear indexed form
            for csirsIdx = 1:length(obj.CsirsConfig)
                csirsLocations = obj.CsirsConfig{csirsIdx}.SymbolLocations; % CSI-RS symbol locations
                if obj.Scheduler.DuplexMode == 0 || all(obj.Scheduler.DLULSlotFormat(obj.CurrDLULSlotIndex + 1, csirsLocations+1) == obj.DLType)
                    % (Mode is FDD) or (Mode is TDD and CSI-RS symbols are DL symbols)
                    pdschInfo.PDSCHConfig.ReservedRE = [pdschInfo.PDSCHConfig.ReservedRE; nrCSIRSIndices(carrierConfig, obj.CsirsConfig{csirsIdx}, 'IndexBase', '0based')]; % Reserve CSI-RS REs
                end
            end
            for idx = 1:length(obj.CsirsConfigRSRP)
                csirsLocations = obj.CsirsConfigRSRP{idx}.SymbolLocations; % CSI-RS symbol locations
                if obj.Scheduler.DuplexMode == 0 || all(obj.Scheduler.DLULSlotFormat(obj.CurrDLULSlotIndex + 1, cell2mat(csirsLocations) + 1) == obj.DLType)
                    % (Mode is FDD) or (Mode is TDD and CSI-RS symbols are DL symbols)
                    pdschInfo.PDSCHConfig.ReservedRE = [pdschInfo.PDSCHConfig.ReservedRE; nrCSIRSIndices(carrierConfig, obj.CsirsConfigRSRP{idx}, 'IndexBase', '0based')]; % Reserve CSI-RS REs
                end
            end            

            obj.TimingInfo.Timestamp = currentTime;
            obj.TxDataRequestFcn(pdschInfo, macPDU, obj.TimingInfo);
        end

        function rxRequestToPhy(obj, rnti, uplinkGrant, currentTime)
            % rxRequestToPhy Send Rx request to Phy

            puschInfo = obj.PUSCHInfo; % Information to be passed to Phy for PUSCH reception
            RBGAllocationBitmap = uplinkGrant.RBGAllocationBitmap;
            numPUSCHRBs = obj.Scheduler.NumPUSCHRBs;
            ULGrantRBs = -1*ones(numPUSCHRBs, 1); % To store RB indices of UL grant
            rbgSizeUL = obj.Scheduler.RBGSizeUL;
            for RBGIndex = 0:(length(RBGAllocationBitmap)-1) % For all RBGs
                if RBGAllocationBitmap(RBGIndex+1) % If RBG is set in bitmap
                    startRBInRBG = rbgSizeUL*RBGIndex;
                    % If the last RBG of BWP is assigned, then it might
                    % not have the same number of RBs as other RBG
                    if RBGIndex == (length(RBGAllocationBitmap)-1)
                        ULGrantRBs(startRBInRBG + 1 : end) =  ...
                            startRBInRBG : numPUSCHRBs-1 ;
                    else
                        ULGrantRBs((startRBInRBG + 1) : (startRBInRBG + rbgSizeUL)) =  ...
                            startRBInRBG : (startRBInRBG + rbgSizeUL -1);
                    end
                end
            end
            ULGrantRBs = ULGrantRBs(ULGrantRBs >= 0);
            puschInfo.PUSCHConfig.PRBSet = ULGrantRBs;
            % Get the corresponding row from the mcs table
            mcsInfo = obj.Scheduler.MCSTableUL(uplinkGrant.MCS + 1, :);
            modSchemeBits = mcsInfo(1); % Bits per symbol for modulation scheme (stored in column 1)
            puschInfo.TargetCodeRate = mcsInfo(2)/1024; % Coderate (stored in column 2)
            % Modulation scheme and corresponding bits/symbol
            fullmodlist = ["pi/2-BPSK", "BPSK", "QPSK", "16QAM", "64QAM", "256QAM"]';
            qm = [1 1 2 4 6 8];
            modScheme = fullmodlist(modSchemeBits == qm); % Get modulation scheme string
            puschInfo.PUSCHConfig.Modulation = modScheme(1);
            puschInfo.PUSCHConfig.RNTI = rnti;
            puschInfo.PUSCHConfig.NID = obj.NCellID;
            puschInfo.NSlot = obj.CurrSlot;
            puschInfo.HARQID = uplinkGrant.HARQID;
            puschInfo.RV = uplinkGrant.RV;
            puschInfo.PUSCHConfig.SymbolAllocation = [uplinkGrant.StartSymbol uplinkGrant.NumSymbols];
            puschInfo.PUSCHConfig.MappingType = uplinkGrant.MappingType;
            puschInfo.PUSCHConfig.NumLayers = uplinkGrant.NumLayers;
            puschInfo.PUSCHConfig.TransmissionScheme = 'codebook';
            puschInfo.PUSCHConfig.NumAntennaPorts = uplinkGrant.NumAntennaPorts;
            puschInfo.PUSCHConfig.TPMI = uplinkGrant.TPMI;
            if isequal(uplinkGrant.MappingType, 'A')
                dmrsAdditonalPos = obj.Scheduler.PUSCHDMRSAdditionalPosTypeA;
            else
                dmrsAdditonalPos = obj.Scheduler.PUSCHDMRSAdditionalPosTypeB;
            end
            puschInfo.PUSCHConfig.DMRS.DMRSLength = uplinkGrant.DMRSLength;
            puschInfo.PUSCHConfig.DMRS.DMRSAdditionalPosition = dmrsAdditonalPos;
            puschInfo.PUSCHConfig.DMRS.NumCDMGroupsWithoutData = uplinkGrant.NumCDMGroupsWithoutData;

            % Carrier configuration
            carrierConfig = obj.CarrierConfigUL;
            carrierConfig.NSlot = puschInfo.NSlot;

            if strcmp(uplinkGrant.Type, 'newTx') % New transmission
                % Calculate TBS
                [~, puschIndicesInfo] = nrPUSCHIndices(carrierConfig, puschInfo.PUSCHConfig);
                tbs = nrTBS(puschInfo.PUSCHConfig.Modulation, puschInfo.PUSCHConfig.NumLayers, length(ULGrantRBs), ...
                    puschIndicesInfo.NREPerPRB, puschInfo.TargetCodeRate);
                puschInfo.TBS = floor(tbs/8); % TBS in bytes
            else % Retransmission
                % Use TBS of the original transmission
                puschInfo.TBS = obj.Scheduler.TBSizeUL(rnti, uplinkGrant.HARQID+1);
            end

            obj.TimingInfo.Timestamp = currentTime;
            % Call Phy to start receiving PUSCH
            obj.RxDataRequestFcn(puschInfo, obj.TimingInfo);
        end

        function nextInvokeTime = getNextInvokeTime(obj, currentTime)
            %getNextInvokeTime Return the next invoke time in nanoseconds

            % Find the duration completed in the current symbol
            durationCompletedInCurrSlot = mod(currentTime, obj.SlotDurationInNS);
            currSymDurCompleted = obj.SymbolDurationsInSlot(obj.CurrSymbol+1) - obj.SymbolEndTimesInSlot(obj.CurrSymbol+1) + durationCompletedInCurrSlot;

            totalSymbols = obj.NumSymInFrame;
            symbolNumFrame = obj.CurrSlot*14 + obj.CurrSymbol;
            % Data Tx time
            nextTxStartSymbol = find(~cellfun('isempty',obj.DownlinkTxContext(:, symbolNumFrame+2:totalSymbols)), 1);
            nextTxStartSymbol = ceil(nextTxStartSymbol/numel(obj.UEs));
            if isempty(nextTxStartSymbol)
                nextTxStartSymbol = find(~cellfun('isempty',obj.DownlinkTxContext(:, 1:symbolNumFrame)), 1);
                nextTxStartSymbol = (totalSymbols-symbolNumFrame-1) + ceil(nextTxStartSymbol/numel(obj.UEs));
            end

            % Data Rx time
            nextRxStartSymbol = find(~cellfun('isempty',obj.UplinkRxContext(:, symbolNumFrame+2:totalSymbols)), 1);
            nextRxStartSymbol = ceil(nextRxStartSymbol/numel(obj.UEs));
            if isempty(nextRxStartSymbol)
                nextRxStartSymbol = find(~cellfun('isempty',obj.UplinkRxContext(:, 1:symbolNumFrame)), 1);
                nextRxStartSymbol = (totalSymbols-symbolNumFrame-1) + ceil(nextRxStartSymbol/numel(obj.UEs));
            end

            nextInvokeSymbol = min([nextTxStartSymbol nextRxStartSymbol inf]);
            nextInvokeTime = inf;
            if nextInvokeSymbol ~= inf
                numSlots = floor(nextInvokeSymbol/14);
                numSymbols = mod(nextInvokeSymbol,14);
                if obj.CurrSymbol + numSymbols > 14
                    totalSymbolsDuration = sum(obj.SymbolDurationsInSlot(obj.CurrSymbol+1:14)) + sum(obj.SymbolDurationsInSlot(1:obj.CurrSymbol+numSymbols-14));
                else
                    totalSymbolsDuration = sum(obj.SymbolDurationsInSlot(obj.CurrSymbol+1:obj.CurrSymbol+numSymbols));
                end
                nextInvokeTime = currentTime + (numSlots * obj.SlotDurationInNS) + totalSymbolsDuration - currSymDurCompleted;
            end

            % Control Tx
            controlTxStartTime = min(obj.CSIRSTxInfo(:, 2));
            % Control Rx
            controlRxStartTime = min(obj.SRSRxInfo(:, 2));

            nextInvokeTime = min([obj.SchedulerNextInvokeTime nextInvokeTime controlTxStartTime controlRxStartTime]);
        end
    end
end