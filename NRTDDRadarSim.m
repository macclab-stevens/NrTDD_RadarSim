%% Plug Custom Channel into Wireless Network Simulator
% This example shows you how to plug a custom channel into the wireless network 
% simulator by using 5G Toolbox™ and the Communications Toolbox™ Wireless Network 
% Simulation Library.
% 
% Using this example, you can: 
% # Create and configure a 5G network with new radio (NR) base station (gNB) 
% and user equipment (UE) nodes.
% # Establish a connection between the gNB and UE nodes.
% # Create a custom channel, and plug it into the wireless network simulator.
% # Simulate a 5G network, and retrieve the statistics of the gNB and UE nodes. 
% Check if the Communications Toolbox Wireless Network Simulation Library support 
% package is installed. If the support package is not installed, MATLAB® returns 
% an error with a link to download and install the support package.

%To create the logger reference:
L = log4m.getLogger('logfile.txt');
L.setCommandWindowLevel(L.ALL);
L.setLogLevel(L.ALL);
L.debug('main','Start Logging');
L.error('exampleFunction','An error occurred');


wirelessnetworkSupportPackageCheck
% Create a wireless network simulator.

networkSimulator = wirelessNetworkSimulator.init;

% Create a gNB node with these specifications. 
% * Position — [100 –100 0]
% * Channel bandwidth — 20 MHz
% * Subcarrier spacing — 30 KHz 
% * Duplex mode — Time division duplex

PhyAbst = "None"
gnb = nrGNB(Position=[-100 100 0],ChannelBandwidth=20e6,DuplexMode="TDD", SubcarrierSpacing=15e3,PHYAbstractionMethod=PhyAbst)
 
% Create two UE nodes, specifying their positions in Cartesian coordinates.

ue1 = nrUE(Position=[100 100 0],PHYAbstractionMethod=PhyAbst) % In Cartesian x, y, and z coordinates.
ue2 = nrUE(Position=[5000 100 0],PHYAbstractionMethod=PhyAbst);
ueNodes = [ue1 ue2]

% Configure a scheduler at the gNB with a maximum number of two users per transmission 
% time interval (TTI).

configureScheduler(gnb,MaxNumUsersPerTTI=2)
 
% Connect the UE nodes to the gNB node and enable full-buffer traffic.
connectUE(gnb,ueNodes,FullBufferTraffic="on")
 
% Add the nodes to the network simulator.
addNodes(networkSimulator,gnb)
addNodes(networkSimulator,ueNodes)

% Add the custom channel to the wireless network simulator.
addChannelModel(networkSimulator,@addImpairment);

% Specify the simulation time in second
simulationTime = 0.050;

% Radar
TestData.Type = 2;
TestData.TransmitterID = 1;
TestData.StartTime = 0;
TestData.Duration = 1e-3;
global Radar
Radar.PRI_Hz = 1000; %Hz
Radar.PRI = 1/ Radar.PRI_Hz;
Radar.PW = 40e-6; %uS
Radar.StartOffset = 200e-6;
Radar.Starts = [Radar.StartOffset]
while Radar.Starts(end) < simulationTime
    Radar.Starts(end + 1) = Radar.Starts(end) + Radar.PRI;
end
disp(Radar.Starts)

%% 
% Run the simulation for the specified simulation time.

run(networkSimulator,simulationTime)
%% 
% Obtain the statistics for the gNB and UE nodes.

gnbStats = statistics(gnb);
gnbStats.MAC
ueStats = statistics(ueNodes)

%% 
% Follow these steps to create a custom channel that models NR path loss for 
% an urban macrocell scenario.
% * Create a custom function with this syntax: |rxData = customFcnName(rxInfo,txData)|. 
% The |rxInfo| input (a structure) is the receiver node information, and the |txData| 
% input (a structure) specifies the transmitted packets. The simulator automatically 
% passes information about the receiver node and the packets transmitted by a 
% transmitter node as inputs to the custom function. For more information about 
% this, see the <docid:comm_ref#mw_17054773-3d39-4e39-8566-5fac05380a1e addChannelModel> 
% object function.
% * Use the <docid:5g_ref#mw_object_nrPathLossConfig |nrPathLossConfig|> object 
% to set path loss configuration parameters for an urban macrocell scenario. 
% * Calculate path loss between the base station and UE nodes using the <docid:5g_ref#mw_function_nrPathLoss 
% |nrPathLoss|> function. Specify carrier frequency, line of sight (LOS) between 
% the gNB and UE nodes, and the transmitter and receiver positions.
% * Apply path loss to the transmitted packets.

