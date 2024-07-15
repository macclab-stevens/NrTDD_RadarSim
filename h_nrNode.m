classdef (Abstract) h_nrNode < wirelessnetwork.internal.wirelessNode
    %nrNode Node class containing properties and components common for
    % both gNB node and UE node
    %
    %   Note: This is an internal undocumented class and its API and/or
    %   functionality may change in subsequent releases.

    % Copyright 2022-2023 The MathWorks, Inc.

    properties(Hidden)
        %TrafficManager Traffic manager
        TrafficManager

        %RLCEntity RLC layer entity
        RLCEntity

        %MACEntity MAC layer entity
        MACEntity

        %PhyEntity Physical layer entity
        PhyEntity
    end

    properties (Access = protected)
        %CurrentTime Current time in seconds
        % Current time gets updated every time the node runs
        CurrentTime = [];

        %CurrentTimeInNanoseconds Current time in nanoseconds
        CurrentTimeInNanoseconds = 0;

        %EventDataObj Event data object
        EventDataObj

        %PHYAbstraction PHY abstraction flag as true or false
        PHYAbstraction
    end

    properties (SetAccess = protected, Hidden)
        %DLCarrierFrequency Downlink carrier frequency in Hz
        DLCarrierFrequency

        %ULCarrierFrequency Uplink carrier frequency in Hz
        ULCarrierFrequency

        %FullBufferTraffic Full buffer traffic configuration for connected
        %nodes
        % Array of strings where each element represents the full buffer
        % traffic configuration for a connected node
        FullBufferTraffic = ""
    end

    properties (Access = protected, Constant)
        % MaxLogicalChannels Maximum number of logical channels
        %   Maximum number of logical channels that can be configured
        %   between a UE and its associated gNB, specified in the [1, 32]
        %   range. For more details, refer 3GPP TS 38.321 Table 6.2.1-1
        MaxLogicalChannels = 4;
    end

    % Constant, hidden properties
    properties (Constant,Hidden)
        PHYAbstraction_Values  = ["linkToSystemMapping","none"];
    end

    events(Hidden)
        %AppDataReceived Packet reception at application layer
        %   This event is triggered when data is received at application
        %   layer from the layer below. It passes the event notification
        %   along with structure containing these fields to the registered
        %   callback:
        %   CurrentTime    - Current simulation time in seconds
        %   Packet         - Received application data in decimal bytes,
        %                    returned as vector of integers in the range [0,
        %                    255]
        %   PacketLength   - Length of data in bytes
        AppDataReceived

        %MACPDUReceived MAC PDU reception from PHY
        %   This event is triggered when data is received at MAC from PHY
        %   layer of the node. It passes the event notification along with
        %   structure containing these fields to the registered callback:
        %   CurrentTime  - Current simulation time in seconds
        %   NCellID      - Cell ID
        %   RNTI         - RNTI of the UE associated with the MAC PDU
        %   DuplexMode   - Duplex mode (FDD as 0, TDD as 1)
        %   TimingInfo   - Timing information as vector of 3 elements of
        %                  the form [SystemFrameNumber SlotNumber
        %                  SymbolNumber]
        %   LinkType     - Link direction (0 for DL, 1 for UL)
        %   HARQID       - HARQ process ID associated with the MAC PDU
        %   MACPDU       - MAC PDU in decimal bytes. It is represented as
        %                  vector of integers in the range [0, 255]
        MACPDUReceived
    end

    methods
        function obj = nrNode()
            %nrNode Initialize the object properties with default values

            % Create an event data object
            obj.EventDataObj = wirelessnetwork.internal.nodeEventData;
        end

        function addTrafficSource(obj, trafficSource, varargin)
            %addTrafficSource Add data traffic source to 5G NR node
            %   addTrafficSource(OBJ, TRAFFICSOURCE) adds a data traffic source object,
            %   TRAFFICSOURCE, to the node, OBJ. TRAFFICSOURCE is an object of type
            %   <a href="matlab:help('networkTrafficOnOff')">networkTrafficOnOff</a>, <a href="matlab:help('networkTrafficFTP')">networkTrafficFTP</a>, <a href="matlab:help('networkTrafficVoIP')">networkTrafficVoIP</a>, or
            %   <a href="matlab:help('networkTrafficVideoConference')">networkTrafficVideoConference</a>. Because an NR node always generates
            %   an application packet with payload, the GeneratePacket property
            %   of a traffic source object is not applicable to an NR node.
            %   OBJ is an object of type <a href="matlab:help('nrGNB')">nrGNB</a> or <a
            %   href="matlab:help('nrUE')">nrUE</a>. addTrafficSource(...,Name=Value)
            %   specifies additional name-value argument as described below.
            %
            %   DestinationNode  - Specify the destination node as an
            %                      object of type <a
            %                      href="matlab:help('nrUE')">nrUE</a>. Set this N-V
            %                      argument only if OBJ is of type <a
            %                      href="matlab:help('nrGNB')">nrGNB</a>. It is
            %                      automatically set as gNB to which UE is connected,
            %                      if OBJ is of type <a
            %                      href="matlab:help('nrUE')">nrUE</a>.
            %
            %   LogicalChannelID - Specify the logical channel identifier
            %                      as an integer scalar within the range [4-32]. The
            %                      added traffic will be mapped to the specified
            %                      logical channel. If no logical channel is specified,
            %                      the traffic will be mapped to the logical channel
            %                      with the smallest ID. If the traffic is mapped to a
            %                      logical channel which is not yet established, error
            %                      will be thrown.

            % First argument must be scalar object
            validateattributes(obj, {'nrGNB', 'nrUE'}, {'nonempty', 'scalar'}, mfilename, 'obj');

            coder.internal.errorIf(~isempty(obj.CurrentTime), 'nr5g:nrNode:NotSupportedOperation', 'addTrafficSource');

            % Validate data source object
            validateattributes(trafficSource, {'networkTrafficOnOff', 'networkTrafficFTP', ...
                'networkTrafficVoIP', 'networkTrafficVideoConference'}, {'scalar'}, ...
                mfilename, 'traffic source');

            % Name-value pair check
            coder.internal.errorIf(mod(numel(varargin), 2) == 1, 'MATLAB:system:invalidPVPairs');

            [upperLayerDataInfo, rlcEntity] = nr5g.internal.nrNodeValidation.validateNVPairAddTrafficSource(obj, varargin);
            % Add the traffic source to traffic manager
            addTrafficSource(obj.TrafficManager, trafficSource, upperLayerDataInfo, @rlcEntity.enqueueSDU);
        end
    end

    methods(Hidden)
        function nextInvokeTime = run(obj, currentTime)
            %run Run the 5G NR node
            %
            %   NEXTINVOKETIME = run(OBJ, CURRENTTIME) runs the 5G NR node
            %   at current time and returns the time at which the node must
            %   be invoked again.
            %
            %   NEXTINVOKETIME is the time (in seconds) at which node must
            %   be invoked again.
            %
            %   OBJ is an object of type nrGNB or nrUE.
            %
            %   CURRENTTIME is the current simulation time in seconds.

            % First argument must be scalar object
            validateattributes(obj, {'nrGNB', 'nrUE'}, {'nonempty', 'scalar'}, mfilename, 'obj');
            obj.CurrentTime = currentTime;
            obj.CurrentTimeInNanoseconds = round(currentTime * 1e9);  % Convert time into nanoseconds
            if obj.ReceiveBufferIdx ~= 0 % Rx buffer has data to be processed
                % Pass the data to layers for processing
                nextInvokeTime = runLayers(obj, obj.CurrentTimeInNanoseconds, [obj.ReceiveBuffer{1:obj.ReceiveBufferIdx}]);
                obj.ReceiveBufferIdx = 0;
            else % Rx buffer has no data to process
                % Update the current time for all the layers
                nextInvokeTime = runLayers(obj, obj.CurrentTimeInNanoseconds, {});
            end
        end

        function addToTxBuffer(obj, packet)
            %addToTxBuffer Adds the packet to Tx buffer
            %
            % OBJ is an object of type nrGNB or nrUE. PACKET is the 5G
            % packet to be transmitted. It is a structure of the format <a
            % href="matlab:help('wirelessnetwork.internal.wirelessPacket')">wirelessPacket</a>

            packet.TransmitterID = obj.ID;
            packet.TransmitterPosition = obj.Position;
            obj.TransmitterBuffer = [obj.TransmitterBuffer packet];
        end

        function pushReceivedData(obj, packet)
            %pushReceivedData Push the received packet to node
            %
            % OBJ is an object of type nrGNB or nrUE. PACKET is the
            % received packet. It is a structure of the format <a href="matlab:help('wirelessnetwork.internal.wirelessPacket')">wirelessPacket</a>

            % Check if PHY flavor matches for the node and the received packet
            if ~packet.DirectToDestination && (packet.Abstraction ~= obj.PHYAbstraction)
                coder.internal.error('nr5g:nrNode:MixedPHYFlavorNotSupported')
            end
            % Copy the received packet to the buffer
            obj.ReceiveBufferIdx = obj.ReceiveBufferIdx + 1;
            obj.ReceiveBuffer{obj.ReceiveBufferIdx} = packet;
        end

        function [flag, rxInfo] = isPacketRelevant(obj, packet)
            %isPacketRelevant Check whether packet is relevant for the node
            %
            %   [FLAG, RXINFO] = isPacketRelevant(OBJ, PACKET) determines
            %   whether the packet is relevant for the node and returns a
            %   flag, FLAG, indicating the decision. It also returns
            %   receiver information, RXINFO, needed for applying channel
            %   on the incoming packet, PACKET.
            %
            %   FLAG is a logical scalar value indicating whether to invoke
            %   channel or not. Value 1 represents that packet is relevant.
            %
            %   The function returns the output, RXINFO, and is valid only
            %   when the FLAG value is 1 (true). The structure of this
            %   output contains these fields:
            %
            %   ID       - Node identifier of the receiver
            %   Position - Current receiver position in Cartesian coordinates,
            %              specified as a real-valued vector of the form [x
            %              y z]. Units are in meters.
            %   Velocity - Current receiver velocity (v) in the x-, y-, and
            %              z-directions, specified as a real-valued vector
            %              of the form [vx vy vz]. Units are in meters per
            %              second.
            %   NumReceiveAntennas - Number of receive antennas on node
            %
            %   OBJ is an object of type <a href="matlab:help('nrGNB')">nrGNB</a> or <a href="matlab:help('nrUE')">nrUE</a>
            %   
            %   PACKET is the packet received from the channel, specified as 
            %   structure of the format <a href="matlab:help('wirelessnetwork.internal.wirelessPacket')">wirelessPacket</a>.

            % Technology agnostic filtering
            [flag, rxInfo] = isPacketRelevant@wirelessnetwork.internal.wirelessNode(obj, packet);

            % Technology specific filtering
            if flag
                % Check if packet is intra-cell and reject if irrelevant
                if ~intracellPacketRelevance(obj, packet)
                    flag = 0;
                    return;
                end

                % Check if node is scheduled to be receiving during packet duration
                if ~rxOn(obj, packet)
                    flag = 0;
                    return;
                end

                rxInfo.NumReceiveAntennas = obj.NumReceiveAntennas;
            end
        end

        function processEvents(obj, eventName, data)
            % Send the event notification to listeners

            if event.hasListener(obj, eventName)
                data.CurrentTime = obj.CurrentTime;
                obj.EventDataObj.Data = data;
                % Notify listeners about the event
                notify(obj, eventName, obj.EventDataObj);
            end
        end
    end

    methods (Access = protected)
        function addRLCBearer(obj, rlcConnectionInfo)
            %addRLCBearer Add RLC entity to node and its associated logical
            %channel to MAC

            % Check if full buffer is configured
            if rlcConnectionInfo.FullBufferTraffic ~= "off"
                addRLCBearerForFullBuffer(obj, rlcConnectionInfo);
            else
                addRLCBearerForCustomTraffic(obj, rlcConnectionInfo);
            end
        end

        function nextInvokeTime = runLayers(obj, currentTime, packets)
            %runLayers Run the node with the received packet and returns the next invoke time (in seconds)

            % Run the application traffic manager
            nextAppTime = run(obj.TrafficManager, currentTime);

            % Run the MAC layer operations
            nextMACTime = run(obj.MACEntity, currentTime, packets);

            % Run the PHY operations
            nextPHYTime = run(obj.PhyEntity, currentTime, packets);

            % Find the next invoke time (in seconds) for the node
            nextInvokeTime = min([nextAppTime nextMACTime nextPHYTime]) * 1e-9;
        end

        function addRLCBearerForFullBuffer(obj, rlcConnectionInfo)
            %addRLCBearerForFullBuffer Add RLC bearer when full buffer is
            %enabled

            macEntity = obj.MACEntity;
            rlcBearerConfig = nrRLCBearerConfig();
            % Establish an RLC passthrough entity and associated logical
            % channel when full buffer is enabled
            if macEntity.MACType == 0 % In case of gNB
                if rlcConnectionInfo.FullBufferTraffic ~= "ul"
                    % Establish an RLC passthrough entity with transmitting
                    % capability when full buffer is not exclusively
                    % enabled on UL. This indicates it is enabled using
                    % value 'on' or 'DL'
                    rlcEntity = nr5g.internal.nrRLCPassthrough(rlcConnectionInfo.RNTI, ...
                        rlcBearerConfig.LogicalChannelID, @macEntity.updateBufferStatus);
                else
                    rlcEntity = nr5g.internal.nrRLCPassthrough(rlcConnectionInfo.RNTI, ...
                        rlcBearerConfig.LogicalChannelID, []);
                end
            else %  In case of UE
                if rlcConnectionInfo.FullBufferTraffic ~= "dl"
                    % Establish an RLC passthrough entity with transmitting
                    % capability when full buffer is not exclusively
                    % enabled on DL. This indicates it is enabled using
                    % value 'on' or 'UL'
                    rlcEntity = nr5g.internal.nrRLCPassthrough(rlcConnectionInfo.RNTI, ...
                        rlcBearerConfig.LogicalChannelID, @macEntity.updateBufferStatus);
                else
                    rlcEntity = nr5g.internal.nrRLCPassthrough(rlcConnectionInfo.RNTI, ...
                        rlcBearerConfig.LogicalChannelID, []);
                end
            end
            obj.RLCEntity{end+1} = rlcEntity;

            % Add MAC logical channel configuration for full buffer traffic
            % case
            addLogicalChannelInfo(macEntity, rlcBearerConfig, rlcConnectionInfo.RNTI);
            registerRLCInterfaceFcn(macEntity, rlcConnectionInfo.RNTI, rlcBearerConfig.LogicalChannelID, @rlcEntity.sendPDUs, @rlcEntity.receivePDUs);
        end

        function addRLCBearerForCustomTraffic(obj, rlcConnectionInfo)
            %addRLCBearerForCustomTraffic Add RLC bearer for custom traffic

            macEntity = obj.MACEntity;
            trafficManager = obj.TrafficManager;
            rnti = rlcConnectionInfo.RNTI;
            maxReassemblySDU = macEntity.NumHARQ;
            % Set up a default RLC bearer if no RLC bearer configuration is
            % provided
            rlcBearerConfigSet = rlcConnectionInfo.RLCBearerConfig;
            if isempty(rlcBearerConfigSet)
                rlcBearerConfigSet = nrRLCBearerConfig();
            end
            % Establish RLC entities and their associated logical channel at
            % MAC by iterating through the given RLC bearer configuration objects
            for rlcBearerIdx = 1:length(rlcBearerConfigSet)
                rlcBearerConfig = rlcBearerConfigSet(rlcBearerIdx);

                % Set up RLC entity at RLC layer
                if rlcBearerConfig.RLCEntityType == "UM"
                    rlcEntity = nr5g.internal.nrRLCUM(rnti, rlcBearerConfig, maxReassemblySDU, @macEntity.updateBufferStatus, @trafficManager.receivePacket);
                else
                    if rlcBearerConfig.RLCEntityType == "UMDL"
                        rlcEntityType = 0;
                    else
                        rlcEntityType = 1;
                    end
                    if rlcEntityType == macEntity.MACType
                        rlcEntity = nr5g.internal.nrRLCUM(rnti, rlcBearerConfig, maxReassemblySDU, @macEntity.updateBufferStatus, []);
                    else
                        rlcEntity = nr5g.internal.nrRLCUM(rnti, rlcBearerConfig, maxReassemblySDU, [], @trafficManager.receivePacket);
                    end
                end
                obj.RLCEntity{end+1} = rlcEntity;

                % Set up logical channel at MAC layer
                addLogicalChannelInfo(macEntity, rlcBearerConfig, rlcConnectionInfo.RNTI);
                registerRLCInterfaceFcn(macEntity, rlcConnectionInfo.RNTI, rlcBearerConfig.LogicalChannelID, ...
                    @rlcEntity.sendPDUs, @rlcEntity.receivePDUs);
            end
        end
    end

    methods (Hidden)
        function sendPacketToRLC(obj, packetInfo)
            %sendPacketToRLC Send a packet received from user to RLC queue
            %   sendPacketToRLC(OBJ, PACKETINFO) sends a packet received
            %   from user to RLC queue.
            %
            %   OBJ is an object of type nrGNB or nrUE.
            %
            %   PACKETINFO is a structure with these mandatory fields.
            %       RNTI   - Radio network temporary identifier of a UE.
            %       Packet - Array of octets in decimal format.
            %       DestinationNodeID - Destination node ID.
            %       LogicalChannelID  - Logical channel ID.

            packetInfo.PacketLength = length(packetInfo.Packet);
            % Get the corresponding RLC entity for the received packet
            rlcEntity = nr5g.internal.nrNodeValidation.getRLCEntity(obj, packetInfo);
            if ~isempty(rlcEntity)
                 % Send the packet to the RLC entity
                enqueueSDU(rlcEntity, packetInfo);
            end
            enda

        function flag = rxOn(obj, packet)
            %rxOn Returns whether Rx is scheduled to be on during the packet duration

            flag = rxOn(obj.MACEntity, packet);
        end

    end
end