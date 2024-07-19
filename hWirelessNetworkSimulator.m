classdef hWirelessNetworkSimulator < handle
    %hWirelessNetworkSimulator Create an object to simulate wireless
    %network
    %
    %   SIMULATOR = hWirelessNetworkSimulator(NODES) creates an object to
    %   simulate wireless network.
    %   This class implements functionality to,
    %       1. Simulate a wireless network for the given simulation time
    %       2. Schedule or cancel actions to process during the simulation
    %
    %   NODES Specify nodes as a cell array of wireless node objects.
    %
    %   hWirelessNetworkSimulator methods:
    %
    %   run                 - Run the simulation
    %   addChannelModel     - Add custom channel/pathloss model
    %   scheduleAction      - Schedule an action to process at specified
    %                         simulation time
    %   scheduleActionAfter - Schedule an action to process after specified
    %                         time from the current simulation time
    %   cancelAction        - Cancel scheduled action
    %   addNodes            - Add nodes to the simulation
    %   currentTime         - Get current simulation time

    %   Copyright 2022 The MathWorks, Inc.

    properties (SetAccess = private)
        %Nodes List (cell array) of configured nodes in the network
        Nodes

        %ChannelFcn Function handle for custom channel function
        ChannelFcn
    end

    properties (Access = private)
        %Actions List of actions queued for future processing
        Actions

        %ActionsInvokeTimes List of times, in seconds, corresponding to
        %list of the action in 'Actions' for processing
        ActionsInvokeTimes

        %NodesNextInvokeTimes List of next invoke time for nodes in network
        NodesNextInvokeTimes

        %TimeAdvanceActions List of actions queued for processing, when
        %there is time advance in the simulation
        TimeAdvanceActions

        %CurrentTime Current simulation time, in seconds
        CurrentTime = 0;

        %LastRunTime Time (in seconds) of the last call of the simulation
        %loop
        LastRunTime = 0;

        %NumNodes Number of nodes in the simulation
        NumNodes


        %ActionCounter Counter for assigning unique identifier for the
        %scheduled action
        ActionCounter = 0;

        %CallbackInput Input structure to callback function
        CallbackInput = struct('UserData', [], 'ActionID', 0);
    end

    methods
        % Constructor
        function obj = hWirelessNetworkSimulator(nodes)
            obj.Nodes = nodes;
            obj.NumNodes = numel(nodes);
            obj.NodesNextInvokeTimes = zeros(1, obj.NumNodes);
        end

        function currentTime = currentTime(obj)
            %currentTime(OBJ) Get current simulation time, in seconds
            %
            %   OBJ Object of type hWirelessNetworkSimulator.

            currentTime = obj.CurrentTime;
        end

        function addChannelModel(obj, customChannelFcn)
            disp(customChannelFcn)
            %addChannelModel Add custom channel/pathloss model for all the
            %links
            %
            %   addChannelModel(OBJ, CUSTOMCHANNELFCN) adds the function
            %   handle, CUSTOMCHANNELFCN, of a custom channel/pathloss
            %   model. 
            % 
            %   OBJ Object of type helperWirelessNetwork
            % 
            %   CUSTOMCHANNELFCN is a function handle with the signature:
            %       OUTPUTDATA = pathlossFcn(RXINFO, TXDATA)
            %        RXINFO is a structure containing the node ID, position
            %        and velocity of the receiver node
            %        TXDATA is the transmitted packet of type
            %        wirelessnetwork.internal.wirelessPacket
            %        OUTPUTDATA is the packet after undergoing channel 
            %        impairments. It is of type wirelessnetwork.internal.wirelessPacket

            obj.ChannelFcn = customChannelFcn;
            disp(obj.ChannelFcn)
        end

        function addNodes(obj, nodes)
            %addNodes Add nodes to the simulation
            %
            %   addNodes(OBJ, NODES) Add nodes to the simulation. You can
            %   add nodes before the start of simulation, and during the
            %   simulation.
            %
            %   OBJ Object of type hWirelessNetworkSimulator.
            %
            %   NODES Specify nodes as a cell array of wireless node
            %   objects.

            obj.Nodes = [obj.Nodes nodes];
            numNodes = numel(nodes);
            obj.NodesNextInvokeTimes = [obj.NodesNextInvokeTimes zeros(1, numNodes)];
            obj.NumNodes = numel(obj.Nodes);
        end
        function actionIdentifier = scheduleActionAfter(obj, callbackFcn, userData, callAfter, varargin)
            %scheduleActionAfter Schedule an action to process after
            %specified time from the current simulation time
            %
            %   ACTIONIDENTIFIER = scheduleActionAfter(OBJ, CALLBACKFCN,
            %   USERDATA, CALLAFTER) Schedule an action in the
            %   simulation. The action is added to scheduled actions list,
            %   and is processed after specified time during the
            %   simulation.
            %
            %   CALLBACKFCN Function handle, associated with the action.
            %
            %   USERDATA User data to be passed to the callback function
            %   (CALLBACKFCN) associated with the action. If multiple
            %   parameters are to be passed as inputs to the callback
            %   function, use a structure or a cell array.
            %
            %   CALLAFTER Time to process the action from current simulation
            %   time, in seconds.
            %
            %   ACTIONIDENTIFIER This value is an integer, indicating the
            %   unique identifier for the scheduled action. This value can
            %   be used to cancel the scheduled action.
            %
            %   ACTIONIDENTIFIER = scheduleActionAfter(OBJ, CALLBACKFCN,
            %   USERDATA, CALLAFTER, PERIODICITY) Schedule a periodic
            %   action in the simulation. The action is added to scheduled
            %   actions list, and is processed after specified time during
            %   the simulation with specified periodicity.
            %
            %   PERIODICITY Periodicity of the scheduled action, in
            %   seconds.
            %
            %   1. To schedule a periodic action i.e., an action called
            %   periodically in the simulation, set periodicity value with
            %   some time value.
            %
            %   2. To schedule a time advance action i.e. an action called
            %   when there was time advance in the simulation, set
            %   periodicity value as 0.

            % Schedule action
            callAt = obj.CurrentTime + callAfter;
            if nargin == 5
                actionIdentifier = scheduleAction(obj, callbackFcn, userData, callAt, varargin{1});
            else
                actionIdentifier = scheduleAction(obj, callbackFcn, userData, callAt);
            end
        end

        function actionIdentifier = scheduleAction(obj, callbackFcn, userData, callAt, varargin)
            %scheduleAction Schedule an action to process at specified
            %simulation time
            %
            %   ACTIONIDENTIFIER = scheduleAction(OBJ, CALLBACKFCN,
            %   USERDATA, CALLAT) Schedule an action in the simulation.
            %   The action is added to scheduled actions list, and is
            %   processed at specified absolute time during the simulation.
            %
            %   CALLBACKFCN Function handle, associated with the action.
            %
            %   USERDATA User data to be passed to the callback function
            %   (CALLBACKFCN) associated with the action. If multiple
            %   parameters are to be passed as inputs to the callback
            %   function, use a structure or a cell array.
            %
            %   CALLAT Absolute simulation time to process the action
            %
            %   ACTIONIDENTIFIER This value is an integer, indicating the
            %   unique identifier for the scheduled action. This value can
            %   be used to cancel the scheduled action.
            %
            %   ACTIONIDENTIFIER = scheduleAction(OBJ, CALLBACKFCN,
            %   USERDATA, CALLAT, PERIODICITY) Schedule a periodic action
            %   in the simulation. The action is added to scheduled actions
            %   list, and is processed at specified absolute time during
            %   the simulation with specified periodicity.
            %
            %   PERIODICITY Periodicity of the scheduled action, in
            %   seconds.
            %
            %   1. To schedule a periodic action i.e. an action called
            %   periodically in the simulation, set periodicity value with
            %   some time value.
            %
            %   2. To schedule a time advance action i.e. an action called
            %   when there was time advance in the simulation, set
            %   periodicity value as 0.

            % Create action
            action.CallbackFcn = callbackFcn;
            action.UserData = userData;
            obj.ActionCounter = obj.ActionCounter + 1;
            action.ActionIdentifier = obj.ActionCounter;
            actionIdentifier = action.ActionIdentifier;

            % One-time action (no periodicity)
            if nargin == 4
                action.CallbackPeriodicity = Inf;
            else
                action.CallbackPeriodicity = varargin{1};
            end

            % Add action to actions queue
            if action.CallbackPeriodicity == 0
                % Add a time advance action to the actions list
                obj.TimeAdvanceActions = [obj.TimeAdvanceActions action];
            else
                % Add periodic or one-time action to the actions list
                addActionAt(obj, action, callAt);
            end
            
            % Sort action in order of time
            sortActions(obj);
        end

        function cancelAction(obj, actionIdentifier)
            %cancelAction Cancel scheduled action
            %
            %   cancelAction(OBJ, ACTIONIDENTIFIER) Cancel the scheduled
            %   actions associated with the action identifier
            %   (ACTIONIDENTIFIER).
            %
            %   ACTIONIDENTIFIER This value is an integer, indicating the
            %   unique identifier for the scheduled action.


            % Cancel periodic or one-time action
            for actionIdx = 1:numel(obj.Actions)
                if obj.Actions(actionIdx).ActionIdentifier == actionIdentifier
                    obj.Actions(actionIdx) = [];
                    obj.ActionsInvokeTimes(actionIdx) = [];
                    return
                end
            end

            % Cancel time advance action
            for actionIdx = 1:numel(obj.TimeAdvanceActions)
                if obj.TimeAdvanceActions(actionIdx).ActionIdentifier == actionIdentifier
                    obj.TimeAdvanceActions(actionIdx) = [];
                    return
                end
            end
        end

        function run(obj, simulationTime)
            %run Run the simulation
            %
            %   run(OBJ, SIMULATIONTIME) Runs the simulation for all the
            %   specified nodes with associated actions, for the specified
            %   simulation time.
            %
            %   OBJ Object of type hWirelessNetworkSimulator.
            %
            %   SIMULATIONTIME Simulation time in seconds.
            % Initialize simulation parameters
            sortActions(obj);

            % Run simulator
            while(obj.CurrentTime < simulationTime)
                % Run all nodes
                if obj.CurrentTime == obj.LastRunTime
                    for nodeIdx = 1:obj.NumNodes
                        obj.NodesNextInvokeTimes(nodeIdx) = runNode(obj.Nodes{nodeIdx}, obj.CurrentTime);
                    end
                else % Run nodes which are required to run at current time
                    for nodeIdx = 1:obj.NumNodes
                        % Call node if next invoke time is same as current
                        % time
                        if obj.NodesNextInvokeTimes(nodeIdx) == obj.CurrentTime
                            obj.NodesNextInvokeTimes(nodeIdx) = runNode(obj.Nodes{nodeIdx}, obj.CurrentTime);
                        end
                    end
                end

                % Distribute the transmitted packets (if any)
                packetDistributed = distributePackets(obj, obj.Nodes);

                % Process actions scheduled at current time
                processActions(obj);
                
                % Calculate invoke time for next run
                nextRunTime = nextInvokeTime(obj, packetDistributed);

                % Advance the simulation time
                obj.LastRunTime = obj.CurrentTime;
                obj.CurrentTime = nextRunTime;
            end
        end
    end

    methods(Access = private)
        % Sort actions in time order
        function sortActions(obj)
            [obj.ActionsInvokeTimes, sIdx] = sort(obj.ActionsInvokeTimes);
            obj.Actions = obj.Actions(sIdx);
        end

        % Invoke current action
        function invokeAction(obj, action)
            if isempty(action.UserData)
                action.CallbackFcn();
            else
                callbackInput = obj.CallbackInput;
                callbackInput.UserData = action.UserData;
                callbackInput.ActionID = action.ActionIdentifier;
                action.CallbackFcn(callbackInput);
            end
        end

        % Add current action to list
        function addActionAt(obj, action, callAt)
            obj.Actions = [obj.Actions action];
            obj.ActionsInvokeTimes = [obj.ActionsInvokeTimes callAt];
        end

        % Calculate time, in seconds, for advancing the simulation to
        % next action
        function dt = nextInvokeTime(obj, packetDistributed)
            % Call all nodes when packet is distributed
            if packetDistributed
                dt = obj.CurrentTime;
            else
                % Get minimum time from next invoke times of nodes and actions
                nextNodeDt = min(obj.NodesNextInvokeTimes);
                if ~isempty(obj.ActionsInvokeTimes)
                    nextActionTimes = obj.ActionsInvokeTimes(obj.ActionsInvokeTimes ~= obj.CurrentTime);
                    dt = min(nextActionTimes(1), nextNodeDt);
                else
                    dt = nextNodeDt;
                end
            end
        end

        % Process actions scheduled at current time. If the action is
        % periodic, update next invocation time for the actions with
        % specified periodicity. Otherwise, remove the action from action
        % list.
        function processActions(obj)
            % Process all time advance actions
            if obj.CurrentTime > obj.LastRunTime
                for actionIdx = 1:numel(obj.TimeAdvanceActions)
                    invokeAction(obj, obj.TimeAdvanceActions(actionIdx));
                end
            end
            
            % Process periodic or one-time actions
            numActions = numel(obj.Actions);
            for actionIdx = 1:numActions
                % As actions are sorted in order of time, process the first
                % action at current time
                currentActionIdx = 1;
                if obj.ActionsInvokeTimes(currentActionIdx) == obj.CurrentTime
                    % Process current action
                    currentAction = obj.Actions(currentActionIdx);
                    invokeAction(obj, currentAction);
                    % Update next invocation time for the current periodic
                    % action
                    if currentAction.CallbackPeriodicity ~= inf
                        callAt = obj.CurrentTime + currentAction.CallbackPeriodicity;
                        obj.ActionsInvokeTimes(currentActionIdx) = callAt;
                        % Sort action in order of time
                        sortActions(obj);
                    else % Remove current one-time action from the list of actions
                        obj.Actions(currentActionIdx) = [];
                        obj.ActionsInvokeTimes(currentActionIdx) = [];
                    end
                else % Ignore the rest of actions
                    break
                end
            end
        end

        % Distribute the transmitted packets.
        function txFlag = distributePackets(obj, nodes)
            %distributePackets Distribute the transmitting data from the
            %nodes into the receiving buffers of all the nodes
            %
            %   TXFLAG = distributePackets(OBJ, NODES) distributes the
            %   transmitting data from the nodes, NODES, into the receiving
            %   buffers of all the nodes and return, TXFLAG, to indicate if
            %   there is any transmission in the network
            %
            %   TXFLAG indicates if there is any transmission in the network
            %
            %   NODES specifies nodes as a cell array of wireless node
            %   objects.

            % Reset the transmission flag to specify that the channel is free
            txFlag = false;

            % Get the data from all the nodes to be transmitted
            for txIdx = 1:obj.NumNodes
                % fprintf("-\n")
                txNode = nodes{txIdx};
                txBuffer = pullTransmittedData(txNode);
                for pktIdx = 1:numel(txBuffer)
                    txData = txBuffer{pktIdx};
                    txFlag = true;
                    for rxIdx = 1:obj.NumNodes
                        % If it is self-packet (transmitted by this node)
                        % do not get this packet
                        if txIdx == rxIdx
                            continue;
                        end

                        % Copy Tx data into the receiving buffers of other
                        % nodes after passing through channel
                        rxNode = nodes{rxIdx};

                        % Workflow for channel registered at simulator
                        [flag, rxInfo] = channelInvokeDecision(rxNode, txData);
                        if flag
                            fprintf("Flag")
                            if ~isempty(obj.ChannelFcn)
                                outputData = obj.ChannelFcn(rxInfo, txData);
                                disp("Custommm")
                            else
                                outputData = freeSpacePathLoss(obj, rxInfo, txData);
                            end
                        else
                            outputData = txData;
                        end
                        pushReceivedData(rxNode, outputData);
                    end
                end
                
            end
        end

        function outputData = freeSpacePathLoss(~, rxInfo, txData)
            fprintf("FSPL Apply")
            %freeSpacePathLoss Apply free space path loss on the packet and
            %update the relevant fields of the output data

            outputData = txData
            % Calculate distance between transmitter and receiver in meters
            distance = norm(outputData.TransmitterPosition - rxInfo.Position);
            % Apply free space path loss
            lambda = physconst('LightSpeed')/(outputData.CenterFrequency);
            % Calculate free space path loss (in dB)
            pathLoss = fspl(distance, lambda);
            % Apply pathLoss on the power of the packet
            outputData.Power = outputData.Power - pathLoss;

            if outputData.Abstraction == 0
                % Modify the IQ samples such that it will contain the
                % pathloss effect
                scale = 10.^(-pathLoss/20);
                [numSamples, ~] = size(outputData.Data);
                outputData.Data(1:numSamples,:) = outputData.Data(1:numSamples,:)*scale;
            end
        end
    end

    methods(Static)
        function init()
            % Set up the environment
            clear wirelessNode;
        end
    end
end
