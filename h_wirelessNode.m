classdef (Abstract) h_wirelessNode < handle & comm.internal.ConfigBase
    %wirelessNode Base class for wireless nodes
    %
    %   wirelessNode properties:
    %   ID          - Node identifier
    %   Name        - Node name
    %   Position    - Node position
    %
    %   wirelessNode methods:
    %
    %   wirelessNode    - Constructor. Assigns node ID and default node name
    %   reset           - Reset the node ID counter
    %   addMobility     - Add mobility model to wireless node
    %
    %   Methods that should be implemented in derived class:
    %
    %   run                 - Simulator run the node
    %   pullTransmittedData - Simulator to get the packets by a transmitting node
    %   isPacketRelevant    - Simulator checks whether the txPacket is relevant for this node
    %   pushReceivedData    - Simulator push the result of channel model into the receiver node

    %   Copyright 2021-2023 The MathWorks, Inc.

    properties
        %Name Node name
        % Specify this property as a character vector or string scalar for
        % representing the name of the node. If name is not set then a default name
        % as 'NodeX' is given to node, where 'X' is ID of the node.
        Name {mustBeTextScalar} = "";

        %Position Node position in 3-D Cartesian coordinates
        % Specify this property as a row vector of three numeric values
        % representing the [X, Y, Z] position in meters. The default value
        % is [0 0 0].
        Position = [0 0 0];
    end

    properties (Hidden)
        %Velocity Velocity in 3-D Cartesian coordinates
        % Specify this property as a row vector of three double values
        % representing the [X, Y, Z] velocity in meters per second. The
        % default value is [0 0 0]
        Velocity = [0 0 0];

        %Simulator Reference to the wirelessNetworkSimulator singleton object
        Simulator
    end

    properties (SetAccess = protected, Hidden)
        %TransmitterBuffer Transmitted packets to be distributed to other nodes
        % Vector of packets of type wirelessnetwork.internal.wirelessPacket
        % transmitted by this node and to be sent over the channel
        TransmitterBuffer

        %ReceiveBuffer Received packets to be processed by the node
        % Cell array of packets of type wirelessnetwork.internal.wirelessPacket
        % received after applying channel model
        ReceiveBuffer = cell(0,1);

        %ReceiveBufferIdx Number of packets in the ReceiveBuffer
        ReceiveBufferIdx = 0;

        %NumDevices Number of devices (network interfaces) in the node
        NumDevices = 1;

        %ReceiveFrequency Reception center frequencies of the node
        % Vector of size N, where N is the number of interfaces. The
        % units are in Hz
        ReceiveFrequency

        %ReceiveBandwidth Reception bandwidths of the node
        % Vector of size N, where N is the number of interfaces. The
        % units are in Hz
        ReceiveBandwidth
    end

    properties (SetAccess=protected, Hidden)
        %Mobility Mobility model object
        Mobility = []
    end

    properties (SetAccess = private)
        %ID Node identifier
        % Unique identifier for the node in the simulation. It is assigned
        % incrementally from 1
        ID
    end

    methods
        % Constructor
        function obj = wirelessNode()
            % Set node ID and default name

            obj.ID = obj.generateID();
            obj.Name = strcat("Node", num2str(obj.ID));
            % Initialize the receiving buffers and related properties
            obj.ReceiveBuffer = cell(obj.NumDevices, 1);
            obj.ReceiveBufferIdx = zeros(obj.NumDevices, 1);
        end

        function set.Position(obj, value)
            validateattributes(value, {'numeric'}, {'vector', 'numel', 3, 'real', 'finite'}, mfilename, 'Position')
            obj.Position = value(:)'; % Convert to a row vector
        end

        function set.Velocity(obj, value)
            validateattributes(value, {'numeric'}, {'vector', 'numel', 3, 'real', 'finite'}, mfilename, 'Velocity')
            obj.Velocity = value(:)'; % Convert to a row vector
        end

        function set.Name(obj, value)
            obj.Name = string(value);
        end

        function value = get.Position(obj)
            % Return the updated position of node when node is added to network
            % simulator and mobility model is added to node. Otherwise, return the
            % initial position of node
            if ~(isempty(obj.Mobility) || isempty(obj.Simulator))
                obj.Position = position(obj.Mobility, obj.Simulator.CurrentTime);
            end
            value = obj.Position;
        end

        function value = get.Velocity(obj)
            % Return the updated velocity of node when node is added to network
            % simulator and mobility model is added to node. Otherwise, return the
            % initial velocity of node
            if ~(isempty(obj.Mobility) || isempty(obj.Simulator)) 
                obj.Velocity = velocity(obj.Mobility, obj.Simulator.CurrentTime);
            end
            value = obj.Velocity;
        end

        function addMobility(obj, varargin)
            %addMobility Add random waypoint mobility model to wireless node
            %
            %   addMobility(OBJ, Name=Value) adds a random waypoint mobility model to a
            %   wireless node, OBJ. The OBJ can be bluetoothLENode, bluetoothNode,
            %   wlanNode, or nrUE. In the random waypoint model, a wireless node starts
            %   by pausing for some duration at a location before moving towards its
            %   next random destination (waypoint) with a random speed. The node
            %   repeats this process at each waypoint. The addMobility function sets
            %   the random waypoint mobility configuration parameters using one or more
            %   optional name-value arguments. When you do not specify a name-value
            %   argument corresponding to a configuration parameter, the function
            %   assigns a default value to it. You can add random waypoint mobility
            %   models to multiple wireless nodes in a single addMobility function
            %   call, but these nodes must all use same mobility parameter values
            %   specified in the name-value arguments. To set the mobility parameters,
            %   use these name-value arguments.
            %
            %   SpeedRange    - Speed range [minSpeed, maxSpeed] used for setting the
            %                   speed of a node according to a continuous uniform
            %                   distribution. minSpeed and maxSpeed indicate the
            %                   minimum speed and the maximum speed, respectively. The
            %                   default value is [0.415 1.66]. Units are in meters per
            %                   second.
            %   PauseDuration - Pause duration of a node after reaching a target waypoint,
            %                   specified as a nonnegative numeric scalar. Units are in
            %                   seconds. The default value is 0.
            %   BoundaryShape - Shape of the node's mobility area, specified as
            %                   "rectangle" or "circle". The default value is
            %                   "rectangle".
            %   Bounds        - Center coordinates and dimensions of the mobility area,
            %                   specified as a three-element numeric vector or
            %                   four-element numeric vector. Units are in meters.
            %                   * If the value of BoundaryShape is "rectangle", the
            %                     vector is of the format [center's X-coordinate,
            %                     center's Y-coordinate, length, width]. The default
            %                     value for the rectangular boundary shape is
            %                     [X-coordinate of the current node position,
            %                     Y-coordinate of the current node position, 10, 10].
            %                   * If the value of BoundaryShape is "circle", the vector
            %                     is of the format [center's X-coordinate, center's
            %                     Y-coordinate, radius]. The default value for the
            %                     circular boundary shape is [X-coordinate of the
            %                     current node position, Y-coordinate of the current
            %                     node position, 10].

            % Name-value pair check
            coder.internal.errorIf(mod(numel(varargin), 2) == 1, 'MATLAB:system:invalidPVPairs');
            % Validate the given name-value pairs
            mobilityParam = validateMobilityInputs(obj, varargin);
            if isempty(obj(1).Simulator)
                mobilityParam.CurrentTime = 0;
            else
                mobilityParam.CurrentTime = obj(1).Simulator.CurrentTime;
            end

            % Add mobility model to each node in the given array of nodes
            for idx=1:numel(obj)
                node = obj(idx);
                % Add position information to the mobility parameter structure
                mobilityParam.Position = node.Position;
                % Add velocity information to the mobility parameter structure
                mobilityParam.Velocity = node.Velocity;
                % Set the default value for "Bounds" parameter value if it is not provided
                if isempty(mobilityParam.Bounds)
                    if strcmpi(mobilityParam.BoundaryShape, "rectangle")
                        mobilityParam.Bounds = [node.Position(1:2) 10 10];
                    else
                        mobilityParam.Bounds = [node.Position(1:2) 10];
                    end
                end
                % Create the random waypoint mobility model object
                mobilityObj = wirelessnetwork.internal.randomWaypointMobilityModel(mobilityParam);
                node.Mobility = mobilityObj;
            end
        end
    end

    methods (Static, Hidden)
        function reset()
            %reset Reset the node ID counter
            % 
            % reset() Reset the node ID counter. Invoke this method to
            % reset the ID counter before creating nodes in the simulation
             wirelessnetwork.internal.wirelessNode.generateID(0);
        end
    end

    methods (Static, Access = private)
        function varargout = generateID(varargin)
            % Generate/Reset the node ID counter
            %
            % ID = generateID() Returns the next node ID. The node ID
            % counter starts from 1
            %
            % generateID(0) Resets the node ID counter to 0

            persistent count;
            if numel(varargin) == 0
                if isempty(count)
                    count = 1;
                else
                    count = count + 1;
                end
                varargout{1} = count;
            else
                count = 0;
            end
        end
    end
    
    methods (Hidden)
        function packets = pullTransmittedData(obj)
            %pullTransmittedData Read the data to be transmitted from transmit buffer
            %
            % OBJ is an object of type wlanNode, nrGNB, nrUE,
            % bluetoothLENode, bluetoothNode, or any other node type derived
            % from this class. PACKETS are the packets to be transmitted.
            % Each packet is a structure of the format <a href="matlab:help('wirelessnetwork.internal.wirelessPacket')">wirelessPacket</a>

            packets = obj.TransmitterBuffer;
            obj.TransmitterBuffer = [];
        end

        % Simulator checks whether the txPacket is relevant for this node,
        % before applying channel model.
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
            %   NumReceiveAntennas - Number of receiver antennas.
            %
            %   OBJ is an object of type wlanNode, nrGNB, nrUE,
            %   bluetoothLENode, bluetoothNode, or any other node type derived
            %   from this class.
            %
            %   PACKET is the incoming packet to the channel, specified as a
            %   structure of the format <a href="matlab:help('wirelessnetwork.internal.wirelessPacket')">wirelessPacket</a>.
          
            % Initialize
            flag = false;
            rxInfo = [];

            % If it is self-packet (transmitted by this node) do not get this
            % packet
            if packet.TransmitterID == obj.ID
                return;
            end

            % Transmitter frequency
            txFrequency = packet.CenterFrequency;

            % This packet can be received by this node if it is sent on any
            % one of the node's operating frequencies
            interfaceIdx = (txFrequency == obj.ReceiveFrequency);
            if any(interfaceIdx)
                flag = true;
                rxInfo.ID = obj.ID;
                rxInfo.Position = obj.Position;
                rxInfo.Velocity = obj.Velocity;
                rxInfo.NumReceiveAntennas = 1;
            end
        end

        function pushReceivedData(obj, packet)
            %pushReceivedData Push the received packet to node
            %
            % OBJ is an object of type wlanNode, nrGNB, nrUE,
            % bluetoothLENode, bluetoothNode, or any other node type
            % derived from this class.
            %
            % PACKET is the received packet. It is a structure of the
            % format <a href="matlab:help('wirelessnetwork.internal.wirelessPacket')">wirelessPacket</a>

            if isempty(packet)
                return;
            end
            % Copy the received packet to the device (network interface)
            % buffers of the node
            for idx = 1:obj.NumDevices
                if  obj.ReceiveFrequency(idx) == packet.CenterFrequency
                    rxBufIdx = obj.ReceiveBufferIdx(idx);
                    obj.ReceiveBuffer{idx, 1}{rxBufIdx+1} = packet;
                    obj.ReceiveBufferIdx(idx) = obj.ReceiveBufferIdx(idx) + 1;
                    break;
                end
            end
        end

        % Every node must override this run method to work with wireless
        % network simulator.
        % Run the node and its internal modules. Current simulation time in
        % seconds is passed as input. The node returns the time in seconds
        % at which it wants to be called again.
        function nextInvokeTime = run(nodeObj, currentTime)
            nextInvokeTime = Inf;
        end
    end

    methods (Access = private)
        function mobilityParam = validateMobilityInputs(obj, nvPairs)
            %validateMobilityInputs Validate the addMobility method inputs

            % Initialize default mobility parameters structure
            mobilityParam = struct("SpeedRange", [0.415 1.66], "PauseDuration", 0, "BoundaryShape", "rectangle", ...
                "Bounds", []);
            % Validate the given Name-Value pairs and update the mobilityParam
            % structure
            for idx = 1:2:length(nvPairs)
                name = nvPairs{idx};
                value = nvPairs{idx+1};
                switch name
                    case "SpeedRange"
                        validateattributes(value, {'numeric'}, {'nonempty', 'vector', 'finite', '>', 0, 'numel', 2, 'increasing'}, 'SpeedRange', 'SpeedRange')
                    case "PauseDuration"
                        validateattributes(value, {'numeric'}, {'nonempty', 'finite', 'scalar', '>=', 0}, 'PauseDuration', 'PauseDuration')
                    case "BoundaryShape"
                        value = validatestring(value, ["rectangle" "circle"], 'BoundaryShape', 'BoundaryShape');
                    case "Bounds"
                        validateattributes(value, {'numeric'}, {'nonempty','finite', 'vector'}, 'Bounds', 'Bounds')
                    otherwise
                        coder.internal.error("wirelessnetwork:wirelessNode:InvalidNVPair");
                end
                mobilityParam.(char(name)) = value;
            end

            % No further action is required if no input is provided for 'Bounds'
            % parameter
            if isempty(mobilityParam.Bounds)
                return
            end
            % Validate the input of 'Bounds' parameter with respect to the position of
            % each node object
            for idx = 1:numel(obj)
                node = obj(idx);
                if strcmpi(mobilityParam.BoundaryShape, "rectangle")
                    validateattributes(mobilityParam.Bounds,{'numeric'},{'numel', 4})
                    validateattributes(mobilityParam.Bounds(3:4),{'numeric'},{'>', 0})
                    % Find the min X and max X coordinates
                    xRange = mobilityParam.Bounds(1) + mobilityParam.Bounds(3)/2 * [-1 1];
                    % Find the min Y and max Y coordinates
                    yRange = mobilityParam.Bounds(2) + mobilityParam.Bounds(4)/2 * [-1 1];
                    actualX = node.Position(1);
                    isInsideX = (xRange(1)<=actualX) && (xRange(2)>=actualX);
                    actualY = node.Position(2);
                    isInsideY = (yRange(1)<=actualY) && (yRange(2)>=actualY);
                    coder.internal.errorIf(~(isInsideX && isInsideY), "wirelessnetwork:wirelessNode:PositionOutsideMobilityBounds")
                else
                    validateattributes(mobilityParam.Bounds,{'numeric'},{'numel', 3})
                    validateattributes(mobilityParam.Bounds(3),{'numeric'},{'>', 0})
                    distance = sum((mobilityParam.Bounds(1:2) - node.Position(1:2)).^2);
                    coder.internal.errorIf(distance>(mobilityParam.Bounds(3)^2), "wirelessnetwork:wirelessNode:PositionOutsideMobilityBounds")
                end
            end
        end
    end
end