function outputData = addImpairment(rxInfo,txData)
% fprintf("add Impairment\n")
% Set path loss configuration parameters
pathLossConfig = nrPathLossConfig;
pathLossConfig.Scenario = "UMa";      % Urban macrocell
pathLossConfig.EnvironmentHeight = 1; % Average height of the environment in UMa/UMi
los = 1;                              % Assume LOS between the gNB and UE nodes

outputData = txData;

% Calculate path loss
pathLoss = nrPathLoss(pathLossConfig,txData.CenterFrequency,los, ...
    txData.TransmitterPosition',rxInfo.Position');
outputData.Power = outputData.Power - pathLoss;
% outputData.Data = zeros(size(outputData.Data))
% Set default values for channel parameters

outputData.Metadata.Channel.PathGains = ...
    permute(ones(outputData.NumTransmitAntennas,rxInfo.NumReceiveAntennas),[3 4 1 2])/ ...
    sqrt(rxInfo.NumReceiveAntennas);
outputData.Metadata.Channel.PathFilters = 1;
outputData.Metadata.Channel.SampleTimes = 0;

if outputData.Abstraction == 0                             % Full physical layer processing
    % outputData.Data = outputData.Data.*db2mag(-pathLoss);
    outputData.Data = outputData.Data.*db2mag(-pathLoss);
    numTxAnts = outputData.NumTransmitAntennas;
    numRxAnts = rxInfo.NumReceiveAntennas;
    H = fft(eye(max([numTxAnts numRxAnts])));
    H = H(1:numTxAnts,1:numRxAnts);
    H = H/norm(H);
    outputData.Data = txData.Data*H; % Apply channel to the waveform
    % outputData.Data = ones(size(outputData.Data));
    % disp(outputData)
    
    fprintf("\n %d %d %f %f %f \n",outputData.Type,outputData.TransmitterID,outputData.StartTime,outputData.Duration,outputData.SampleRate)



    %%Null IQ Data that lines up with the radar pulses
    outputData = applyRadar(outputData)


end
end

function Data = applyRadar(Data)
    fprintf("-- \n")
    global Radar
    % disp(Radar.Starts)
    for i = 1:length(Radar.Starts)
        % disp(Radar.Starts(i))
        %if radar value is between start_time and start_time+duration
        if Radar.Starts(i)>=Data.StartTime & Radar.Starts(i) <= (Data.StartTime+Data.Duration)
            fprintf("Radar Pulse at T:%f between %f and %f \n",Radar.Starts(i),Data.StartTime,Data.StartTime+Data.Duration)
            numSamples = length(Data.Data);
            sampleDur = Data.Duration/numSamples;
            fprintf("%d samples over %f (s). 1 Sample = %d (s) \n",numSamples,Data.Duration,sampleDur)
            Radar.PWsamples = int64(Radar.PW/sampleDur);
            fprintf("Radar PulseWidth is %f (s) or %f samples \n",Radar.PW,Radar.PWsamples)
            Radar.SampleStart = int64((Radar.Starts(i) - Data.StartTime)/sampleDur);
            fprintf("Radar Pulse starts at sample index: %f \n",Radar.SampleStart)
            fprintf("IQ Data will be 1'd from sample index %f to %f \n",Radar.SampleStart,Radar.SampleStart+Radar.PWsamples)
            x = complex(ones(1,Radar.PWsamples),0);
            fprintf("x size:%f Data.Data(:) %f \n",numel(x),numel(Data.Data(Radar.SampleStart:Radar.SampleStart+Radar.PWsamples-1) )   )
            % disp(Data.Data(Radar.SampleStart:Radar.SampleStart+Radar.PWsamples-1))
            % disp(x)
            Data.Data(Radar.SampleStart:Radar.SampleStart+Radar.PWsamples-1) = x;
            break
        end
    end
    fprintf("-- \n")
end 