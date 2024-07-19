classdef (Abstract) hNRNode < wirelessnetwork.internal.wirelessNode
    %hNRNode Node class containing properties and components common for
    %both gNB node and UE node

    % Copyright 2019-2023 The MathWorks, Inc.

    properties (Access = public)
        % AppLayer Application layer object
        AppLayer

        % RLCEntities A set of RLC entities
        % Each entity corresponds to a configured MAC logical channel. For
        % gNB, it is a 2D array with each row corresponding to a UE
        RLCEntities

        % MACEntity A MAC entity associated with this node
        MACEntity

        % PhyEntity A physical layer entity associated with this node
        PhyEntity

        % DistanceCalculatorFcn Function handle to calculate distance between nodes
        % Specify this property as a function handle to the distance
        % calculator function. If empty, Euclidean distance is used for
        % node distance calculation.
        DistanceCalculatorFcn
    end

    properties (Access = protected)
        %TransmitBuffer Buffer contains the data to be transmitted from the
        %node
        TransmitBuffer = cell(1, 1);

        %TxBufferIdx Index used to identify the number of signals in the
        %Tx buffer
        TxBufferIdx = 0;
        
        % RxBuffer Rx buffer contains the received packets to be processed
        RxBuffer = cell(1, 1);

        % RxBufferIdx Index used to identify the number of signals in the
        % Rx buffer
        RxBufferIdx = 0;

        % RLCNextInvokeTime Time (in nanoseconds) after which RLC will get invoked
        RLCNextInvokeTime = 0;

        % CurrentTime Current time in seconds. This will be updated for
        % every call of the runNode with the received timestamp
        CurrentTime = 0;

        % CurrentTimeInNanoseconds Current time in nanoseconds
        CurrentTimeInNanoseconds = 0;

        %RxInfo Structure containing the receiver information to be passed
        %to the channel
        RxInfo
    end

    properties (Access = protected, Constant)
        % MaxApplications Maximum number of applications
        %   Maximum number of applications that can be configured on a node
        MaxApplications = 16;
        % MaxLogicalChannels Maximum number of logical channels
        %   Maximum number of logical channels that can be configured
        %   between a UE and its associated gNB, specified in the [1, 32]
        %   range. For more details, refer 3GPP TS 38.321 Table 6.2.1-1
        MaxLogicalChannels = 4;
        % NumRLCStats Number of RLC layer statistics collected
        NumRLCStats = 21;
        % RLCInvocationPeriodicity RLC invocation periodicity in nanoseconds
        RLCInvocationPeriodicity = 1e6;
    end

    methods
        function obj = hNRNode()
            %hNRNode Initialize the object properties with default values

            % For gNB, the default initialization considers only one UE
            % associated with it
            obj.RLCEntities = cell(1, obj.MaxLogicalChannels);
            obj.AppLayer = hApplication('ID', obj.ID, 'MaxApplications', ...
                obj.MaxApplications);

            % Initialize receiver information
            obj.RxInfo = struct('ID',0,'Position',[0 0 0],'Velocity',[0 0 0]);
        end

        function nextInvokeTime = runNode(obj, currentTime)
            %runNode Run the 5G NR node
            %
            %   NEXTINVOKETIME = runNode(OBJ, CURRENTTIME) runs the 5G NR
            %   node at current time and returns the time at which to run
            %   the node again.
            %
            %   NEXTINVOKETIME is the time (in seconds) at which the node
            %   must be invoked again.
            %
            %   OBJ is an object of type hNRGNB or hNRUE.
            %
            %   CURRENTTIME is the current simulation time in seconds.

            % Convert time into nanoseconds
            currentTimeInNanoseconds = round(currentTime * 1e9);
            
            if obj.RxBufferIdx ~= 0 % Rx buffer has data to be processed
                % Pass the data to layers for processing
                nextInvokeTime = runLayers(obj, currentTimeInNanoseconds, obj.RxBuffer(1:obj.RxBufferIdx));
                obj.RxBufferIdx = 0;
            else % Rx buffer has no data to process
                % Update the current time for all the layers
                nextInvokeTime = runLayers(obj, currentTimeInNanoseconds, {});
            end
            obj.CurrentTime = currentTime;
            obj.CurrentTimeInNanoseconds = currentTimeInNanoseconds;
        end

        function addApplication(obj, rnti, lcid, app)
            %addApplication Add application traffic model to the node
            %
            % appApplication(OBJ, RNTI, LCID, APPCONFIG) adds the
            % application traffic model for LCID in the node. If the node
            % is UE, the traffic is in UL direction. If it is gNB, it is in
            % DL direction for the UE identified by RNTI.
            %
            % RNTI is a radio network temporary identifier, specified
            % within [1 65519]. Refer table 7.1-1 in 3GPP TS 38.321.
            %
            % LCID is a logical channel id, specified in the range
            % between 1 and 32, inclusive.
            %
            % APP is a handle object that generates the application
            % traffic.

            % Create metadata structure for newly adding application that
            % helps the application layer in packet generration and
            % transmission
            metadata.PriorityID = lcid;
            if obj.MACEntity.MACType == 0
                % On gNB side, RNTI acts as the destination of application
                % packet
                metadata.DestinationNode = rnti;
            else
                % On UE side, 0 acts as the destination of application
                % packet
                metadata.DestinationNode = 0;
            end
            % Add the application to application layer
            addApplication(obj.AppLayer, app, metadata);
        end

        function configureLogicalChannel(obj, rnti, rlcChannelConfig)
            %configureLogicalChannel Configure a logical channel
            %   configureLogicalChannel(OBJ, RNTI, RLCCHANNELCONFIG)
            %   configures a logical channel by creating an associated RLC
            %   entity and updating this logical channel information in the
            %   MAC.
            %
            %   RNTI is a radio network temporary identifier, specified
            %   within [1 65519]. Refer table 7.1-1 in 3GPP TS 38.321.
            %
            %   RLCCHANNELCONFIG is a RLC channel configuration structure.
            %   For RLC transmitter entity RLCCHANNELCONFIG contains these
            %   fields:
            %       EntityType         - Indicates the RLC entity type. It
            %                            can take values in the range [0,
            %                            3]. The values 0, 1, 2, and 3
            %                            indicate RLC UM unidirectional DL
            %                            entity, RLC UM unidirectional UL
            %                            entity, RLC UM bidirectional
            %                            entity, and RLC AM entity,
            %                            respectively
            %       LogicalChannelID    - Logical channel id
            %       SeqNumFieldLength   - Sequence number field length (in
            %                             bits) for transmitter and
            %                             receiver. So, it is a 1-by-2
            %                             matrix
            %       MaxTxBufferSDUs     - Maximum Tx buffer size in term of
            %                             RLC SDUs
            %       PollPDU             - Number of PDUs that must be sent
            %                             before requesting status report
            %                             in the RLC AM entity
            %       PollByte            - Number of RLC SDU bytes that must
            %                             be sent before requesting status
            %                             report in the RLC AM entity
            %       PollRetransmitTimer - Poll retransmit timer value (in
            %                             ms) that is used in the RLC AM
            %                             entity
            %       ReassemblyTimer     - Reassembly timer value (in ms)
            %
            %       StatusProhibitTimer - Status prohibit timer value (in
            %                             ms)
            %       LCGID               - Logical channel group id
            %       Priority            - Priority of the logical channel
            %       PBR                 - Prioritized bit rate (in kilo
            %                             bytes per second)
            %       BSD                 - Bucket size duration (in ms)

            macEntity = obj.MACEntity;
            % Determine the logical channel index of a UE in the logical
            % channel set
            if macEntity.MACType
                % If it is UE, there will be only one logical channel set
                logicalChannelSetIndex = 1;
            else
                % If it is gNB, then RNTI becomes logical channel set index
                logicalChannelSetIndex = rnti;
            end

            % Alter the entity type value in the given configuration
            % structure from 0 to 1 and 1 to 0 for UE device. This
            % alteration helps in UE side RLC entities to choose receiver
            % configuration on 0 and transmitter configuration on 1 from
            % the structure in case of unidirectional RLC UM entities
            if macEntity.MACType && isfield(rlcChannelConfig, 'EntityType') && ...
                    any(rlcChannelConfig.EntityType == [0 1])
                rlcChannelConfig.EntityType = ~rlcChannelConfig.EntityType;
            end
            rlcChannelConfig.RNTI = rnti;

            % Check whether the new logical channel can be established
            % between the UE and its associated gNB
            lchIdx = find(cellfun(@isempty, obj.RLCEntities(logicalChannelSetIndex, :)), 1);
            if isempty(lchIdx)
                error('nr5g:hNRNode:TooManyLogicalChannels', ...
                    ['Number of logical channels between UE', num2str(rnti), ...
                    ' and its associated gNB must not exceed the configured limit ', num2str(obj.MaxLogicalChannels)]);
            end

            % Set the RLC reassembly buffer size to the number of gaps
            % possible in the reception. The maximum possible gaps at RLC
            % entity is equal to the number of HARQ process at the MAC
            % layer
            rlcChannelConfig.MaxReassemblySDU = macEntity.NumHARQ;
            if isfield(rlcChannelConfig, 'EntityType') && rlcChannelConfig.EntityType == 3
                % Create an RLC AM entity
                obj.RLCEntities{logicalChannelSetIndex, lchIdx} = hNRAMEntity(rlcChannelConfig);
            else
                % Create an RLC UM entity
                obj.RLCEntities{logicalChannelSetIndex, lchIdx} = hNRUMEntity(rlcChannelConfig);
            end
            appLayer = obj.AppLayer;
            % Register application interface function with the RLC entity
            registerAppReceiverFcn(obj.RLCEntities{logicalChannelSetIndex, lchIdx}, @appLayer.receivePacket);
            % Register MAC interface function with the RLC entity
            registerMACInterfaceFcn(obj.RLCEntities{logicalChannelSetIndex, lchIdx}, @macEntity.updateBufferStatus);
            % Add the logical channel information to the MAC layer
            lcConfig.RNTI = rnti;
            lcConfig.LCID = rlcChannelConfig.LogicalChannelID;
            lcConfig.Priority = rlcChannelConfig.Priority;
            lcConfig.LCGID = rlcChannelConfig.LCGID;
            lcConfig.BSD = rlcChannelConfig.BSD;
            lcConfig.PBR = rlcChannelConfig.PBR;
            addLogicalChannelInfo(macEntity, lcConfig, rnti);
        end

        function enqueueRLCSDU(obj, rlcSDUInfo)
            %enqueueRLCSDU Enqueue the received RLC SDU from higher layers
            %
            % enqueueRLCSDU(OBJ, RLCSDUINFO) enqueues the received RLC SDU
            % in the respective RLC entity Tx queue.
            %
            %   RLCSDUINFO is a strcuture that contains the following
            %   fields:
            %
            %   Data is a column vector of octets in decimal format.
            %
            %   DestinationID is an unique identifier for the receiving
            %   node.
            %
            %   PRIORITYID is an identifier for the logical channel,
            %   specified in the range between 1 and 32.

            if obj.MACEntity.MACType
                % On UE side, get the RLC entity by sending its RNTI and
                % priority ID received in the RLC SDU context
                rlcEntity = getRLCEntity(obj, obj.MACEntity.RNTI, rlcSDUInfo.PriorityID);
            else
                % On gNB side, get the RLC entity by sending its
                % destination node ID and priority id received in the RLC
                % SDU context. The destination node ID acts as RNTI here
                rlcEntity = getRLCEntity(obj, rlcSDUInfo.DestinationID, rlcSDUInfo.PriorityID);
            end
            if ~isempty(rlcEntity)
                % Send the received RLC SDU to the corresponding RLC entity
                enqueueSDU(rlcEntity, rlcSDUInfo.Data);
            else
                error('nr5g:hNRNode:RLCEntityNotPresent', 'Application must be associated to a logical channel');
            end
        end

        function rlcPDUs = sendRLCPDUs(obj, rnti, lcid, grantSize, remainingGrant)
            %sendRLCPDUs Callback from MAC to RLC for getting RLC PDUs of a
            % logical channel for transmission
            %
            % RLCPDUS = sendRLCPDUs(OBJ, RNTI, LCID, GRANTSIZE,
            % REMAININGGRANT) returns the RLC PDUs.
            %
            % RNTI is a radio network temporary identifier, specified
            % within [1 65519]. Refer table 7.1-1 in 3GPP TS 38.321.
            %
            % LCID is a logical channel id, specified in the range
            % between 1 and 32, inclusive.
            %
            % GRANTSIZE is a scalar integer that specifies the resource
            % grant size in bytes.
            %
            % REMAININGGRANT is a scalar integer that specifies the
            % remaining resource grant (in bytes) available for the
            % current Tx.
            %
            % RLCPDUS is a cell array of RLC PDUs. Each element in the
            % cell represents an RLC PDU which contains column vector of
            % octets in decimal format.

            % Get the corresponding RLC entity
            rlcEntity = getRLCEntity(obj, rnti, lcid);
            % Notify the grant to the RLC entity
            rlcPDUs = sendPDU(rlcEntity, grantSize, remainingGrant);
        end

        function receiveRLCPDUs(obj, rnti, lcid, rlcPDU)
            %receiveRLCPDUs Callback to RLC to receive an RLC PDU for a
            % logical channel
            %
            % receiveRLCPDUs(OBJ, RNTI, LCID, RLCPDU)
            %
            % RNTI is a radio network temporary identifier, specified
            % within [1 65519]. Refer table 7.1-1 in 3GPP TS 38.321. It
            % identifies the transmitter UE.
            %
            % LCID is a logical channel id, specified in the range
            % between 1 and 32, inclusive.
            %
            % RLCPDU RLC PDU extracted from received MAC PDU, to be sent
            % to RLC.

            % Get the corresponding RLC entity
            rlcEntity = getRLCEntity(obj, rnti, lcid);
            % Forward the received RLC PDU to the RLC entity
            receivePDU(rlcEntity, rlcPDU);
        end

        function rlcStats = getRLCStatistics(obj, rnti)
            %getRLCStatistics Return the instantaneous RLC statistics
            %
            % RLCSTATS = getRLCStatistics(OBJ, RNTI) returns statistics
            % of its RLC entities.
            %
            % RNTI is a radio network temporary identifier, specified
            % within [1 65519]. Refer table 7.1-1 in 3GPP TS 38.321.
            %
            % RLCSTATS - RLC statistics represented as a N-by-P matrix,
            % where 'N' represent the number of logical channels and 'P'
            % represent the number of RLC layer statistics collected. The
            % 'P' columns are as follows 'RNTI', 'LCID', 'TxDataPDU',
            % 'TxDataBytes', 'ReTxDataPDU', 'ReTxDataBytes' 'TxControlPDU',
            % 'TxControlBytes', 'TxPacketsDropped', 'TxBytesDropped',
            % 'TimerPollRetransmitTimedOut', 'RxDataPDU', 'RxDataBytes',
            % 'RxDataPDUDropped', 'RxDataBytesDropped',
            % 'RxDataPDUDuplicate', 'RxDataBytesDuplicate', 'RxControlPDU',
            % 'RxControlBytes', 'TimerReassemblyTimedOut',
            % 'TimerStatusProhibitTimedOut'

            % Row index in the RLC Entity list
            if obj.MACEntity.MACType % UE
                logicalChannelSetIdx = 1;
            else % gNB
                % If it is gNB, then RNTI becomes row index
                logicalChannelSetIdx = rnti;
            end

            rlcStatsList = zeros(obj.MaxLogicalChannels, obj.NumRLCStats);
            activeLCHIds = zeros(obj.MaxLogicalChannels, 1);
            for lchIdx = 1:obj.MaxLogicalChannels
                % Check the existence of RLC entity before querying the
                % statistics
                rlcEntity = obj.RLCEntities{logicalChannelSetIdx, lchIdx};
                if isempty(rlcEntity)
                    continue;
                end
                % Get the cumulative RLC statistics of all logical
                % channels of a UE
                stats = getStatistics(rlcEntity);
                lcid = rlcEntity.LogicalChannelID;
                activeLCHIds(lchIdx) = lchIdx;
                rlcStatsList(lchIdx, :) = [rnti lcid stats'];
            end
            rlcStats = rlcStatsList(nonzeros(activeLCHIds), :); % Send the information of active logical channels
        end

        function [throughputServing, goodputServing] = getTTIBytes(obj)
            %getTTIBytes Return amount of throughput and goodput bytes sent in current symbol
            %
            % [THROUGHPUTSERVING GOODPUTSERVING] = getTTIBytes(OBJ)
            % returns the amount of throughput and goodput bytes sent in
            % the TTI which starts at current symbol.
            %
            % THROUGHPUTSERVING - MAC transmission (throughput) in bytes.
            %
            % GOODPUTSERVING - Only new MAC transmission (goodput) in bytes

            [throughputServing, goodputServing] = getTTIBytes(obj.MACEntity);
        end

        function bufferStatus = getBufferStatus(obj)
            %getBufferStatus Return the current buffer status of UEs
            %
            % BUFFERSTATUS = getBufferStatus(OBJ) Returns the UL buffer
            % status of UE, when called by UE. Returns DL buffer
            % status array containing buffer amount for each UE, when
            % called by gNB.
            %
            % BUFFERSTATUS - Represents the buffer size in bytes.

            bufferStatus = getUEBufferStatus(obj.MACEntity);
        end

        function timestamp = getCurrentTime(obj)
            %getCurrentTime Current time (in seconds) at the node

            timestamp = obj.CurrentTime;
        end

        function value = getNodeDistance(obj, refPosition)
            %getNodeDistance Get distance from the reference node in meters

            validateattributes(refPosition, {'numeric'}, {'row', 'numel', 3});
            if ~isempty(obj.DistanceCalculatorFcn)
                value = obj.DistanceCalculatorFcn(refPosition, obj.Position);
            else
                % Use Euclidean distance for distance calculation if
                % function handle is not specified
                value = norm(refPosition - obj.Position);
            end
        end

        function addToTxBuffer(obj, packetInfo)
            %addToTxBuffer Adds the packet to Tx buffer
            %
            % OBJ is an object of type hNRNode.
            %
            % PACKETINFO is the information about the packet to be
            % transmitted. Based on Phy type PACKETINFO has two formats.
            %
            % Format - 1 (waveform IQ samples): It is a structure with
            % following fields
            % 
            %     Waveform    - IQ samples of the waveform
            %     SampleRate  - Sample rate of the waveform
            %     CarrierFreq - Carrier frequency (in Hz)
            %     TxPower     - Tx power (in dBm)
            %     Position    - 3D position of the transmitting node
            %
            % Format - 2 (Unencoded packet): It is a structure with
            % following fields
            %
            %     PacketType    - Indicates type of unencoded packet
            %     Packet        - Column vector of octets in decimal format
            %     CarrierFreq   - Carrier frequency (in Hz)
            %     TxPower       - Tx power (in dBm)
            %     Position      - 3D position of the transmitting node
            %     NCellID       - Cell identifier
            %     RNTI          - Radio network temporary identifier

            obj.TxBufferIdx = obj.TxBufferIdx + 1;
            obj.TransmitBuffer{obj.TxBufferIdx} = packetInfo;
        end

        function pushReceivedData(obj, packetInfo)
            %pushReceivedData Push the received packet into Rx buffer of node
            %
            % OBJ is an object of type hNRNode.
            %
            % PACKETINFO is the information about the received packet.
            % Based on Phy type PACKETINFO has two formats.
            %
            % Format - 1 (waveform IQ samples): It is a structure with
            % following fields
            % 
            %     Waveform    - IQ samples of the waveform
            %     SampleRate  - Sample rate of the waveform
            %     CarrierFreq - Carrier frequency (in Hz)
            %     TxPower     - Tx power (in dBm)
            %     Position    - 3D position of the transmitting node
            %
            % Format - 2 (Unencoded packet): It is a structure with
            % following fields
            %
            %     PacketType    - Indicates type of unencoded packet
            %     Packet        - Column vector of octets in decimal format
            %     CarrierFreq   - Carrier frequency (in Hz)
            %     TxPower       - Tx power (in dBm)
            %     Position      - 3D position of the transmitting node
            %     NCellID       - Cell identifier
            %     RNTI          - Radio network temporary identifier

            % Copy the received signal to the buffer
            obj.RxBufferIdx = obj.RxBufferIdx + 1;
            obj.RxBuffer{obj.RxBufferIdx} = packetInfo;
        end

        function [flag, rxInfo] = channelInvokeDecision(obj, ~)
            %channelInvokeDecision Return a flag to indicate whether channel
            %has to be applied on incoming signal
            %
            %   [FLAG, RXINFO] = channelInvokeDecision(OBJ, PACKET) determines
            %   whether the node wants to receive the packet and returns a
            %   flag, FLAG, indicating the decision and the receiver
            %   information, RXINFO, needed for applying channel on the
            %   incoming packet, PACKET.
            %
            %   FLAG is a logical scalar value indicating whether to invoke
            %   channel or not.
            %
            %   The object function returns the output, RXINFO, and is valid
            %   only when the FLAG value is 1 (true). The structure of this
            %   output contains these fields:
            %
            %   ID       - Node identifier of the receiver
            %   Position - Current receiver position in Cartesian coordinates,
            %              specified as a real-valued vector of the form [x y
            %              z]. Units are in meters.
            %   Velocity - Current receiver velocity (v) in the x-, y-, and
            %              z-directions, specified as a real-valued vector of
            %              the form [vx vy vz]. Units are in meters per second.
            %
            %   OBJ is an object of type hNRNode.
            %
            % PACKETINFO is the information about the received packet.
            % Based on Phy type, PACKETINFO has two formats.
            %
            % Format - 1 (waveform IQ samples): It is a structure with
            % following fields
            % 
            %     Waveform    - IQ samples of the waveform
            %     SampleRate  - Sample rate of the waveform
            %     CarrierFreq - Carrier frequency (in Hz)
            %     TxPower     - Tx power (in dBm)
            %     Position    - 3D position of the transmitting node
            %
            % Format - 2 (Unencoded packet): It is a structure with
            % following fields
            %
            %     PacketType    - Indicates type of unencoded packet
            %     Packet        - Column vector of octets in decimal format
            %     CarrierFreq   - Carrier frequency (in Hz)
            %     TxPower       - Tx power (in dBm)
            %     Position      - 3D position of the transmitting node
            %     NCellID       - Cell identifier
            %     RNTI          - Radio network temporary identifier

            % Initialize
            flag = false;
            rxInfo = obj.RxInfo;
        end

        function txBuffer = pullTransmittedData(obj)
            %pullTransmittedData Pull the transmitted data from Tx buffer
            %   TXBUFFER = pullTransmittedData(OBJ) pulls the transmitted
            %   data from Tx buffer.
            %
            %   OBJ is an object type of hNRNode.
            %
            %   TXBUFFER is the transmitter buffer.

            txBuffer = obj.TransmitBuffer(1:obj.TxBufferIdx);

            % Reset the buffer after reading the Tx packets
            obj.TxBufferIdx = 0;
        end
    end

    methods(Access = private)
        function nextInvokeTime = runLayers(obj, currentTime, packets)
            %runLayers Run the node with the received packets and returns the next invoke time (in seconds)

            % Run the application layer
            nextAppTime = run(obj.AppLayer, currentTime, @obj.enqueueRLCSDU);
            % Run the RLC entities for updating timers
            nextRLCTime = updateRLCTimer(obj, currentTime);
            % Run the MAC layer operations
            nextMACTime = run(obj.MACEntity, currentTime, packets);
            % Run the Phy layer operations
            nextPHYTime = run(obj.PhyEntity, currentTime, packets);
            
            % Find the next invoke time (in seconds) for the node
            nextInvokeTime = min([nextAppTime nextRLCTime nextMACTime nextPHYTime]) * 1e-9;
        end

        function nextRLCTime = updateRLCTimer(obj, currentTime)
            %updateRLCTimer Update RLC timers

            elapsedTime = currentTime - obj.CurrentTimeInNanoseconds;
            % Decrement the RLC timer by elapsed time
            obj.RLCNextInvokeTime = obj.RLCNextInvokeTime - elapsedTime;
            if obj.RLCNextInvokeTime > 0
                nextRLCTime = currentTime + obj.RLCNextInvokeTime;
                return;
            end

            for ueRLCEntityIdx = 1:size(obj.RLCEntities, 1)
                for rlcEntityIdx = 1:obj.MaxLogicalChannels
                    rlcEntity = obj.RLCEntities{ueRLCEntityIdx, rlcEntityIdx};
                    % Check if the RLC entity exists
                    if isempty(rlcEntity)
                        continue;
                    end
                    handleTimerTrigger(rlcEntity);
                end
            end

            % Update the RLC next invoke time
            nextRLCTime = currentTime + obj.RLCInvocationPeriodicity;
            obj.RLCNextInvokeTime = nextRLCTime;
        end

        function rlcEntity = getRLCEntity(obj, rnti, lcid)
            %getRLCEntity Return the RLC entity
            %   RLCENTITY = getRLCEntityIndex(OBJ, RNTI, LCID) returns the
            %   RLCENTITY reference based on RNTI and LCID.
            %
            %   RNTI is a radio network temporary identifier, specified
            %   within [1 65519]. Refer table 7.1-1 in 3GPP TS 38.321.
            %
            %   LCID is a logical channel id, specified in the range
            %   between 1 and 32, inclusive.

            % Row index in the RLC Entity list
            if obj.MACEntity.MACType % UE
                rowIdx = 1;
            else % gNB
                % If it is gNB then RNTI becomes row index
                rowIdx = rnti;
            end
            rlcEntity = [];
            for colIdx = 1:obj.MaxLogicalChannels
                entity = obj.RLCEntities{rowIdx, colIdx};
                % Check the existence of RLC entity before accessing its
                % data
                if isempty(entity)
                    continue;
                end
                if entity.LogicalChannelID == lcid
                    rlcEntity = entity;
                    break;
                end
            end
        end
    end
end